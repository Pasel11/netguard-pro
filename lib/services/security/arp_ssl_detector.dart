import 'dart:io';
import 'dart:async';
import 'package:netguard_pro/services/local/network_discovery.dart';

/// كاشف تسمم ARP (ARP Poisoning / ARP Spoofing)
/// 
/// ARP spoofing هو هجوم يرسل فيه المهاجم رسائل ARP وهمية
/// لربط MAC الخاصه بعنوان IP شخص آخر (غالباً الراوتر)
/// 
/// هذا يسمح للمهاجم بـ:
/// - اعتراض حركة المرور (MITM)
/// - تعديل الحزم
/// - سرقة كلمات المرور
class ArpPoisoningDetector {
  Timer? _monitorTimer;
  bool _isMonitoring = false;
  
  // الخريطة المعروفة: IP -> MAC الصحيح
  final Map<String, String> _knownIpToMac = {};
  // الخريطة الحالية
  final Map<String, String> _currentIpToMac = {};
  
  final List<ArpPoisoningAlert> _alerts = [];
  final StreamController<ArpPoisoningAlert> _alertController = StreamController.broadcast();
  
  Stream<ArpPoisoningAlert> get alertStream => _alertController.stream;
  List<ArpPoisoningAlert> get alerts => List.unmodifiable(_alerts);
  bool get isMonitoring => _isMonitoring;
  
  /// بدء المراقبة
  Future<bool> startMonitoring({Duration interval = const Duration(seconds: 30)}) async {
    if (_isMonitoring) return false;
    
    // الحصول على الـ baseline
    await _buildBaseline();
    
    if (_knownIpToMac.isEmpty) return false;
    
    _isMonitoring = true;
    _monitorTimer = Timer.periodic(interval, (_) => _checkArpTable());
    
    return true;
  }
  
  /// إيقاف المراقبة
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
  }
  
  /// بناء baseline من الأجهزة المعروفة
  Future<void> _buildBaseline() async {
    final devices = await NetworkDiscovery.discoverViaArp();
    
    for (final device in devices) {
      if (device.mac != 'Unknown' && _isValidMac(device.mac)) {
        _knownIpToMac[device.ip] = device.mac;
      }
    }
  }
  
  /// فحص ARP table للكشف عن التغييرات
  Future<void> _checkArpTable() async {
    if (!_isMonitoring) return;
    
    try {
      final file = File('/proc/net/arp');
      if (!await file.exists()) return;
      
      final lines = await file.readAsLines();
      _currentIpToMac.clear();
      
      for (var i = 1; i < lines.length; i++) {
        final parts = lines[i].split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final ip = parts[0];
          final mac = parts[3].toUpperCase();
          
          if (mac != '00:00:00:00:00:00' && _isValidIp(ip) && _isValidMac(mac)) {
            _currentIpToMac[ip] = mac;
          }
        }
      }
      
      // مقارنة مع الـ baseline
      for (final entry in _currentIpToMac.entries) {
        final ip = entry.key;
        final mac = entry.value;
        final knownMac = _knownIpToMac[ip];
        
        if (knownMac != null && knownMac != mac) {
          // تم تغيير MAC! هذا ARP spoofing
          _addAlert(ArpPoisoningAlert(
            type: ArpPoisoningType.macChanged,
            severity: ArpPoisoningSeverity.critical,
            ip: ip,
            originalMac: knownMac,
            spoofedMac: mac,
            description: 'تم تغيير MAC لـ $ip من $knownMac إلى $mac!',
            recommendation: 'قد يكون هناك هجوم ARP spoofing. افصل الشبكة فوراً!',
            timestamp: DateTime.now(),
          ));
        }
      }
      
      // كشف MACs مكررة (عدة IPs تستخدم نفس MAC)
      final macToIps = <String, List<String>>{};
      for (final entry in _currentIpToMac.entries) {
        macToIps[entry.value] ??= [];
        macToIps[entry.value]!.add(entry.key);
      }
      
      for (final entry in macToIps.entries) {
        if (entry.value.length > 1) {
          // نفس MAC لعدة IPs!
          _addAlert(ArpPoisoningAlert(
            type: ArpPoisoningType.duplicateMac,
            severity: ArpPoisoningSeverity.high,
            ip: entry.value.join(', '),
            originalMac: 'Multiple',
            spoofedMac: entry.key,
            description: 'الـ MAC ${entry.key} يستخدم لعدة IPs: ${entry.value.join(", ")}',
            recommendation: 'قد يكون هناك هجوم MITM. تحقق من الأجهزة المتصلة.',
            timestamp: DateTime.now(),
          ));
        }
      }
      
      // كشف جهاز جديد غير معروف
      for (final entry in _currentIpToMac.entries) {
        if (!_knownIpToMac.containsKey(entry.key)) {
          _addAlert(ArpPoisoningAlert(
            type: ArpPoisoningType.newDevice,
            severity: ArpPoisoningSeverity.medium,
            ip: entry.key,
            originalMac: 'Unknown',
            spoofedMac: entry.value,
            description: 'جهاز جديد على الشبكة: ${entry.key} (${entry.value})',
            recommendation: 'تحقق من هوية الجهاز الجديد.',
            timestamp: DateTime.now(),
          ));
        }
      }
    } catch (_) {}
  }
  
  /// فحص شامل واحد
  Future<List<ArpPoisoningAlert>> performFullScan() async {
    if (_knownIpToMac.isEmpty) {
      await _buildBaseline();
    }
    
    await _checkArpTable();
    return _alerts;
  }
  
  /// تحديث الـ baseline
  Future<void> updateBaseline() async {
    _knownIpToMac.clear();
    await _buildBaseline();
  }
  
  void _addAlert(ArpPoisoningAlert alert) {
    // منع التكرار خلال 5 دقائق
    final recentAlert = _alerts.lastWhere(
      (a) => a.ip == alert.ip && 
             a.spoofedMac == alert.spoofedMac &&
             DateTime.now().difference(a.timestamp) < const Duration(minutes: 5),
      orElse: () => ArpPoisoningAlert(
        type: ArpPoisoningType.newDevice,
        severity: ArpPoisoningSeverity.low,
        ip: '',
        originalMac: '',
        spoofedMac: '',
        description: '',
        recommendation: '',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    
    if (recentAlert.ip.isEmpty) {
      _alerts.add(alert);
      _alertController.add(alert);
    }
  }
  
  bool _isValidIp(String ip) {
    return RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(ip);
  }
  
  bool _isValidMac(String mac) {
    return RegExp(r'^([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}$').hasMatch(mac);
  }
  
  void clearAlerts() {
    _alerts.clear();
  }
  
  void dispose() {
    stopMonitoring();
    _alertController.close();
  }
}

class ArpPoisoningAlert {
  final ArpPoisoningType type;
  final ArpPoisoningSeverity severity;
  final String ip;
  final String originalMac;
  final String spoofedMac;
  final String description;
  final String recommendation;
  final DateTime timestamp;
  
  ArpPoisoningAlert({
    required this.type,
    required this.severity,
    required this.ip,
    required this.originalMac,
    required this.spoofedMac,
    required this.description,
    required this.recommendation,
    required this.timestamp,
  });
}

enum ArpPoisoningType {
  macChanged,        // MAC تغيّر لنفس IP
  duplicateMac,      // نفس MAC لعدة IPs
  newDevice,         // جهاز جديد غير معروف
  gatewayChanged,    // MAC الراوتر تغيّر
}

enum ArpPoisoningSeverity { critical, high, medium, low }


/// كاشف SSL Stripping
/// 
/// SSL Strip هو هجوم يحوّل HTTPS إلى HTTP
/// ليتمكن المهاجم من قراءة البيانات غير المشفّرة
class SslStripDetector {
  /// فحص شامل لـ SSL stripping
  Future<SslStripResult> performScan({List<String>? testUrls}) async {
    final results = <SslStripTestResult>[];
    final urls = testUrls ?? _getDefaultTestUrls();
    
    for (final url in urls) {
      final result = await _testSslStripping(url);
      results.add(result);
    }
    
    // تحليل النتائج
    final hasStripping = results.any((r) => r.isStripped);
    final issues = _identifyIssues(results);
    final recommendations = _generateRecommendations(hasStripping, issues);
    
    return SslStripResult(
      hasStripping: hasStripping,
      testResults: results,
      issues: issues,
      recommendations: recommendations,
      timestamp: DateTime.now(),
    );
  }
  
  /// قائمة المواقع للاختبار
  List<String> _getDefaultTestUrls() {
    return [
      'https://www.google.com',
      'https://www.facebook.com',
      'https://www.twitter.com',
      'https://www.github.com',
      'https://www.cloudflare.com',
    ];
  }
  
  /// اختبار SSL stripping على موقع واحد
  Future<SslStripTestResult> _testSslStripping(String url) async {
    try {
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 10);
      
      // محاولة HTTPS
      final httpsRequest = await httpClient.getUrl(Uri.parse(url));
      final httpsResponse = await httpsRequest.close();
      
      final httpsStatus = httpsResponse.statusCode;
      final httpsHeaders = httpsResponse.headers;
      
      // قراءة body
      final httpsBody = await httpsResponse.transform(const SystemEncoding().decoder).join();
      httpClient.close();
      
      // محاولة HTTP (يجب أن يحدث redirect إلى HTTPS)
      final httpUrl = url.replaceAll('https://', 'http://');
      final httpClient2 = HttpClient();
      httpClient2.connectionTimeout = const Duration(seconds: 10);
      
      final httpRequest = await httpClient2.getUrl(Uri.parse(httpUrl));
      final httpResponse = await httpRequest.close();
      
      final httpStatus = httpResponse.statusCode;
      final httpLocation = httpResponse.headers.value('location');
      
      httpClient2.close();
      
      // تحليل
      bool isStripped = false;
      String description = '';
      
      // إذا كان HTTP يرجع 200 (لا redirect)، قد يكون stripping
      if (httpStatus == 200 && httpLocation == null) {
        isStripped = true;
        description = 'HTTP لا يعيد التوجيه إلى HTTPS - قد يكون SSL stripping';
      }
      
      // إذا كان HTTP يعيد التوجيه لـ HTTP بدلاً من HTTPS
      if (httpLocation != null && httpLocation.startsWith('http://')) {
        isStripped = true;
        description = 'HTTP يعيد التوجيه إلى HTTP بدلاً من HTTPS!';
      }
      
      // فحص HSTS header
      final hasHsts = httpsHeaders.value('strict-transport-security') != null;
      if (!hasHsts && !isStripped) {
        description = 'الموقع لا يستخدم HSTS - عرضة لـ SSL stripping';
      }
      
      return SslStripTestResult(
        url: url,
        httpsStatus: httpsStatus,
        httpStatus: httpStatus,
        httpRedirectLocation: httpLocation,
        hasHsts: hasHsts,
        isStripped: isStripped,
        description: description,
        responseSize: httpsBody.length,
      );
    } catch (e) {
      return SslStripTestResult(
        url: url,
        httpsStatus: 0,
        httpStatus: 0,
        httpRedirectLocation: null,
        hasHsts: false,
        isStripped: false,
        description: 'Error: $e',
        responseSize: 0,
        error: e.toString(),
      );
    }
  }
  
  /// تحديد المشاكل
  List<String> _identifyIssues(List<SslStripTestResult> results) {
    final issues = <String>[];
    
    for (final result in results) {
      if (result.isStripped) {
        issues.add('🔴 ${result.url}: ${result.description}');
      } else if (!result.hasHsts && result.error == null) {
        issues.add('🟡 ${result.url}: لا يستخدم HSTS');
      }
    }
    
    return issues;
  }
  
  /// توليد التوصيات
  List<String> _generateRecommendations(bool hasStripping, List<String> issues) {
    final recommendations = <String>[];
    
    if (hasStripping) {
      recommendations.add('🚨 تم اكتشاف احتمال SSL stripping!');
      recommendations.add('افصل عن الشبكة فوراً واستخدم VPN');
      recommendations.add('استخدم HTTPS Everywhere في المتصفح');
      recommendations.add('فعّل HSTS في المتصفح');
    } else {
      recommendations.add('✅ لا يوجد SSL stripping واضح');
    }
    
    recommendations.add('استخدم متصفح Brave مع Shields UP');
    recommendations.add('فعّل "HTTPS-Only Mode" في Firefox/Chrome');
    recommendations.add('تجنب إدخال كلمات المرور على شبكات WiFi عامة');
    
    return recommendations;
  }
}

class SslStripResult {
  final bool hasStripping;
  final List<SslStripTestResult> testResults;
  final List<String> issues;
  final List<String> recommendations;
  final DateTime timestamp;
  
  SslStripResult({
    required this.hasStripping,
    required this.testResults,
    required this.issues,
    required this.recommendations,
    required this.timestamp,
  });
}

class SslStripTestResult {
  final String url;
  final int httpsStatus;
  final int httpStatus;
  final String? httpRedirectLocation;
  final bool hasHsts;
  final bool isStripped;
  final String description;
  final int responseSize;
  final String? error;
  
  SslStripTestResult({
    required this.url,
    required this.httpsStatus,
    required this.httpStatus,
    required this.httpRedirectLocation,
    required this.hasHsts,
    required this.isStripped,
    required this.description,
    required this.responseSize,
    this.error,
  });
}
