import 'dart:async';
import 'dart:io';
import '../local/network_discovery.dart';

/// كاشف هجمات Deauthentication
/// يكتشف محاولات قطع أجهزة عن شبكة WiFi
/// 
/// هجمات Deauth ترسل حزم deauthentication وهمية لطرد الأجهزة من الشبكة
/// يستخدمها مهاجمون لـ:
/// - قطع إنترنت الضحية
/// - التقاط handshake (لكسر كلمة المرور)
/// - هجمات man-in-the-middle
class DeauthDetector {
  Process? _monitorProcess;
  bool _isMonitoring = false;
  final List<DeauthAlert> _deauthAlerts = [];
  final StreamController<DeauthAlert> _alertController = StreamController.broadcast();
  
  // تتبع تكرار الهجمات
  final Map<String, List<DateTime>> _attackTimes = {}; // source MAC -> times
  
  Stream<DeauthAlert> get alertStream => _alertController.stream;
  List<DeauthAlert> get alerts => List.unmodifiable(_deauthAlerts);
  bool get isMonitoring => _isMonitoring;
  int get alertCount => _deauthAlerts.length;
  
  /// بدء المراقبة
  /// يتطلب: root + wireless adapter في monitor mode
  Future<bool> startMonitoring({String interface = 'wlan0'}) async {
    if (_isMonitoring) return false;
    
    try {
      // التحقق من توفر tcpdump
      final whichResult = await Process.run('which', ['tcpdump']);
      if (whichResult.exitCode != 0) {
        return false;
      }
      
      // فلتر deauth frames
      // نوع الحزمة: 0x00C0 (deauthentication)
      // type=0 (management), subtype=12 (deauth)
      final filter = 'type mgt subtype deauth';
      
      _monitorProcess = await Process.start(
        'su',
        ['-c', 'tcpdump -i $interface -e -nn "$filter" 2>&1'],
      );
      
      _isMonitoring = true;
      _deauthAlerts.clear();
      
      _monitorProcess!.stdout.transform(const SystemEncoding().decoder).listen(
        (data) => _parseDeauthPacket(data, interface),
        onDone: () => _isMonitoring = false,
        onError: (e) => _isMonitoring = false,
      );
      
      return true;
    } catch (_) {
      return false;
    }
  }
  
  /// إيقاف المراقبة
  Future<void> stopMonitoring() async {
    if (_monitorProcess != null) {
      _monitorProcess!.kill(ProcessSignal.sigterm);
      await _monitorProcess!.exitCode;
      _monitorProcess = null;
    }
    _isMonitoring = false;
  }
  
  /// تحليل حزم deauth
  void _parseDeauthPacket(String data, String interface) {
    final lines = data.split('\n');
    
    for (final line in lines) {
      if (line.isEmpty || !line.contains('DeAuthentication')) continue;
      
      // مثال: 10:30:45.123456 aa:bb:cc:dd:ee:ff > ff:ff:ff:ff:ff:ff, DeAuthentication
      final match = RegExp(
        r'(\d{2}:\d{2}:\d{2}\.\d+)\s+([0-9a-fA-F:]{17})\s+>\s+([0-9a-fA-F:]{17})'
      ).firstMatch(line);
      
      if (match != null) {
        final timestamp = match.group(1)!;
        final sourceMac = match.group(2)!;
        final targetMac = match.group(3)!;
        
        final alert = DeauthAlert(
          timestamp: DateTime.now(),
          sourceMac: sourceMac,
          targetMac: targetMac,
          interface: interface,
          severity: _determineSeverity(sourceMac),
          count: _attackTimes[sourceMac]?.length ?? 1,
        );
        
        _deauthAlerts.add(alert);
        _alertController.add(alert);
        
        // إذا كان هجوم متكرر، نرفع الخطورة
        _trackAttack(sourceMac);
      }
    }
  }
  
  /// تتبع تكرار الهجمات
  void _trackAttack(String sourceMac) {
    final now = DateTime.now();
    _attackTimes[sourceMac] ??= [];
    _attackTimes[sourceMac]!.add(now);
    
    // إزالة الهجمات القديمة (أكثر من دقيقة)
    _attackTimes[sourceMac]!.removeWhere(
      (time) => now.difference(time) > const Duration(minutes: 1),
    );
    
    // إذا تجاوز 10 هجمات في الدقيقة، نعتبره هجوم حقيقي
    if (_attackTimes[sourceMac]!.length > 10) {
      // ترقية الخطورة
      if (_deauthAlerts.isNotEmpty) {
        // يمكن إضافة منطق ترقية هنا
      }
    }
  }
  
  /// تحديد مستوى الخطورة
  DeauthSeverity _determineSeverity(String sourceMac) {
    final times = _attackTimes[sourceMac] ?? [];
    final now = DateTime.now();
    
    final recentAttacks = times.where(
      (time) => now.difference(time) < const Duration(minutes: 1),
    ).length;
    
    if (recentAttacks > 20) return DeauthSeverity.critical;
    if (recentAttacks > 10) return DeauthSeverity.high;
    if (recentAttacks > 5) return DeauthSeverity.medium;
    return DeauthSeverity.low;
  }
  
  /// كشف بديل بدون root (مراقبة انقطاع الاتصال)
  Future<bool> startMonitoringWithoutRoot() async {
    if (_isMonitoring) return false;
    
    _isMonitoring = true;
    
    // مراقبة حالة الاتصال
    // إذا انقطع فجأة بدون سبب، قد يكون deauth attack
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isMonitoring) {
        timer.cancel();
        return;
      }
      
      final network = await NetworkDiscovery.getCurrentNetwork();
      if (network == null) {
        // انقطاع الاتصال - قد يكون deauth
        final alert = DeauthAlert(
          timestamp: DateTime.now(),
          sourceMac: 'Unknown',
          targetMac: 'Your Device',
          interface: 'wlan0',
          severity: DeauthSeverity.medium,
          count: 1,
          note: 'انقطاع الاتصال - قد يكون هجوم deauth',
        );
        
        _deauthAlerts.add(alert);
        _alertController.add(alert);
      }
    });
    
    return true;
  }
  
  /// إحصائيات
  Map<String, int> getAttackStats() {
    final stats = <String, int>{};
    for (final alert in _deauthAlerts) {
      stats[alert.sourceMac] = (stats[alert.sourceMac] ?? 0) + 1;
    }
    return stats;
  }
  
  void clearAlerts() {
    _deauthAlerts.clear();
    _attackTimes.clear();
  }
  
  void dispose() {
    stopMonitoring();
    _alertController.close();
  }
}

class DeauthAlert {
  final DateTime timestamp;
  final String sourceMac;
  final String targetMac;
  final String interface;
  final DeauthSeverity severity;
  final int count;
  final String? note;
  
  DeauthAlert({
    required this.timestamp,
    required this.sourceMac,
    required this.targetMac,
    required this.interface,
    required this.severity,
    required this.count,
    this.note,
  });
  
  String get severityText {
    switch (severity) {
      case DeauthSeverity.critical: return '🔴 هجوم حرج';
      case DeauthSeverity.high: return '🟠 خطر عالي';
      case DeauthSeverity.medium: return '🟡 خطر متوسط';
      case DeauthSeverity.low: return '🟢 خطر منخفض';
    }
  }
  
  String get recommendation {
    switch (severity) {
      case DeauthSeverity.critical: 
        return '⚠️ هجوم نشط! افصل WiFi فوراً واستخدم بيانات الخلوي. قد يحاول المهاجم التقاط handshake لكسر كلمة المرور.';
      case DeauthSeverity.high:
        return 'تحقق من الأجهزة القريبة. قد يكون هناك جهاز يحاول اختراق الشبكة.';
      case DeauthSeverity.medium:
        return 'راقب الاتصال. إذا تكرر، تواصل مع مسؤول الشبكة.';
      case DeauthSeverity.low:
        return 'قد يكون انقطاع عادي. لا حاجة لقلق الآن.';
    }
  }
}

enum DeauthSeverity { critical, high, medium, low }
