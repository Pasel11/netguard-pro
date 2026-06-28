import 'dart:io';
import 'dart:async';

/// كاشف البوابات الأسيرة (Captive Portal Detector)
/// 
/// Captive Portal هو الجزء الذي يطلب منك تسجيل الدخول أو الدفع
/// في المقاهي والمطارات والفنادق قبل الوصول للإنترنت
/// 
/// الخطر: بعض البوابات الأسيرة تكون وهمية لسرقة البيانات
class CaptivePortalDetector {
  /// فحص وجود captive portal
  Future<CaptivePortalResult> detect() async {
    try {
      // 1. محاولة الوصول لصفحة معروفة بدون captive portal
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 10);
      
      // Google's captive portal detection page
      final request = await httpClient.getUrl(
        Uri.parse('http://connectivitycheck.gstatic.com/generate_204'),
      );
      final response = await request.close();
      
      // إذا حصلنا على 204، لا يوجد captive portal
      if (response.statusCode == 204) {
        httpClient.close();
        return CaptivePortalResult(
          hasCaptivePortal: false,
          portalUrl: null,
          isSecure: true,
          description: 'لا يوجد captive portal - الإنترنت يعمل مباشرة',
          timestamp: DateTime.now(),
        );
      }
      
      // إذا حصلنا على redirect (3xx)، قد يكون captive portal
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers.value('location');
        httpClient.close();
        
        return CaptivePortalResult(
          hasCaptivePortal: true,
          portalUrl: location,
          isSecure: _isSecurePortal(location),
          description: 'تم اكتشاف captive portal - قد تحتاج لتسجيل الدخول',
          timestamp: DateTime.now(),
        );
      }
      
      // أي استجابة أخرى، نفحص المحتوى
      final body = await response.transform(const SystemEncoding().decoder).join();
      httpClient.close();
      
      // إذا كان المحتوى يحتوي على نموذج تسجيل دخول
      final hasLoginForm = body.toLowerCase().contains('<form') ||
                           body.toLowerCase().contains('login') ||
                           body.toLowerCase().contains('password');
      
      if (hasLoginForm) {
        return CaptivePortalResult(
          hasCaptivePortal: true,
          portalUrl: 'http://connectivitycheck.gstatic.com/generate_204',
          isSecure: false,
          description: 'تم اكتشاف captive portal مع نموذج تسجيل دخول',
          timestamp: DateTime.now(),
        );
      }
      
      return CaptivePortalResult(
        hasCaptivePortal: false,
        portalUrl: null,
        isSecure: true,
        description: 'لا يوجد captive portal',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      // إذا فشل الاتصال، قد يكون captive portal يمنع الوصول
      return CaptivePortalResult(
        hasCaptivePortal: true,
        portalUrl: null,
        isSecure: false,
        description: 'تعذّر الوصول للإنترنت - قد يكون captive portal نشط',
        timestamp: DateTime.now(),
        error: e.toString(),
      );
    }
  }
  
  /// فحص إذا كان البوابة آمنة (HTTPS)
  bool _isSecurePortal(String? url) {
    if (url == null) return false;
    return url.startsWith('https://');
  }
  
  /// فحص شامل لكل أنواع captive portals
  Future<List<CaptivePortalResult>> performFullScan() async {
    final results = <CaptivePortalResult>[];
    
    // قائمة بخوادم الفحص
    final testUrls = [
      'http://connectivitycheck.gstatic.com/generate_204',
      'http://captive.apple.com/hotspot-detect.html',
      'http://clients3.google.com/generate_204',
      'http://www.msftconnecttest.com/connecttest.txt',
      'http://detectportal.firefox.com/success.txt',
    ];
    
    for (final url in testUrls) {
      try {
        final httpClient = HttpClient();
        httpClient.connectionTimeout = const Duration(seconds: 5);
        
        final request = await httpClient.getUrl(Uri.parse(url));
        final response = await request.close();
        final body = await response.transform(const SystemEncoding().decoder).join();
        httpClient.close();
        
        final hasPortal = response.statusCode != 204 &&
                         response.statusCode != 200;
        
        results.add(CaptivePortalResult(
          hasCaptivePortal: hasPortal,
          portalUrl: hasPortal ? url : null,
          isSecure: !hasPortal,
          description: hasPortal 
            ? 'Portal detected via $url'
            : 'No portal via $url',
          timestamp: DateTime.now(),
        ));
      } catch (e) {
        results.add(CaptivePortalResult(
          hasCaptivePortal: true,
          portalUrl: url,
          isSecure: false,
          description: 'Connection failed via $url',
          timestamp: DateTime.now(),
          error: e.toString(),
        ));
      }
    }
    
    return results;
  }
}

class CaptivePortalResult {
  final bool hasCaptivePortal;
  final String? portalUrl;
  final bool isSecure;
  final String description;
  final DateTime timestamp;
  final String? error;
  
  CaptivePortalResult({
    required this.hasCaptivePortal,
    required this.portalUrl,
    required this.isSecure,
    required this.description,
    required this.timestamp,
    this.error,
  });
}

/// مختبر الجدار الناري (Firewall Tester)
/// 
/// يفحص إذا كان جدار الحماية يعمل بشكل صحيح
class FirewallTester {
  /// فحص شامل للجدار الناري
  Future<FirewallTestResult> performTest() async {
    final inboundResults = <FirewallPortResult>[];
    final outboundResults = <FirewallPortResult>[];
    
    // 1. فحص البورتات الواردة (هل الجدار الناري يحجبها؟)
    final inboundPorts = [21, 22, 23, 25, 80, 110, 143, 443, 445, 3389];
    for (final port in inboundPorts) {
      final result = await _testInboundPort(port);
      inboundResults.add(result);
    }
    
    // 2. فحص البورتات الصادرة (هل الجدار الناري يسمح بها؟)
    final outboundPorts = [80, 443, 53, 25, 587, 993, 995];
    for (final port in outboundPorts) {
      final result = await _testOutboundPort(port);
      outboundResults.add(result);
    }
    
    // 3. تحليل النتائج
    final firewallScore = _calculateFirewallScore(inboundResults);
    final issues = _identifyIssues(inboundResults, outboundResults);
    final recommendations = _generateRecommendations(issues);
    
    return FirewallTestResult(
      inboundResults: inboundResults,
      outboundResults: outboundResults,
      firewallScore: firewallScore,
      issues: issues,
      recommendations: recommendations,
      timestamp: DateTime.now(),
    );
  }
  
  /// فحص بورت وارد
  Future<FirewallPortResult> _testInboundPort(int port) async {
    try {
      // محاولة الاستماع على البورت
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      server.close();
      
      // إذا نجحنا في فتح البورت، الجدار الناري لا يحجبه
      return FirewallPortResult(
        port: port,
        direction: 'inbound',
        isBlocked: false,
        description: 'البورت مفتوح - الجدار الناري لا يحجبه',
      );
    } catch (_) {
      // البورت محجوب (جيد للـ inbound)
      return FirewallPortResult(
        port: port,
        direction: 'inbound',
        isBlocked: true,
        description: 'البورت محجوب - الجدار الناري يعمل',
      );
    }
  }
  
  /// فحص بورت صادر
  Future<FirewallPortResult> _testOutboundPort(int port) async {
    try {
      // محاولة الاتصال بخادم خارجي على البورت
      final socket = await Socket.connect(
        '8.8.8.8', // Google DNS
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      
      // نجح الاتصال - البورت الصادر مفتوح
      return FirewallPortResult(
        port: port,
        direction: 'outbound',
        isBlocked: false,
        description: 'البورت الصادر مفتوح',
      );
    } catch (_) {
      // فشل الاتصال - قد يكون محجوب
      return FirewallPortResult(
        port: port,
        direction: 'outbound',
        isBlocked: true,
        description: 'البورت الصادر محجوب',
      );
    }
  }
  
  /// حساب درجة الجدار الناري
  int _calculateFirewallScore(List<FirewallPortResult> inbound) {
    int score = 100;
    
    for (final result in inbound) {
      if (!result.isBlocked && result.port != 80 && result.port != 443) {
        // بورت خطير غير محجوب
        score -= 10;
      }
    }
    
    return score.clamp(0, 100);
  }
  
  /// تحديد المشاكل
  List<String> _identifyIssues(
    List<FirewallPortResult> inbound,
    List<FirewallPortResult> outbound,
  ) {
    final issues = <String>[];
    
    for (final result in inbound) {
      if (!result.isBlocked) {
        switch (result.port) {
          case 23:
            issues.add('🔴 Telnet (23) مفتوح للإنترنت - خطر شديد');
            break;
          case 21:
            issues.add('🔴 FTP (21) مفتوح - غير مشفّر');
            break;
          case 22:
            issues.add('🟡 SSH (22) مفتوح - تأكد من كلمة مرور قوية');
            break;
          case 3389:
            issues.add('🟡 RDP (3389) مفتوح - قيّده بـ VPN');
            break;
          case 445:
            issues.add('🔴 SMB (445) مفتوح - عرضة لهجمات WannaCry');
            break;
        }
      }
    }
    
    for (final result in outbound) {
      if (result.isBlocked) {
        if (result.port == 80 || result.port == 443) {
          issues.add('🔴 تصفح الويب (${result.port}) محجوب!');
        } else if (result.port == 53) {
          issues.add('🔴 DNS محجوب - لن يعمل الإنترنت');
        }
      }
    }
    
    return issues;
  }
  
  /// توليد التوصيات
  List<String> _generateRecommendations(List<String> issues) {
    final recommendations = <String>[];
    
    if (issues.isEmpty) {
      recommendations.add('✅ إعداد الجدار الناري ممتاز');
    } else {
      recommendations.add('⚠️ يوجد ${issues.length} مشكلة في الجدار الناري');
    }
    
    recommendations.add('فعّل جدار الحماية على مستوى الراوتر');
    recommendations.add('استخدم جدار حماية على الجهاز (Windows Defender / iptables)');
    recommendations.add('أغلق كل البورتات غير الضرورية');
    recommendations.add('استخدم VPN عند الاتصال بشبكات عامة');
    
    return recommendations;
  }
}

class FirewallPortResult {
  final int port;
  final String direction;
  final bool isBlocked;
  final String description;
  
  FirewallPortResult({
    required this.port,
    required this.direction,
    required this.isBlocked,
    required this.description,
  });
}

class FirewallTestResult {
  final List<FirewallPortResult> inboundResults;
  final List<FirewallPortResult> outboundResults;
  final int firewallScore;
  final List<String> issues;
  final List<String> recommendations;
  final DateTime timestamp;
  
  FirewallTestResult({
    required this.inboundResults,
    required this.outboundResults,
    required this.firewallScore,
    required this.issues,
    required this.recommendations,
    required this.timestamp,
  });
}
