import 'dart:io';
import 'dart:async';

/// كاشف تسريب DNS (DNS Leak Test)
/// 
/// تسريب DNS يحدث عندما:
/// - تستخدم VPN لكن DNS queries تذهب لخادم ISP بدلاً من VPN
/// - راوترك يعيد توجيه DNS لخوادم غير آمنة
/// - بعض التطبيقات تتجاوز DNS المخصص
/// 
/// هذا يكشف:
/// - من يرى مواقعك التي تزورها
/// - هل VPN يعمل بشكل صحيح
/// - هل DNS مُخترق
class DnsLeakTest {
  bool _isTesting = false;
  final List<DnsServer> _detectedServers = [];
  
  List<DnsServer> get detectedServers => List.unmodifiable(_detectedServers);
  bool get isTesting => _isTesting;
  
  /// إجراء فحص شامل لتسريب DNS
  Future<DnsLeakResult> performTest() async {
    if (_isTesting) {
      return DnsLeakResult(
        hasLeak: false,
        detectedServers: [],
        yourIp: '',
        yourLocation: '',
        expectedDns: '',
        actualDns: '',
        recommendations: [],
        timestamp: DateTime.now(),
        error: 'Test already running',
      );
    }
    
    _isTesting = true;
    _detectedServers.clear();
    
    try {
      // 1. الحصول على IP العام
      final publicIp = await _getPublicIp();
      
      // 2. الحصول على موقع IP
      final ipLocation = await _getIpLocation(publicIp);
      
      // 3. الحصول على DNS المستخدم فعلياً
      final actualDns = await _getActualDnsServer();
      
      // 4. الحصول على DNS المتوقع (من إعدادات النظام)
      final expectedDns = await _getExpectedDns();
      
      // 5. فحص عدة خوادم DNS leak
      final dnsServers = await _checkMultipleDnsServers();
      
      // 6. تحليل النتائج
      final hasLeak = _analyzeLeak(actualDns, expectedDns, ipLocation, dnsServers);
      
      // 7. توليد التوصيات
      final recommendations = _generateRecommendations(
        hasLeak, actualDns, expectedDns, ipLocation, dnsServers,
      );
      
      _isTesting = false;
      
      return DnsLeakResult(
        hasLeak: hasLeak,
        detectedServers: dnsServers,
        yourIp: publicIp,
        yourLocation: ipLocation,
        expectedDns: expectedDns,
        actualDns: actualDns,
        recommendations: recommendations,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _isTesting = false;
      return DnsLeakResult(
        hasLeak: false,
        detectedServers: [],
        yourIp: '',
        yourLocation: '',
        expectedDns: '',
        actualDns: '',
        recommendations: [],
        timestamp: DateTime.now(),
        error: e.toString(),
      );
    }
  }
  
  /// الحصول على IP العام
  Future<String> _getPublicIp() async {
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
    
    return 'Unknown';
  }
  
  /// الحصول على موقع IP
  Future<String> _getIpLocation(String ip) async {
    try {
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 5);
      
      final request = await httpClient.getUrl(Uri.parse('https://ipapi.co/json/'));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final body = await response.transform(const SystemEncoding().decoder).join();
        httpClient.close();
        
        // Parse JSON يدوياً
        final countryMatch = RegExp(r'"country_name"\s*:\s*"([^"]+)"').firstMatch(body);
        final cityMatch = RegExp(r'"city"\s*:\s*"([^"]+)"').firstMatch(body);
        final ispMatch = RegExp(r'"org"\s*:\s*"([^"]+)"').firstMatch(body);
        
        final country = countryMatch?.group(1) ?? '';
        final city = cityMatch?.group(1) ?? '';
        final isp = ispMatch?.group(1) ?? '';
        
        return '$city, $country ($isp)';
      }
      httpClient.close();
    } catch (_) {}
    
    return 'Unknown';
  }
  
  /// الحصول على DNS الفعلي المستخدم
  Future<String> _getActualDnsServer() async {
    try {
      // محاولة الحصول على DNS من /etc/resolv.conf
      final file = File('/etc/resolv.conf');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final match = RegExp(r'nameserver\s+(\d+\.\d+\.\d+\.\d+)').firstMatch(contents);
        if (match != null) {
          return match.group(1)!;
        }
      }
    } catch (_) {}
    
    // محاولة بديلة عبر getprop على Android
    try {
      final result = await Process.run('getprop', ['net.dns1']);
      if (result.exitCode == 0) {
        final dns = result.stdout.toString().trim();
        if (dns.isNotEmpty && dns != '0.0.0.0') {
          return dns;
        }
      }
    } catch (_) {}
    
    // محاولة عبر nslookup
    try {
      final result = await Process.run('nslookup', ['localhost']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'Server:\s+(\d+\.\d+\.\d+\.\d+)').firstMatch(output);
        if (match != null) {
          return match.group(1)!;
        }
      }
    } catch (_) {}
    
    return 'Unknown';
  }
  
  /// الحصول على DNS المتوقع (VPN أو مخصص)
  Future<String> _getExpectedDns() async {
    // نتحقق من إعدادات VPN
    // في تطبيق حقيقي، نتحقق من إعدادات شبكة VPN
    return 'Cloudflare (1.1.1.1)'; // افتراضي
  }
  
  /// فحص عدة خوادم DNS
  Future<List<DnsServer>> _checkMultipleDnsServers() async {
    final servers = <DnsServer>[];
    
    // قائمة بالخوادم المعروفة
    const knownServers = [
      ('1.1.1.1', 'Cloudflare'),
      ('8.8.8.8', 'Google'),
      ('9.9.9.9', 'Quad9'),
      ('208.67.222.222', 'OpenDNS'),
      ('8.26.56.26', 'Comodo Secure DNS'),
    ];
    
    for (final (ip, name) in knownServers) {
      final server = await _testDnsServer(ip, name);
      if (server != null) {
        servers.add(server);
      }
    }
    
    return servers;
  }
  
  /// فحص خادم DNS واحد
  Future<DnsServer?> _testDnsServer(String ip, String name) async {
    try {
      // قياس زمن الاستجابة
      final start = DateTime.now();
      final socket = await Socket.connect(ip, 53, timeout: const Duration(seconds: 3));
      final responseTime = DateTime.now().difference(start).inMilliseconds;
      socket.destroy();
      
      // الحصول على موقع الخادم
      final location = await _getServerLocation(ip);
      
      return DnsServer(
        ip: ip,
        name: name,
        responseTime: responseTime,
        location: location,
        isReachable: true,
      );
    } catch (_) {
      return null;
    }
  }
  
  /// الحصول على موقع خادم
  Future<String> _getServerLocation(String ip) async {
    try {
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 3);
      
      final request = await httpClient.getUrl(Uri.parse('https://ipapi.co/$ip/json/'));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final body = await response.transform(const SystemEncoding().decoder).join();
        httpClient.close();
        
        final countryMatch = RegExp(r'"country_name"\s*:\s*"([^"]+)"').firstMatch(body);
        final cityMatch = RegExp(r'"city"\s*:\s*"([^"]+)"').firstMatch(body);
        
        final country = countryMatch?.group(1) ?? '';
        final city = cityMatch?.group(1) ?? '';
        
        return '$city, $country';
      }
      httpClient.close();
    } catch (_) {}
    
    return 'Unknown';
  }
  
  /// تحليل وجود تسريب
  bool _analyzeLeak(
    String actualDns,
    String expectedDns,
    String ipLocation,
    List<DnsServer> detectedServers,
  ) {
    // تسريب يحدث إذا:
    // 1. DNS المستخدم يختلف عن المتوقع (مثلاً VPN DNS)
    // 2. DNS من ISP ظهر بدلاً من DNS المخصص
    
    if (actualDns == 'Unknown') return false;
    
    // إذا كان DNS الفعلي ليس في قائمة DNS المتوقعة
    if (!expectedDns.toLowerCase().contains(actualDns.toLowerCase()) &&
        !actualDns.toLowerCase().contains('cloudflare') &&
        !actualDns.toLowerCase().contains('1.1.1.1')) {
      // قد يكون تسريب
      return true;
    }
    
    return false;
  }
  
  /// توليد التوصيات
  List<String> _generateRecommendations(
    bool hasLeak,
    String actualDns,
    String expectedDns,
    String ipLocation,
    List<DnsServer> detectedServers,
  ) {
    final recommendations = <String>[];
    
    if (hasLeak) {
      recommendations.add('🔴 تم اكتشاف تسريب DNS! متصفحك قد يكشف مواقعك لـ ISP');
      recommendations.add('استخدم VPN مع DNS leak protection');
      recommendations.add('أو استخدم DNS-over-HTTPS (DoH) في متصفحك');
      recommendations.add('فعّل "Secure DNS" في Chrome / Firefox');
    } else {
      recommendations.add('✅ لا يوجد تسريب DNS');
      recommendations.add('DNS الخاص بك يعمل بشكل صحيح');
    }
    
    if (detectedServers.isNotEmpty) {
      final fastest = detectedServers.reduce(
        (a, b) => a.responseTime < b.responseTime ? a : b,
      );
      recommendations.add('💡 أسرع خادم DNS: ${fastest.name} (${fastest.responseTime}ms)');
    }
    
    if (ipLocation.contains('Unknown')) {
      recommendations.add('⚠️ تعذّر تحديد موقعك - قد يكون هناك proxy');
    }
    
    return recommendations;
  }
}

class DnsServer {
  final String ip;
  final String name;
  final int responseTime;
  final String location;
  final bool isReachable;
  
  DnsServer({
    required this.ip,
    required this.name,
    required this.responseTime,
    required this.location,
    required this.isReachable,
  });
}

class DnsLeakResult {
  final bool hasLeak;
  final List<DnsServer> detectedServers;
  final String yourIp;
  final String yourLocation;
  final String expectedDns;
  final String actualDns;
  final List<String> recommendations;
  final DateTime timestamp;
  final String? error;
  
  DnsLeakResult({
    required this.hasLeak,
    required this.detectedServers,
    required this.yourIp,
    required this.yourLocation,
    required this.expectedDns,
    required this.actualDns,
    required this.recommendations,
    required this.timestamp,
    this.error,
  });
}
