import 'dart:async';
import 'dart:io';
import '../local/network_discovery.dart';
import '../local/wifi_info_service.dart';

/// نظام كشف التسلل (Intrusion Detection System)
/// يراقب الشبكة بحثاً عن أنشطة مشبوهة
class IntrusionDetectionService {
  Timer? _monitorTimer;
  bool _isMonitoring = false;
  final List<SecurityAlert> _alerts = [];
  final StreamController<SecurityAlert> _alertController = StreamController.broadcast();
  
  // قواعد البيانات
  final Map<String, DateTime> _knownDevices = {}; // MAC -> first seen
  final Map<String, int> _portScanAttempts = {}; // source IP -> attempts
  final Map<String, DateTime> _lastAlertTime = {}; // rule key -> last alert
  
  Stream<SecurityAlert> get alertStream => _alertController.stream;
  List<SecurityAlert> get alerts => List.unmodifiable(_alerts);
  bool get isMonitoring => _isMonitoring;
  int get alertCount => _alerts.length;
  
  /// بدء المراقبة
  Future<bool> startMonitoring({Duration interval = const Duration(seconds: 30)}) async {
    if (_isMonitoring) return false;
    
    // التحقق من إمكانية الوصول للشبكة
    final network = await NetworkDiscovery.getCurrentNetwork();
    if (network == null) return false;
    
    // حفظ الأجهزة المعروفة كـ baseline
    final devices = await NetworkDiscovery.discoverViaArp();
    for (final device in devices) {
      if (device.mac != 'Unknown') {
        _knownDevices[device.mac] = device.firstSeen;
      }
    }
    
    _isMonitoring = true;
    
    // بدء المراقبة الدورية
    _monitorTimer = Timer.periodic(interval, (_) => _performScan());
    
    return true;
  }
  
  /// إيقاف المراقبة
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
  }
  
  /// فحص دوري
  Future<void> _performScan() async {
    if (!_isMonitoring) return;
    
    try {
      // 1. فحص الأجهزة الجديدة
      await _checkForNewDevices();
      
      // 2. فحص تغيرات MAC
      await _checkForMacChanges();
      
      // 3. فحص البورتات المفتوحة على الراوتر
      await _checkRouterSecurity();
      
      // 4. فحص DNS leaks
      await _checkDnsLeaks();
      
    } catch (_) {}
  }
  
  /// كشف أجهزة جديدة على الشبكة
  Future<void> _checkForNewDevices() async {
    final devices = await NetworkDiscovery.discoverViaArp();
    
    for (final device in devices) {
      if (device.mac == 'Unknown') continue;
      
      if (!_knownDevices.containsKey(device.mac)) {
        // جهاز جديد!
        _knownDevices[device.mac] = device.firstSeen;
        
        _addAlert(SecurityAlert(
          type: AlertType.newDevice,
          severity: AlertSeverity.medium,
          title: 'جهاز جديد على الشبكة',
          description: 'تم اكتشاف جهاز جديد: ${device.vendor} (${device.ip})',
          sourceIp: device.ip,
          sourceMac: device.mac,
          timestamp: DateTime.now(),
          recommendation: 'تحقق من هوية الجهاز. إذا لم تتعرف عليه، افصله عن الشبكة فوراً.',
        ));
      }
    }
  }
  
  /// كشف تغير MAC (محاولة انتحال شخصية)
  Future<void> _checkForMacChanges() async {
    final devices = await NetworkDiscovery.discoverViaArp();
    final currentMacs = <String, DiscoveredDevice>{};
    
    for (final device in devices) {
      if (device.mac != 'Unknown') {
        currentMacs[device.ip] = device;
      }
    }
    
    // فحص إذا كان نفس IP يستخدم MAC مختلف عن السابق
    // (هذا يتطلب تخزين سابق، نضيفه لاحقاً)
  }
  
  /// فحص أمان الراوتر
  Future<void> _checkRouterSecurity() async {
    final network = await NetworkDiscovery.getCurrentNetwork();
    if (network == null || network.gateway.isEmpty) return;
    
    try {
      // فحص بورتات خطيرة على الراوتر
      const dangerousPorts = [23, 21, 161, 7547];
      
      for (final port in dangerousPorts) {
        final socket = await Socket.connect(
          network.gateway,
          port,
          timeout: const Duration(seconds: 2),
        );
        socket.destroy();
        
        // البورت مفتوح!
        _addAlert(SecurityAlert(
          type: AlertType.openPort,
          severity: port == 23 || port == 7547 ? AlertSeverity.high : AlertSeverity.medium,
          title: 'بورت خطير مفتوح على الراوتر',
          description: _getPortDescription(port),
          sourceIp: network.gateway,
          timestamp: DateTime.now(),
          recommendation: _getPortRecommendation(port),
        ));
      }
    } catch (_) {}
  }
  
  String _getPortDescription(int port) {
    switch (port) {
      case 23: return 'Telnet مفتوح على الراوتر - غير مشفّر وعرضة للاختراق';
      case 21: return 'FTP مفتوح على الراوتر - غير مشفّر';
      case 161: return 'SNMP مفتوح - قد يكشف معلومات حساسة';
      case 7547: return 'TR-069/CWMP مفتوح - يمكن استغلاله للتحكم الكامل بالراوتر';
      default: return 'بورت $port مفتوح';
    }
  }
  
  String _getPortRecommendation(int port) {
    switch (port) {
      case 23: return 'عطّل Telnet من إعدادات الراوتر فوراً واستخدم SSH';
      case 21: return 'عطّل FTP أو استخدم SFTP/SCP';
      case 161: return 'استخدم SNMP v3 مع كلمة مرور قوية أو عطّله';
      case 7547: return 'عطّل TR-069 من إعدادات الراوتر';
      default: return 'أغلق هذا البورت إذا لم تكن تستخدمه';
    }
  }
  
  /// فحص DNS leaks
  Future<void> _checkDnsLeaks() async {
    // سيتم تنفيذه في DNS Leak Test service
  }
  
  /// إضافة تنبيه (مع منع التكرار)
  void _addAlert(SecurityAlert alert) {
    // منع التكرار خلال 5 دقائق
    final ruleKey = '${alert.type}:${alert.sourceIp}';
    final lastAlert = _lastAlertTime[ruleKey];
    if (lastAlert != null && 
        DateTime.now().difference(lastAlert) < const Duration(minutes: 5)) {
      return;
    }
    
    _lastAlertTime[ruleKey] = DateTime.now();
    _alerts.add(alert);
    _alertController.add(alert);
  }
  
  /// تنبيه يدوي من مصادر خارجية
  void reportAlert(SecurityAlert alert) {
    _addAlert(alert);
  }
  
  /// مسح التنبيهات
  void clearAlerts() {
    _alerts.clear();
    _lastAlertTime.clear();
  }
  
  /// حذف تنبيه واحد
  void dismissAlert(int index) {
    if (index >= 0 && index < _alerts.length) {
      _alerts.removeAt(index);
    }
  }
  
  /// إحصائيات
  Map<AlertSeverity, int> getAlertStats() {
    final stats = <AlertSeverity, int>{};
    for (final alert in _alerts) {
      stats[alert.severity] = (stats[alert.severity] ?? 0) + 1;
    }
    return stats;
  }
  
  List<SecurityAlert> getAlertsBySeverity(AlertSeverity severity) {
    return _alerts.where((a) => a.severity == severity).toList();
  }
  
  void dispose() {
    stopMonitoring();
    _alertController.close();
  }
}

class SecurityAlert {
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String description;
  final String? sourceIp;
  final String? sourceMac;
  final DateTime timestamp;
  final String recommendation;
  
  SecurityAlert({
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.sourceIp,
    this.sourceMac,
    required this.timestamp,
    required this.recommendation,
  });
  
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'severity': severity.name,
    'title': title,
    'description': description,
    'sourceIp': sourceIp,
    'sourceMac': sourceMac,
    'timestamp': timestamp.toIso8601String(),
    'recommendation': recommendation,
  };
}

enum AlertType {
  newDevice,
  macSpoofing,
  openPort,
  deauthAttack,
  rogueAp,
  dnsLeak,
  webrtcLeak,
  portScan,
  bruteForce,
  malware,
  suspiciousTraffic,
}

enum AlertSeverity {
  critical,  // خطر فوري
  high,      // خطر عالي
  medium,    // تحذير
  low,       // معلومات
  info,      // مجرد معلومات
}

extension AlertSeverityExtension on AlertSeverity {
  String get displayName {
    switch (this) {
      case AlertSeverity.critical: return 'حرج';
      case AlertSeverity.high: return 'عالي';
      case AlertSeverity.medium: return 'متوسط';
      case AlertSeverity.low: return 'منخفض';
      case AlertSeverity.info: return 'معلومة';
    }
  }
  
  int get priority {
    switch (this) {
      case AlertSeverity.critical: return 5;
      case AlertSeverity.high: return 4;
      case AlertSeverity.medium: return 3;
      case AlertSeverity.low: return 2;
      case AlertSeverity.info: return 1;
    }
  }
}
