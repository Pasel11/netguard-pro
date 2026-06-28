import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// خدمة معلومات WiFi حقيقية - تشتغل محلياً
class WifiInfoService {
  static final NetworkInfo _networkInfo = NetworkInfo();
  static final Connectivity _connectivity = Connectivity();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  /// الحصول على معلومات WiFi الكاملة
  static Future<WifiInfo> getWifiInfo() async {
    String? ip, gateway, subnet, bssid, ssid;
    String connectionType = 'Unknown';
    
    // فحص نوع الاتصال
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.wifi) {
      connectionType = 'WiFi';
    } else if (connectivityResult == ConnectivityResult.mobile) {
      connectionType = 'Mobile Data';
    } else if (connectivityResult == ConnectivityResult.ethernet) {
      connectionType = 'Ethernet';
    } else if (connectivityResult == ConnectivityResult.vpn) {
      connectionType = 'VPN';
    } else if (connectivityResult == ConnectivityResult.none) {
      connectionType = 'Offline';
    }
    
    // محاولة الحصول على معلومات WiFi
    try {
      ip = await _networkInfo.getWifiIP();
      gateway = await _networkInfo.getWifiGatewayIP();
      subnet = await _networkInfo.getWifiSubmask();
      bssid = await _networkInfo.getWifiBSSID();
      ssid = await _networkInfo.getWifiName();
    } catch (_) {}
    
    // معلومات الجهاز
    String? deviceModel, osVersion, manufacturer;
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        deviceModel = info.model;
        osVersion = 'Android ${info.version.release}';
        manufacturer = info.manufacturer;
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        deviceModel = info.utsname.machine;
        osVersion = info.systemVersion;
        manufacturer = 'Apple';
      }
    } catch (_) {}
    
    return WifiInfo(
      ip: ip ?? 'Unknown',
      gateway: gateway ?? 'Unknown',
      subnet: subnet ?? 'Unknown',
      bssid: bssid ?? 'Unknown',
      ssid: ssid?.replaceAll('"', '') ?? 'Unknown',
      connectionType: connectionType,
      deviceModel: deviceModel ?? 'Unknown',
      osVersion: osVersion ?? 'Unknown',
      manufacturer: manufacturer ?? 'Unknown',
      timestamp: DateTime.now().toIso8601String(),
    );
  }
  
  /// مراقبة حالة الشبكة بشكل مستمر
  static Stream<ConnectivityResult> watchConnectivity() {
    return _connectivity.onConnectivityChanged;
  }
  
  /// الحصول على IP العام (عبر خدمة outside)
  static Future<String?> getPublicIp() async {
    try {
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 5);
      
      final request = await httpClient.getUrl(Uri.parse('https://api.ipify.org'));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final body = await response.transform(const SystemEncoding().decoder).join();
        httpClient.close();
        return body.trim();
      }
      httpClient.close();
    } catch (_) {}
    
    // محاولة بديلة
    try {
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 5);
      
      final request = await httpClient.getUrl(Uri.parse('https://ifconfig.me/ip'));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final body = await response.transform(const SystemEncoding().decoder).join();
        httpClient.close();
        return body.trim();
      }
      httpClient.close();
    } catch (_) {}
    
    return null;
  }
  
  /// الحصول على معلومات IP العام (مع الموقع الجغرافي)
  static Future<PublicIpInfo?> getPublicIpInfo() async {
    try {
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 5);
      
      final request = await httpClient.getUrl(Uri.parse('https://ipapi.co/json/'));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final body = await response.transform(const SystemEncoding().decoder).join();
        httpClient.close();
        
        // Parse JSON يدوياً (لأن dart:convert قد يكون محدود)
        return _parseIpInfo(body);
      }
      httpClient.close();
    } catch (_) {}
    
    return null;
  }
  
  static PublicIpInfo? _parseIpInfo(String body) {
    try {
      // JSON parsing بسيط - في الإنتاج استخدم dart:convert
      final ipMatch = RegExp(r'"ip"\s*:\s*"([^"]+)"').firstMatch(body);
      final cityMatch = RegExp(r'"city"\s*:\s*"([^"]+)"').firstMatch(body);
      final countryMatch = RegExp(r'"country_name"\s*:\s*"([^"]+)"').firstMatch(body);
      final countryCodeMatch = RegExp(r'"country_code"\s*:\s*"([^"]+)"').firstMatch(body);
      final ispMatch = RegExp(r'"org"\s*:\s*"([^"]+)"').firstMatch(body);
      final asnMatch = RegExp(r'"asn"\s*:\s*"([^"]+)"').firstMatch(body);
      final timezoneMatch = RegExp(r'"timezone"\s*:\s*"([^"]+)"').firstMatch(body);
      final latMatch = RegExp(r'"latitude"\s*:\s*([\d.-]+)').firstMatch(body);
      final lonMatch = RegExp(r'"longitude"\s*:\s*([\d.-]+)').firstMatch(body);
      
      return PublicIpInfo(
        ip: ipMatch?.group(1) ?? '',
        city: cityMatch?.group(1),
        country: countryMatch?.group(1),
        countryCode: countryCodeMatch?.group(1),
        isp: ispMatch?.group(1),
        asn: asnMatch?.group(1),
        timezone: timezoneMatch?.group(1),
        latitude: latMatch != null ? double.tryParse(latMatch.group(1)!) : null,
        longitude: lonMatch != null ? double.tryParse(lonMatch.group(1)!) : null,
      );
    } catch (_) {
      return null;
    }
  }
  
  /// فحص سرعة الإنترنت (Download/Upload)
  static Future<SpeedTestResult> testInternetSpeed({Function(double progress)? onProgress}) async {
    final start = DateTime.now();
    
    // Download test
    final downloadResult = await _testDownloadSpeed(onProgress: onProgress);
    
    // Upload test
    final uploadResult = await _testUploadSpeed();
    
    final duration = DateTime.now().difference(start);
    
    return SpeedTestResult(
      downloadSpeed: downloadResult.speedMbps,
      uploadSpeed: uploadResult.speedMbps,
      downloadSize: downloadResult.sizeBytes,
      uploadSize: uploadResult.sizeBytes,
      duration: duration,
      timestamp: start.toIso8601String(),
    );
  }
  
  static Future<_SpeedResult> _testDownloadSpeed({Function(double progress)? onProgress}) async {
    try {
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 30);
      
      final start = DateTime.now();
      final request = await httpClient.getUrl(
        Uri.parse('https://speed.cloudflare.com/__down?bytes=10000000'), // 10 MB
      );
      final response = await request.close();
      
      var receivedBytes = 0;
      await for (final chunk in response) {
        receivedBytes += chunk.length;
        if (onProgress != null) {
          onProgress(receivedBytes / 10000000);
        }
      }
      
      final duration = DateTime.now().difference(start);
      httpClient.close();
      
      final speedBps = (receivedBytes * 8) / (duration.inMilliseconds / 1000);
      final speedMbps = speedBps / 1000000;
      
      return _SpeedResult(
        speedMbps: speedMbps,
        sizeBytes: receivedBytes,
      );
    } catch (_) {
      return _SpeedResult(speedMbps: 0, sizeBytes: 0);
    }
  }
  
  static Future<_SpeedResult> _testUploadSpeed() async {
    try {
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 30);
      
      // إنشاء بيانات عشوائية للرفع (1 MB)
      final data = List<int>.filled(1000000, 65); // 1MB من 'A'
      
      final start = DateTime.now();
      final request = await httpClient.postUrl(
        Uri.parse('https://speed.cloudflare.com/__up'),
      );
      request.contentLength = data.length;
      request.add(data);
      final response = await request.close();
      await response.drain();
      
      final duration = DateTime.now().difference(start);
      httpClient.close();
      
      final speedBps = (data.length * 8) / (duration.inMilliseconds / 1000);
      final speedMbps = speedBps / 1000000;
      
      return _SpeedResult(
        speedMbps: speedMbps,
        sizeBytes: data.length,
      );
    } catch (_) {
      return _SpeedResult(speedMbps: 0, sizeBytes: 0);
    }
  }
}

class WifiInfo {
  final String ip;
  final String gateway;
  final String subnet;
  final String bssid;
  final String ssid;
  final String connectionType;
  final String deviceModel;
  final String osVersion;
  final String manufacturer;
  final String timestamp;
  
  WifiInfo({
    required this.ip,
    required this.gateway,
    required this.subnet,
    required this.bssid,
    required this.ssid,
    required this.connectionType,
    required this.deviceModel,
    required this.osVersion,
    required this.manufacturer,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
    'ip': ip,
    'gateway': gateway,
    'subnet': subnet,
    'bssid': bssid,
    'ssid': ssid,
    'connectionType': connectionType,
    'deviceModel': deviceModel,
    'osVersion': osVersion,
    'manufacturer': manufacturer,
    'timestamp': timestamp,
  };
}

class PublicIpInfo {
  final String ip;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? isp;
  final String? asn;
  final String? timezone;
  final double? latitude;
  final double? longitude;
  
  PublicIpInfo({
    required this.ip,
    this.city,
    this.country,
    this.countryCode,
    this.isp,
    this.asn,
    this.timezone,
    this.latitude,
    this.longitude,
  });
}

class _SpeedResult {
  final double speedMbps;
  final int sizeBytes;
  
  _SpeedResult({required this.speedMbps, required this.sizeBytes});
}

class SpeedTestResult {
  final double downloadSpeed;
  final double uploadSpeed;
  final int downloadSize;
  final int uploadSize;
  final Duration duration;
  final String timestamp;
  
  SpeedTestResult({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.downloadSize,
    required this.uploadSize,
    required this.duration,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
    'downloadSpeed': downloadSpeed.toStringAsFixed(2),
    'uploadSpeed': uploadSpeed.toStringAsFixed(2),
    'downloadSize': downloadSize,
    'uploadSize': uploadSize,
    'durationMs': duration.inMilliseconds,
    'timestamp': timestamp,
  };
}
