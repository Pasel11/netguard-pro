import 'dart:io';
import 'dart:async';

/// فاحص أجهزة Bluetooth
/// يكتشف الأجهزة القريبة وخدماتها
class BluetoothScanner {
  Process? _hcitoolProcess;
  bool _isScanning = false;
  final List<BluetoothDevice> _devices = [];
  final StreamController<BluetoothDevice> _deviceController = StreamController.broadcast();
  
  Stream<BluetoothDevice> get deviceStream => _deviceController.stream;
  List<BluetoothDevice> get devices => List.unmodifiable(_devices);
  bool get isScanning => _isScanning;
  
  /// بدء الفحص
  Future<bool> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isScanning) return false;
    
    try {
      // التحقق من توفر hcitool
      final whichResult = await Process.run('which', ['hcitool']);
      if (whichResult.exitCode != 0) {
        return false;
      }
      
      _isScanning = true;
      _devices.clear();
      
      // بدء الفحص
      _hcitoolProcess = await Process.start('hcitool', ['scan', '--flush']);
      
      final output = <String>[];
      _hcitoolProcess!.stdout.transform(const SystemEncoding().decoder).listen(
        (data) {
          output.add(data);
          _parseScanOutput(data);
        },
        onDone: () {
          _isScanning = false;
          // بعد الفحص، نحصل على معلومات إضافية لكل جهاز
          _getDetailedInfo();
        },
      );
      
      // timeout
      Timer(timeout, () => stopScan());
      
      return true;
    } catch (_) {
      _isScanning = false;
      return false;
    }
  }
  
  /// إيقاف الفحص
  Future<void> stopScan() async {
    if (_hcitoolProcess != null) {
      _hcitoolProcess!.kill(ProcessSignal.sigterm);
      await _hcitoolProcess!.exitCode;
      _hcitoolProcess = null;
    }
    _isScanning = false;
  }
  
  /// تحليل ناتج الفحص
  void _parseScanOutput(String data) {
    final lines = data.split('\n');
    
    for (final line in lines) {
      // مثال: AA:BB:CC:DD:EE:FF Device Name
      final match = RegExp(
        r'([0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2})\s+(.+)'
      ).firstMatch(line.trim());
      
      if (match != null) {
        final mac = match.group(1)!.toUpperCase();
        final name = match.group(2)!.trim();
        
        final device = BluetoothDevice(
          mac: mac,
          name: name,
          vendor: _getVendorFromOui(mac),
          type: _guessDeviceType(name),
          discoveredAt: DateTime.now(),
        );
        
        if (!_devices.any((d) => d.mac == mac)) {
          _devices.add(device);
          _deviceController.add(device);
        }
      }
    }
  }
  
  /// الحصول على معلومات إضافية لكل جهاز
  Future<void> _getDetailedInfo() async {
    for (final device in _devices) {
      try {
        // الحصول على معلومات الجهاز
        final infoResult = await Process.run(
          'hcitool', ['info', device.mac],
        ).timeout(const Duration(seconds: 5));
        
        if (infoResult.exitCode == 0) {
          final info = infoResult.stdout.toString();
          _parseDeviceInfo(device, info);
        }
        
        // الحصول على الخدمات
        final servicesResult = await Process.run(
          'sdptool', ['browse', device.mac],
        ).timeout(const Duration(seconds: 5));
        
        if (servicesResult.exitCode == 0) {
          final services = servicesResult.stdout.toString();
          device.services = _parseServices(services);
        }
      } catch (_) {}
    }
  }
  
  /// تحليل معلومات الجهاز
  void _parseDeviceInfo(BluetoothDevice device, String info) {
    // اسم الجهاز
    final nameMatch = RegExp(r'Name:\s*(.+)').firstMatch(info);
    if (nameMatch != null && device.name == 'Unknown') {
      device.name = nameMatch.group(1)!.trim();
    }
    
    // فئة الجهاز
    final classMatch = RegExp(r'Class:\s*(0x[0-9A-Fa-f]+)').firstMatch(info);
    if (classMatch != null) {
      device.deviceClass = classMatch.group(1)!;
      device.type = _getClassType(device.deviceClass!);
    }
    
    // قوة الإشارة
    final rssiMatch = RegExp(r'RSSI:\s*(-?\d+)').firstMatch(info);
    if (rssiMatch != null) {
      device.rssi = int.tryParse(rssiMatch.group(1)!);
    }
    
    // Hersteller (manufacturer)
    final mfrMatch = RegExp(r'Manufacturer:\s*(.+)').firstMatch(info);
    if (mfrMatch != null) {
      device.manufacturer = mfrMatch.group(1)!.trim();
    }
  }
  
  /// تحليل الخدمات
  List<BluetoothService> _parseServices(String services) {
    final result = <BluetoothService>[];
    final lines = services.split('\n');
    
    BluetoothService? currentService;
    
    for (final line in lines) {
      // Service Name: ServiceName
      final nameMatch = RegExp(r'Service Name:\s*(.+)').firstMatch(line);
      if (nameMatch != null) {
        if (currentService != null) result.add(currentService);
        currentService = BluetoothService(name: nameMatch.group(1)!.trim());
        continue;
      }
      
      // Protocol: <protocol>
      final protoMatch = RegExp(r'Protocol:\s*(\S+)').firstMatch(line);
      if (protoMatch != null && currentService != null) {
        currentService.protocol = protoMatch.group(1)!;
      }
      
      // Port: <port>
      final portMatch = RegExp(r'Port:\s*(\d+)').firstMatch(line);
      if (portMatch != null && currentService != null) {
        currentService.port = int.tryParse(portMatch.group(1)!) ?? 0;
      }
    }
    
    if (currentService != null) result.add(currentService);
    return result;
  }
  
  /// كشف نوع الجهاز من الاسم
  String _guessDeviceType(String name) {
    final n = name.toLowerCase();
    if (n.contains('iphone') || n.contains('samsung') || n.contains('huawei') || 
        n.contains('xiaomi') || n.contains('pixel') || n.contains('oneplus')) {
      return 'Smartphone';
    }
    if (n.contains('airpods') || n.contains('earbuds') || n.contains('buds')) {
      return 'Earbuds';
    }
    if (n.contains('watch')) return 'Smartwatch';
    if (n.contains('speaker')) return 'Speaker';
    if (n.contains('tv')) return 'Smart TV';
    if (n.contains('keyboard')) return 'Keyboard';
    if (n.contains('mouse')) return 'Mouse';
    if (n.contains('headphone')) return 'Headphones';
    if (n.contains('laptop') || n.contains('macbook')) return 'Laptop';
    return 'Unknown';
  }
  
  /// فئة الجهاز من device class
  String _getClassType(String deviceClass) {
    final code = int.tryParse(deviceClass.replaceAll('0x', ''), radix: 16) ?? 0;
    final majorClass = (code >> 8) & 0x1F;
    
    switch (majorClass) {
      case 0: return 'Miscellaneous';
      case 1: return 'Computer';
      case 2: return 'Phone';
      case 3: return 'LAN/Network Access Point';
      case 4: return 'Audio/Video';
      case 5: return 'Peripheral (Mouse, Keyboard, etc.)';
      case 6: return 'Imaging (Printer, Scanner, Camera)';
      case 7: return 'Wearable';
      case 8: return 'Toy';
      case 9: return 'Health';
      default: return 'Uncategorized';
    }
  }
  
  /// الحصول على المورد من OUI
  String _getVendorFromOui(String mac) {
    final oui = mac.substring(0, 8).toUpperCase();
    
    const ouiDb = {
      'F8:F8:F8': 'Apple',
      '00:1D:4F': 'Apple',
      'AC:DE:48': 'Apple',
      '00:1B:63': 'Apple',
      '00:26:08': 'Apple',
      '00:1F:F3': 'Apple',
      '00:25:00': 'Apple',
      '00:23:DF': 'Apple',
      '00:1E:52': 'Apple',
      '00:1C:B3': 'Apple',
      '00:17:F2': 'Apple',
      '00:16:CB': 'Apple',
      '00:15:00': 'Apple',
      '00:14:51': 'Apple',
      '00:13:95': 'Apple',
      '00:12:25': 'Apple',
      '00:11:24': 'Apple',
      '00:10:FA': 'Apple',
      '00:0D:93': 'Apple',
      '00:0C:E5': 'Apple',
      '00:0B:5C': 'Apple',
      '00:0A:95': 'Apple',
      '00:09:DD': 'Apple',
      '00:08:5B': 'Apple',
      '00:07:2D': 'Apple',
      '00:06:5B': 'Apple',
      '00:05:02': 'Apple',
      '00:03:93': 'Apple',
      '00:02:78': 'Apple',
      '00:01:E1': 'Apple',
      '00:00:F0': 'Apple',
      // Samsung
      '00:12:FB': 'Samsung',
      '00:16:FB': 'Samsung',
      '00:1B:6E': 'Samsung',
      '00:1F:1C': 'Samsung',
      '00:21:19': 'Samsung',
      '00:24:54': 'Samsung',
      '00:25:38': 'Samsung',
      '00:30:91': 'Samsung',
      '00:50:18': 'Samsung',
      '00:71:47': 'Samsung',
      '00:76:6C': 'Samsung',
      // Huawei
      '00:0E:35': 'Huawei',
      '00:25:9E': 'Huawei',
      '00:46:4B': 'Huawei',
      '00:E0:FC': 'Huawei',
      '04:02:1F': 'Huawei',
      '04:33:88': 'Huawei',
      '04:4F:4C': 'Huawei',
      '04:66:14': 'Huawei',
      '04:C0:5F': 'Huawei',
      '04:E6:76': 'Huawei',
      '08:19:A6': 'Huawei',
      // Xiaomi
      '64:09:80': 'Xiaomi',
      '7C:1C:4E': 'Xiaomi',
      '8C:F2:1A': 'Xiaomi',
      // Others
      '00:1A:6B': 'Cisco',
      '00:17:02': 'Cisco',
      '00:1E:4A': 'Cisco',
      'F0:F8:F2': 'TP-Link',
      '00:19:E0': 'D-Link',
      '00:15:C5': 'Belkin',
    };
    
    return ouiDb[oui] ?? 'Unknown';
  }
  
  /// كشف تتبع Bluetooth (BT tracking)
  Future<bool> detectBluetoothTracking() async {
    // فحص إذا كان هناك جهاز يتبعك
    // يعمل فحصين متتاليين ويقارن
    
    final firstScan = await _quickScan();
    await Future.delayed(const Duration(seconds: 5));
    final secondScan = await _quickScan();
    
    // البحث عن أجهزة ظهرت في الفحصين
    final tracked = firstScan.where(
      (d1) => secondScan.any((d2) => d2.mac == d1.mac),
    ).toList();
    
    return tracked.isNotEmpty;
  }
  
  Future<List<BluetoothDevice>> _quickScan() async {
    try {
      final result = await Process.run('hcitool', ['scan'])
          .timeout(const Duration(seconds: 10));
      
      final devices = <BluetoothDevice>[];
      final lines = result.stdout.toString().split('\n');
      
      for (final line in lines) {
        final match = RegExp(
          r'([0-9A-Fa-f:]{17})\s+(.+)'
        ).firstMatch(line.trim());
        
        if (match != null) {
          devices.add(BluetoothDevice(
            mac: match.group(1)!.toUpperCase(),
            name: match.group(2)!.trim(),
            vendor: _getVendorFromOui(match.group(1)!),
            type: _guessDeviceType(match.group(2)!),
            discoveredAt: DateTime.now(),
          ));
        }
      }
      
      return devices;
    } catch (_) {
      return [];
    }
  }
  
  void dispose() {
    stopScan();
    _deviceController.close();
  }
}

class BluetoothDevice {
  String mac;
  String name;
  String vendor;
  String type;
  DateTime discoveredAt;
  String? deviceClass;
  int? rssi;
  String? manufacturer;
  List<BluetoothService> services;
  
  BluetoothDevice({
    required this.mac,
    required this.name,
    required this.vendor,
    required this.type,
    required this.discoveredAt,
    this.deviceClass,
    this.rssi,
    this.manufacturer,
    List<BluetoothService>? services,
  }) : services = services ?? [];
  
  String get signalQuality {
    if (rssi == null) return 'Unknown';
    if (rssi! >= -50) return 'Excellent';
    if (rssi! >= -65) return 'Good';
    if (rssi! >= -75) return 'Fair';
    return 'Poor';
  }
  
  bool get isTrackable => name != 'Unknown' && vendor != 'Unknown';
}

class BluetoothService {
  String name;
  String? protocol;
  int? port;
  
  BluetoothService({
    required this.name,
    this.protocol,
    this.port,
  });
}
