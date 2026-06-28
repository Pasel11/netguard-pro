import 'dart:io';
import 'dart:async';
import 'package:netguard_pro/services/local/network_discovery.dart';
import 'package:netguard_pro/services/local/wifi_info_service.dart';

/// كاشف نقاط الوصول المزيفة (Rogue Access Point)
/// 
/// Rogue AP هو راوتر وهمي ينتحل شخصية الراوتر الحقيقي
/// يستخدمه المهاجمون لـ:
/// - اعتراض حركة المرور (MITM)
/// - سرقة كلمات المرور
/// - هجمات Evil Twin
class RogueApDetector {
  bool _isScanning = false;
  final List<AccessPoint> _knownAps = [];
  final List<RogueApAlert> _alerts = [];
  final StreamController<RogueApAlert> _alertController = StreamController.broadcast();
  
  Stream<RogueApAlert> get alertStream => _alertController.stream;
  List<RogueApAlert> get alerts => List.unmodifiable(_alerts);
  bool get isScanning => _isScanning;
  
  /// بدء فحص شامل
  Future<List<RogueApAlert>> performFullScan() async {
    if (_isScanning) return [];
    
    _isScanning = true;
    _alerts.clear();
    
    try {
      // 1. الحصول على معلومات الشبكة الحالية
      final currentNetwork = await NetworkDiscovery.getCurrentNetwork();
      if (currentNetwork == null) {
        _isScanning = false;
        return [];
      }
      
      // 2. فحص SSID/BSSID للشبكات القريبة
      final nearbyAps = await _scanNearbyAccessPoints();
      
      // 3. مقارنة مع الشبكة الحالية
      for (final ap in nearbyAps) {
        if (ap.ssid == currentNetwork.ssid && 
            ap.bssid != currentNetwork.bssid) {
          // SSID مطابق لكن BSSID مختلف = احتمال Rogue AP!
          _addAlert(RogueApAlert(
            type: RogueApType.evilTwin,
            severity: RogueApSeverity.critical,
            ssid: ap.ssid,
            bssid: ap.bssid,
            channel: ap.channel,
            signalStrength: ap.signalStrength,
            description: 'تم اكتشاف نقطة وصول بنفس اسم شبكتك (${ap.ssid}) لكن بعنوان MAC مختلف!',
            recommendation: 'تأكد من أنك متصل بالراوتر الصحيح. افحص BSSID في إعدادات WiFi.',
            timestamp: DateTime.now(),
          ));
        }
      }
      
      // 4. فحص قوة الإشارة (إذا كانت إشارة الراوتر المزيف أقوى، احتمال هجوم)
      final currentBssid = currentNetwork.bssid;
      if (currentBssid != 'Unknown') {
        final currentAp = nearbyAps.firstWhere(
          (ap) => ap.bssid.toUpperCase() == currentBssid.toUpperCase(),
          orElse: () => AccessPoint(
            ssid: currentNetwork.ssid,
            bssid: currentBssid,
            channel: 0,
            signalStrength: -50,
            frequency: 0,
            capabilities: '',
          ),
        );
        
        for (final ap in nearbyAps) {
          if (ap.ssid == currentNetwork.ssid && 
              ap.bssid.toUpperCase() != currentBssid.toUpperCase() &&
              ap.signalStrength > currentAp.signalStrength) {
            _addAlert(RogueApAlert(
              type: RogueApType.strongerSignal,
              severity: RogueApSeverity.high,
              ssid: ap.ssid,
              bssid: ap.bssid,
              channel: ap.channel,
              signalStrength: ap.signalStrength,
              description: 'نقطة وصول مزيفة بإشارة أقوى من الراوتر الأصلي! قد يكون المهاجم قريباً جداً.',
              recommendation: 'افصل عن WiFi فوراً واستخدم بيانات الخلوي حتى يتم التحقق.',
              timestamp: DateTime.now(),
            ));
          }
        }
      }
      
      // 5. فحص قنوات متعددة بنفس SSID
      final ssidGroups = <String, List<AccessPoint>>{};
      for (final ap in nearbyAps) {
        ssidGroups[ap.ssid] ??= [];
        ssidGroups[ap.ssid]!.add(ap);
      }
      
      for (final entry in ssidGroups.entries) {
        if (entry.value.length > 1) {
          final channels = entry.value.map((ap) => ap.channel).toSet();
          if (channels.length > 1) {
            _addAlert(RogueApAlert(
              type: RogueApType.multiChannel,
              severity: RogueApSeverity.medium,
              ssid: entry.key,
              bssid: entry.value.map((ap) => ap.bssid).join(', '),
              channel: channels.join(', '),
              signalStrength: entry.value.first.signalStrength,
              description: 'تم اكتشاف ${entry.value.length} نقاط وصول بنفس الاسم على قنوات مختلفة.',
              recommendation: 'قد يكون بعضها نقاط وصول شرعية (mesh) أو محاولة انتحال.',
              timestamp: DateTime.now(),
            ));
          }
        }
      }
      
      // 6. فحص أنواع التشفير الضعيفة
      for (final ap in nearbyAps) {
        if (ap.capabilities.contains('WEP') || 
            ap.capabilities.contains('OPEN') ||
            !ap.capabilities.contains('WPA2')) {
          _addAlert(RogueApAlert(
            type: RogueApType.weakEncryption,
            severity: RogueApSeverity.high,
            ssid: ap.ssid,
            bssid: ap.bssid,
            channel: ap.channel,
            signalStrength: ap.signalStrength,
            description: 'شبكة ${ap.ssid} تستخدم تشفير ضعيف أو مفتوح!',
            recommendation: 'لا تتصل بهذه الشبكة. يمكن اعتراض بياناتك بسهولة.',
            timestamp: DateTime.now(),
          ));
        }
      }
      
      _isScanning = false;
      return _alerts;
    } catch (_) {
      _isScanning = false;
      return [];
    }
  }
  
  /// فحص نقاط الوصول القريبة
  Future<List<AccessPoint>> _scanNearbyAccessPoints() async {
    // محاولة استخدام iwlist على Linux/Android (تحتاج root)
    try {
      final result = await Process.run('su', ['-c', 'iwlist wlan0 scan']);
      if (result.exitCode == 0) {
        return _parseIwlistOutput(result.stdout.toString());
      }
    } catch (_) {}
    
    // محاولة بديلة بدون root
    try {
      final result = await Process.run('iwlist', ['wlan0', 'scan']);
      if (result.exitCode == 0) {
        return _parseIwlistOutput(result.stdout.toString());
      }
    } catch (_) {}
    
    return [];
  }
  
  /// تحليل ناتج iwlist
  List<AccessPoint> _parseIwlistOutput(String output) {
    final aps = <AccessPoint>[];
    final lines = output.split('\n');
    
    AccessPoint? currentAp;
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      // Cell 01 - Address: AA:BB:CC:DD:EE:FF
      final cellMatch = RegExp(r'Cell \d+ - Address: ([0-9A-Fa-f:]{17})').firstMatch(trimmed);
      if (cellMatch != null) {
        if (currentAp != null) aps.add(currentAp);
        currentAp = AccessPoint(
          ssid: '',
          bssid: cellMatch.group(1)!,
          channel: 0,
          signalStrength: -100,
          frequency: 0,
          capabilities: '',
        );
        continue;
      }
      
      if (currentAp == null) continue;
      
      // ESSID:"NetworkName"
      final essidMatch = RegExp(r'ESSID:"([^"]*)"').firstMatch(trimmed);
      if (essidMatch != null) {
        currentAp = AccessPoint(
          ssid: essidMatch.group(1)!,
          bssid: currentAp.bssid,
          channel: currentAp.channel,
          signalStrength: currentAp.signalStrength,
          frequency: currentAp.frequency,
          capabilities: currentAp.capabilities,
        );
        continue;
      }
      
      // Channel:6
      final channelMatch = RegExp(r'Channel:(\d+)').firstMatch(trimmed);
      if (channelMatch != null) {
        currentAp = AccessPoint(
          ssid: currentAp.ssid,
          bssid: currentAp.bssid,
          channel: int.parse(channelMatch.group(1)!),
          signalStrength: currentAp.signalStrength,
          frequency: currentAp.frequency,
          capabilities: currentAp.capabilities,
        );
        continue;
      }
      
      // Frequency:2.437 GHz (Channel 6)
      final freqMatch = RegExp(r'Frequency:([\d.]+)\s*GHz').firstMatch(trimmed);
      if (freqMatch != null) {
        currentAp = AccessPoint(
          ssid: currentAp.ssid,
          bssid: currentAp.bssid,
          channel: currentAp.channel,
          signalStrength: currentAp.signalStrength,
          frequency: double.parse(freqMatch.group(1)!),
          capabilities: currentAp.capabilities,
        );
        continue;
      }
      
      // Quality=70/70  Signal level=-40 dBm
      final signalMatch = RegExp(r'Signal level=(-?\d+)\s*dBm').firstMatch(trimmed);
      if (signalMatch != null) {
        currentAp = AccessPoint(
          ssid: currentAp.ssid,
          bssid: currentAp.bssid,
          channel: currentAp.channel,
          signalStrength: int.parse(signalMatch.group(1)!),
          frequency: currentAp.frequency,
          capabilities: currentAp.capabilities,
        );
        continue;
      }
      
      // Encryption key:on / IE: WPA2
      if (trimmed.contains('Encryption key:on') || 
          trimmed.contains('IE:') || 
          trimmed.contains('WPA')) {
        currentAp = AccessPoint(
          ssid: currentAp.ssid,
          bssid: currentAp.bssid,
          channel: currentAp.channel,
          signalStrength: currentAp.signalStrength,
          frequency: currentAp.frequency,
          capabilities: '${currentAp.capabilities} $trimmed',
        );
      }
    }
    
    if (currentAp != null) aps.add(currentAp);
    
    return aps;
  }
  
  void _addAlert(RogueApAlert alert) {
    _alerts.add(alert);
    _alertController.add(alert);
  }
  
  void clearAlerts() {
    _alerts.clear();
  }
  
  void dispose() {
    _alertController.close();
  }
}

class AccessPoint {
  final String ssid;
  final String bssid;
  final int channel;
  final int signalStrength; // dBm
  final double frequency; // GHz
  final String capabilities;
  
  AccessPoint({
    required this.ssid,
    required this.bssid,
    required this.channel,
    required this.signalStrength,
    required this.frequency,
    required this.capabilities,
  });
  
  String get signalQuality {
    if (signalStrength >= -50) return 'ممتاز';
    if (signalStrength >= -60) return 'جيد';
    if (signalStrength >= -70) return 'متوسط';
    if (signalStrength >= -80) return 'ضعيف';
    return 'ضعيف جداً';
  }
  
  String get securityType {
    if (capabilities.contains('WPA3')) return 'WPA3';
    if (capabilities.contains('WPA2')) return 'WPA2';
    if (capabilities.contains('WPA')) return 'WPA';
    if (capabilities.contains('WEP')) return 'WEP';
    if (capabilities.contains('OPEN') || capabilities.isEmpty) return 'Open';
    return 'Unknown';
  }
}

class RogueApAlert {
  final RogueApType type;
  final RogueApSeverity severity;
  final String ssid;
  final String bssid;
  final String channel;
  final int signalStrength;
  final String description;
  final String recommendation;
  final DateTime timestamp;
  
  RogueApAlert({
    required this.type,
    required this.severity,
    required this.ssid,
    required this.bssid,
    required this.channel,
    required this.signalStrength,
    required this.description,
    required this.recommendation,
    required this.timestamp,
  });
}

enum RogueApType {
  evilTwin,        // انتحال شخصية SSID
  strongerSignal,  // إشارة أقوى من الأصلي
  multiChannel,    // عدة نقاط بنفس SSID
  weakEncryption,  // تشفير ضعيف
  hiddenSsid,      // شبكة مخفية مشبوهة
}

enum RogueApSeverity { critical, high, medium, low }
