import 'dart:io';
import 'dart:async';
import 'package:network_info_plus/network_info_plus.dart';

/// خدمة كشف أجهزة الشبكة الحقيقية
/// تستخدم ARP table + Ping + mDNS discovery
class NetworkDiscovery {
  static final NetworkInfo _networkInfo = NetworkInfo();
  
  /// الحصول على معلومات الشبكة الحالية
  static Future<NetworkDetails?> getCurrentNetwork() async {
    try {
      final ip = await _networkInfo.getWifiIP();
      final gateway = await _networkInfo.getWifiGatewayIP();
      final subnet = await _networkInfo.getWifiSubmask();
      final bssid = await _networkInfo.getWifiBSSID();
      final ssid = await _networkInfo.getWifiName();
      
      if (ip == null) return null;
      
      return NetworkDetails(
        ip: ip,
        gateway: gateway ?? '',
        subnet: subnet ?? '',
        bssid: bssid ?? '',
        ssid: ssid?.replaceAll('"', '') ?? '',
        networkBase: _getNetworkBase(ip, subnet ?? '255.255.255.0'),
      );
    } catch (e) {
      return null;
    }
  }
  
  /// كشف أجهزة الشبكة عبر ARP table
  static Future<List<DiscoveredDevice>> discoverViaArp() async {
    final devices = <DiscoveredDevice>[];
    
    try {
      // قراءة ARP table من /proc/net/arp (Linux/Android)
      final arpFile = File('/proc/net/arp');
      if (await arpFile.exists()) {
        final lines = await arpFile.readAsLines();
        
        for (var i = 1; i < lines.length; i++) {
          final parts = lines[i].split(RegExp(r'\s+'));
          if (parts.length >= 6) {
            final ip = parts[0];
            final mac = parts[3].toUpperCase();
            final type = parts[5];
            
            if (mac != '00:00:00:00:00:00' && _isValidIp(ip) && _isValidMac(mac)) {
              final vendor = _getVendorFromMac(mac);
              final deviceType = _guessDeviceType(vendor, mac);
              
              devices.add(DiscoveredDevice(
                ip: ip,
                mac: mac,
                vendor: vendor,
                type: deviceType,
                status: type == '0x2' ? 'static' : 'dynamic',
                firstSeen: DateTime.now(),
                hostname: await _resolveHostname(ip),
              ));
            }
          }
        }
      }
    } catch (_) {}
    
    return devices;
  }
  
  /// كشف الأجهزة عبر Ping Sweep
  static Future<List<DiscoveredDevice>> discoverViaPing(String networkBase) async {
    final devices = <DiscoveredDevice>[];
    final ipParts = networkBase.split('.');
    
    if (ipParts.length != 4) return devices;
    
    // فحص 1-254 في الـ subnet
    final futures = <Future<DiscoveredDevice?>>[];
    
    for (var i = 1; i < 255; i++) {
      final ip = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}.$i';
      futures.add(_pingHost(ip));
    }
    
    final results = await Future.wait(futures);
    for (final device in results) {
      if (device != null) {
        devices.add(device);
      }
    }
    
    return devices;
  }
  
  /// Ping جهاز واحد والحصول على معلوماته
  static Future<DiscoveredDevice?> _pingHost(String ip) async {
    try {
      // محاولة Ping عبر Process (تحتاج صلاحيات على بعض الأجهزة)
      final result = await Process.run('ping', ['-c', '1', '-W', '1', ip]);
      
      if (result.exitCode == 0) {
        // محاولة الحصول على MAC من ARP بعد الـ ping
        final mac = await _getMacFromArp(ip);
        final vendor = mac != null ? _getVendorFromMac(mac) : 'Unknown';
        
        return DiscoveredDevice(
          ip: ip,
          mac: mac ?? 'Unknown',
          vendor: vendor,
          type: _guessDeviceType(vendor, mac ?? ''),
          status: 'reachable',
          firstSeen: DateTime.now(),
          hostname: await _resolveHostname(ip),
          responseTime: _parsePingTime(result.stdout.toString()),
        );
      }
    } catch (_) {}
    
    return null;
  }
  
  /// فحص شامل: ARP + Ping + mDNS
  static Future<List<DiscoveredDevice>> fullDiscovery(String networkBase) async {
    final arpDevices = await discoverViaArp();
    final pingDevices = await discoverViaPing(networkBase);
    
    // دمج النتائج بدون تكرار
    final deviceMap = <String, DiscoveredDevice>{};
    
    for (final device in arpDevices) {
      deviceMap[device.ip] = device;
    }
    
    for (final device in pingDevices) {
      if (!deviceMap.containsKey(device.ip)) {
        deviceMap[device.ip] = device;
      } else {
        // تحديث المعلومات إذا كانت موجودة
        final existing = deviceMap[device.ip]!;
        deviceMap[device.ip] = DiscoveredDevice(
          ip: existing.ip,
          mac: existing.mac == 'Unknown' ? device.mac : existing.mac,
          vendor: existing.vendor == 'Unknown' ? device.vendor : existing.vendor,
          type: existing.type == 'Unknown' ? device.type : existing.type,
          status: 'reachable',
          firstSeen: existing.firstSeen,
          hostname: existing.hostname ?? device.hostname,
          responseTime: device.responseTime,
        );
      }
    }
    
    return deviceMap.values.toList()..sort((a, b) => _ipToInt(a.ip).compareTo(_ipToInt(b.ip)));
  }
  
  /// الحصول على MAC من ARP table لـ IP معين
  static Future<String?> _getMacFromArp(String ip) async {
    try {
      final result = await Process.run('arp', ['-n', ip]);
      final output = result.stdout.toString();
      
      final macMatch = RegExp(r'([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}').firstMatch(output);
      return macMatch?.group(0)?.toUpperCase();
    } catch (_) {
      return null;
    }
  }
  
  /// تحويل hostname من IP
  static Future<String?> _resolveHostname(String ip) async {
    try {
      final addresses = await InternetAddress.lookup(ip);
      if (addresses.isNotEmpty && addresses.first.host != ip) {
        return addresses.first.host;
      }
    } catch (_) {}
    return null;
  }
  
  /// Parse زمن الاستجابة من ناتج ping
  static int? _parsePingTime(String output) {
    final match = RegExp(r'time=([\d.]+)\s*ms').firstMatch(output);
    if (match != null) {
      return double.tryParse(match.group(1)!)?.round();
    }
    return null;
  }
  
  /// تحويل IP إلى رقم للمقارنة
  static int _ipToInt(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return 0;
    return (int.parse(parts[0]) << 24) |
           (int.parse(parts[1]) << 16) |
           (int.parse(parts[2]) << 8) |
           int.parse(parts[3]);
  }
  
  /// الحصول على network base من IP و subnet
  static String _getNetworkBase(String ip, String subnet) {
    final ipParts = ip.split('.').map(int.parse).toList();
    final subnetParts = subnet.split('.').map(int.parse).toList();
    
    final networkParts = <String>[];
    for (var i = 0; i < 4; i++) {
      networkParts.add((ipParts[i] & subnetParts[i]).toString());
    }
    
    return networkParts.join('.');
  }
  
  static bool _isValidIp(String ip) {
    return RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(ip);
  }
  
  static bool _isValidMac(String mac) {
    return RegExp(r'^([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}$').hasMatch(mac);
  }
  
  /// كشف نوع الجهاز من MAC address
  static String _guessDeviceType(String vendor, String mac) {
    final v = vendor.toLowerCase();
    if (v.contains('apple')) return 'Apple Device';
    if (v.contains('samsung')) return 'Samsung Device';
    if (v.contains('huawei')) return 'Huawei Device';
    if (v.contains('xiaomi')) return 'Xiaomi Device';
    if (v.contains('raspberry')) return 'IoT Device';
    if (v.contains('espressif') || v.contains('tuya')) return 'Smart Home';
    if (v.contains('hp') && v.contains('printer')) return 'Printer';
    if (v.contains('dell') || v.contains('lenovo') || v.contains('asus')) return 'Computer';
    if (v.contains('sony')) return 'PlayStation';
    if (v.contains('microsoft')) return 'Xbox/Surface';
    if (v.contains('amazon')) return 'Echo/Fire TV';
    if (v.contains('google')) return 'Chromecast/Pixel';
    if (v.contains('tp-link') || v.contains('d-link') || v.contains('netgear')) return 'Router';
    return 'Unknown Device';
  }
  
  /// قاعدة بيانات مختصرة لأشهر OUIs
  static String _getVendorFromMac(String mac) {
    final oui = mac.replaceAll(RegExp(r'[:\-]'), '').toUpperCase().substring(0, 6);
    
    const ouiDb = {
      'F8F8F8': 'TP-Link',
      'F4F26D': 'TP-Link',
      '60324D': 'TP-Link',
      'EC086B': 'TP-Link',
      '0019E0': 'D-Link',
      '00179A': 'D-Link',
      '001CF0': 'D-Link',
      '0015C5': 'Belkin',
      '00173F': 'Belkin',
      '001A6B': 'Cisco',
      '001702': 'Cisco',
      '001E4A': 'Cisco',
      'C46115': 'Huawei',
      '080F3E': 'Huawei',
      '00462D': 'Huawei',
      '00E04C': 'ASUSTek',
      '00112F': 'ASUSTek',
      'F099B6': 'Apple',
      'ACDE48': 'Apple',
      '001B63': 'Apple',
      'DCA632': 'Apple',
      'BC52B7': 'Apple',
      '001DE0': 'Samsung',
      '00265E': 'Samsung',
      '0029C5': 'Samsung',
      'C0CB38': 'Samsung',
      '00235C': 'Xiaomi',
      '8CBEBE': 'Xiaomi',
      '94D569': 'Xiaomi',
      'C47154': 'Lenovo',
      '0026C7': 'Lenovo',
      '002128': 'Dell',
      '00234D': 'Dell',
      '00C0EE': 'HP',
      '001083': 'HP',
      '0021CC': 'HP',
      '000B82': 'Sony',
      'B827EB': 'Raspberry Pi',
      'DC5360': 'Raspberry Pi',
      '5CCF7F': 'Espressif (ESP8266)',
      'A4CF12': 'Espressif (ESP32)',
      'FCF5C4': 'Tuya',
      '10D561': 'Tuya',
      'D8F15E': 'Google',
      'FCF5C4': 'Google',
      '641C46': 'Google',
      '4201D6': 'Amazon',
      'FC65DE': 'Amazon',
      '0022B0': 'Amazon',
    };
    
    return ouiDb[oui] ?? 'Unknown';
  }
}

class NetworkDetails {
  final String ip;
  final String gateway;
  final String subnet;
  final String bssid;
  final String ssid;
  final String networkBase;
  
  NetworkDetails({
    required this.ip,
    required this.gateway,
    required this.subnet,
    required this.bssid,
    required this.ssid,
    required this.networkBase,
  });
}

class DiscoveredDevice {
  final String ip;
  final String mac;
  final String vendor;
  final String type;
  final String status;
  final DateTime firstSeen;
  final String? hostname;
  final int? responseTime;
  
  DiscoveredDevice({
    required this.ip,
    required this.mac,
    required this.vendor,
    required this.type,
    required this.status,
    required this.firstSeen,
    this.hostname,
    this.responseTime,
  });
  
  Map<String, dynamic> toJson() => {
    'ip': ip,
    'mac': mac,
    'vendor': vendor,
    'type': type,
    'status': status,
    'firstSeen': firstSeen.toIso8601String(),
    'hostname': hostname,
    'responseTime': responseTime,
  };
}
