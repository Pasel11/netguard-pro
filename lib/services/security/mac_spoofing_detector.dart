import 'dart:async';
import 'package:netguard_pro/services/local/network_discovery.dart';

/// كاشف تزييف MAC (MAC Spoofing Detection)
/// 
/// MAC Spoofing هو انتحال عنوان MAC لجهاز آخر
/// يستخدمه المهاجمون لـ:
/// - تجاوز فلتر MAC في الراوتر
/// - انتحال شخصية جهاز موثوق
/// - إخفاء هويتهم
class MacSpoofingDetector {
  final Map<String, DeviceRecord> _deviceHistory = {}; // MAC -> سجل
  final List<MacSpoofingAlert> _alerts = [];
  final StreamController<MacSpoofingAlert> _alertController = StreamController.broadcast();
  
  // قاعدة بيانات لأشهر OUIs (Organizationally Unique Identifier)
  static const Map<String, String> _ouiDatabase = {
    'F8F8F8': 'TP-Link',
    '0019E0': 'D-Link',
    '001A6B': 'Cisco',
    'C46115': 'Huawei',
    '00E04C': 'ASUSTek',
    'F099B6': 'Apple',
    '001DE0': 'Samsung',
    '00235C': 'Xiaomi',
    '002128': 'Dell',
    '00C0EE': 'HP',
    'B827EB': 'Raspberry Pi',
    '5CCF7F': 'Espressif',
    'D8F15E': 'Google',
    '4201D6': 'Amazon',
  };
  
  Stream<MacSpoofingAlert> get alertStream => _alertController.stream;
  List<MacSpoofingAlert> get alerts => List.unmodifiable(_alerts);
  
  /// بدء الفحص
  Future<List<MacSpoofingAlert>> performScan() async {
    _alerts.clear();
    
    try {
      // 1. الحصول على الأجهزة الحالية
      final currentDevices = await NetworkDiscovery.discoverViaArp();
      
      // 2. مقارنة مع السجل
      for (final device in currentDevices) {
        if (device.mac == 'Unknown') continue;
        
        final existing = _deviceHistory[device.mac];
        
        if (existing == null) {
          // جهاز جديد - نسجله
          _deviceHistory[device.mac] = DeviceRecord(
            mac: device.mac,
            vendor: device.vendor,
            firstSeen: DateTime.now(),
            lastSeen: DateTime.now(),
            knownIps: {device.ip},
          );
        } else {
          // جهاز معروف - نتحقق من التغييرات
          _checkForSpoofing(existing, device);
          
          // تحديث السجل
          existing.lastSeen = DateTime.now();
          existing.knownIps.add(device.ip);
        }
      }
      
      // 3. فحص تناسق OUI
      for (final device in currentDevices) {
        if (device.mac == 'Unknown') continue;
        _checkOuiConsistency(device);
      }
      
      // 4. فحص الأجهزة بنفس IP لكن MAC مختلف
      _checkForIpMacChanges(currentDevices);
      
      return _alerts;
    } catch (_) {
      return [];
    }
  }
  
  /// فحص التناسق بين MAC والـ vendor المعلن
  void _checkOuiConsistency(DiscoveredDevice device) {
    final oui = device.mac.replaceAll(RegExp(r'[:\-]'), '').toUpperCase().substring(0, 6);
    final expectedVendor = _ouiDatabase[oui];
    
    if (expectedVendor != null && 
        device.vendor != 'Unknown' && 
        device.vendor != expectedVendor) {
      // المورد المعلن لا يطابق OUI
      _addAlert(MacSpoofingAlert(
        type: MacSpoofingType.vendorMismatch,
        severity: MacSpoofingSeverity.high,
        mac: device.mac,
        ip: device.ip,
        expectedVendor: expectedVendor,
        detectedVendor: device.vendor,
        description: 'عنوان MAC ${device.mac} مُسجّل لشركة $expectedVendor لكن الجهاز يعلن أنه $device.vendor',
        recommendation: 'قد يكون الجهاز يستخدم MAC مزيف. تحقق من هوية الجهاز.',
        timestamp: DateTime.now(),
      ));
    }
  }
  
  /// فحص تغير MAC لنفس IP
  void _checkForIpMacChanges(List<DiscoveredDevice> currentDevices) {
    final ipToMacs = <String, Set<String>>{};
    
    for (final device in currentDevices) {
      if (device.mac == 'Unknown') continue;
      ipToMacs[device.ip] ??= {};
      ipToMacs[device.ip]!.add(device.mac);
    }
    
    for (final entry in ipToMacs.entries) {
      if (entry.value.length > 1) {
        // نفس IP يستخدم MACs مختلفة!
        _addAlert(MacSpoofingAlert(
          type: MacSpoofingType.ipMacChange,
          severity: MacSpoofingSeverity.critical,
          mac: entry.value.join(', '),
          ip: entry.key,
          expectedVendor: 'Multiple',
          detectedVendor: 'Multiple',
          description: 'IP ${entry.key} يستخدم عناوين MAC متعددة: ${entry.value.join(", ")}',
          recommendation: 'هذا قد يكون MAC spoofing أو جهاز يستخدم MAC randomization. تحقق فوراً.',
          timestamp: DateTime.now(),
        ));
      }
    }
  }
  
  /// فحص جهاز معين
  void _checkForSpoofing(DeviceRecord existing, DiscoveredDevice current) {
    // فحص تغير المورد
    if (existing.vendor != current.vendor && 
        existing.vendor != 'Unknown' && 
        current.vendor != 'Unknown') {
      _addAlert(MacSpoofingAlert(
        type: MacSpoofingType.vendorChanged,
        severity: MacSpoofingSeverity.high,
        mac: current.mac,
        ip: current.ip,
        expectedVendor: existing.vendor,
        detectedVendor: current.vendor,
        description: 'الجهاز ${current.mac} غيّر المورد من ${existing.vendor} إلى ${current.vendor}',
        recommendation: 'هذا غير طبيعي. قد يكون جهاز آخر يستخدم نفس MAC.',
        timestamp: DateTime.now(),
      ));
    }
    
    // فحص تكرار MAC على عدة IPs
    if (existing.knownIps.length > 3) {
      _addAlert(MacSpoofingAlert(
        type: MacSpoofingType.multipleIps,
        severity: MacSpoofingSeverity.medium,
        mac: current.mac,
        ip: current.ip,
        expectedVendor: existing.vendor,
        detectedVendor: current.vendor,
        description: 'الجهاز ${current.mac} يستخدم ${existing.knownIps.length} IPs مختلفة',
        recommendation: 'قد يكون جهاز يتصل بـ DHCP عدة مرات أو محاولة انتحال.',
        timestamp: DateTime.now(),
      ));
    }
  }
  
  /// كشف MAC randomization (ميزة في الهواتف الحديثة)
  bool isRandomizedMac(String mac) {
    // MACs العشوائية تبدأ غالباً بـ:
    // 02:xx:xx:xx (locally administered)
    // 06:xx:xx:xx
    // 0A:xx:xx:xx
    // 0E:xx:xx:xx
    final firstByte = mac.substring(0, 2).toUpperCase();
    final firstBit = int.parse(firstByte, radix: 16) & 0x02;
    return firstBit != 0;
  }
  
  /// تحليل MAC address
  MacAnalysis analyzeMac(String mac) {
    final oui = mac.replaceAll(RegExp(r'[:\-]'), '').toUpperCase().substring(0, 6);
    final vendor = _ouiDatabase[oui] ?? 'Unknown';
    final isRandom = isRandomizedMac(mac);
    final isLocal = _isLocallyAdministered(mac);
    final isMulticast = _isMulticast(mac);
    
    return MacAnalysis(
      mac: mac,
      oui: oui,
      vendor: vendor,
      isRandomized: isRandom,
      isLocallyAdministered: isLocal,
      isMulticast: isMulticast,
      type: _determineMacType(isLocal, isMulticast, isRandom),
    );
  }
  
  bool _isLocallyAdministered(String mac) {
    final firstByte = int.parse(mac.substring(0, 2), radix: 16);
    return (firstByte & 0x02) != 0;
  }
  
  bool _isMulticast(String mac) {
    final firstByte = int.parse(mac.substring(0, 2), radix: 16);
    return (firstByte & 0x01) != 0;
  }
  
  String _determineMacType(bool isLocal, bool isMulticast, bool isRandom) {
    if (isMulticast) return 'Multicast';
    if (isRandom) return 'Randomized (Locally Administered)';
    if (isLocal) return 'Locally Administered';
    return 'Universal (Vendor Assigned)';
  }
  
  void _addAlert(MacSpoofingAlert alert) {
    _alerts.add(alert);
    _alertController.add(alert);
  }
  
  void clearAlerts() {
    _alerts.clear();
  }
  
  void clearHistory() {
    _deviceHistory.clear();
  }
  
  void dispose() {
    _alertController.close();
  }
}

class DeviceRecord {
  final String mac;
  final String vendor;
  final DateTime firstSeen;
  DateTime lastSeen;
  Set<String> knownIps;
  
  DeviceRecord({
    required this.mac,
    required this.vendor,
    required this.firstSeen,
    required this.lastSeen,
    required this.knownIps,
  });
}

class MacSpoofingAlert {
  final MacSpoofingType type;
  final MacSpoofingSeverity severity;
  final String mac;
  final String ip;
  final String expectedVendor;
  final String detectedVendor;
  final String description;
  final String recommendation;
  final DateTime timestamp;
  
  MacSpoofingAlert({
    required this.type,
    required this.severity,
    required this.mac,
    required this.ip,
    required this.expectedVendor,
    required this.detectedVendor,
    required this.description,
    required this.recommendation,
    required this.timestamp,
  });
}

enum MacSpoofingType {
  vendorMismatch,    // المورد لا يطابق OUI
  vendorChanged,     // المورد تغيّر
  ipMacChange,       // IP يستخدم MACs متعددة
  multipleIps,       // MAC يستخدم IPs متعددة
  randomizedMac,     // MAC عشوائي
}

enum MacSpoofingSeverity { critical, high, medium, low }

class MacAnalysis {
  final String mac;
  final String oui;
  final String vendor;
  final bool isRandomized;
  final bool isLocallyAdministered;
  final bool isMulticast;
  final String type;
  
  MacAnalysis({
    required this.mac,
    required this.oui,
    required this.vendor,
    required this.isRandomized,
    required this.isLocallyAdministered,
    required this.isMulticast,
    required this.type,
  });
}
