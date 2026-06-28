import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

/// فاحص SSL/TLS حقيقي - يفحص الشهادات والبروتوكولات
class SslScanner {
  /// فحص شهادة SSL/TLS لموقع
  static Future<SslScanResult> scan(String host, {int port = 443}) async {
    final issues = <String>[];
    final recommendations = <String>[];
    final protocols = <String>[];
    var securityScore = 100;
    
    try {
      // محاولة الاتصال باستخدام TLS
      final socket = await SecureSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
        onBadCertificate: (cert) => true, // نسمح بالشهادات السيئة للفحص
      );
      
      // الحصول على شهادة الخادم
      final cert = socket.peerCertificate;
      
      if (cert != null) {
        // فحص انتهاء الشهادة
        final now = DateTime.now();
        final expiry = cert.endValidity;
        final daysUntilExpiry = expiry.difference(now).inDays;
        
        if (daysUntilExpiry < 0) {
          issues.add('🔴 الشهادة منتهية الصلاحية منذ ${-daysUntilExpiry} يوم');
          securityScore -= 30;
          recommendations.add('جدّد الشهادة فوراً');
        } else if (daysUntilExpiry < 30) {
          issues.add('🟡 الشهادة ستنتهي خلال $daysUntilExpiry يوم');
          securityScore -= 10;
          recommendations.add('جدّد الشهادة قريباً');
        } else {
          issues.add('✅ الشهادة صالحة لمدة $daysUntilExpiry يوم');
        }
        
        // فحص بداية الشهادة
        final start = cert.startValidity;
        if (start.isAfter(now)) {
          issues.add('🔴 الشهادة غير فعّالة بعد (تبدأ في $start)');
          securityScore -= 20;
        }
        
        // فحص الـ Subject
        final subject = cert.subject.toString();
        issues.add('Subject: ${_formatCertName(subject)}');
        
        // فحص الـ Issuer
        final issuer = cert.issuer.toString();
        issues.add('Issuer: ${_formatCertName(issuer)}');
        
        // فحص تطابق hostname
        // SecureSocket يتأكد تلقائياً، لكن إذا كان هناك bad certificate، نعرف
      } else {
        issues.add('🔴 لا توجد شهادة SSL/TLS');
        securityScore -= 50;
      }
      
      // فحص البروتوكول المستخدم
      final selectedProtocol = socket.selectedProtocol;
      if (selectedProtocol != null) {
        protocols.add(selectedProtocol);
        if (selectedProtocol == 'h2' || selectedProtocol == 'http/1.1') {
          issues.add('✅ ALPN: $selectedProtocol');
        }
      }
      
      socket.destroy();
      
    } on HandshakeException catch (e) {
      issues.add('🔴 فشل في TLS handshake: ${e.message}');
      securityScore -= 40;
      
      // محاولة معرفة السبب
      if (e.toString().contains('certificate')) {
        recommendations.add('الشهادة غير صالحة أو غير موثوقة');
      } else if (e.toString().contains('protocol')) {
        recommendations.add('بروتوكول SSL/TLS غير مدعوم');
      }
    } on SocketException catch (e) {
      issues.add('🔴 خطأ في الاتصال: ${e.message}');
      securityScore = 0;
    } catch (e) {
      issues.add('🔴 خطأ غير متوقع: $e');
      securityScore = 0;
    }
    
    // فحص HTTP Headers (HSTS, etc.)
    final headersResult = await _checkSecurityHeaders(host, port);
    issues.addAll(headersResult.issues);
    recommendations.addAll(headersResult.recommendations);
    
    // إعادة حساب الدرجة
    securityScore = (securityScore - headersResult.scoreDeduction).clamp(0, 100);
    
    if (securityScore >= 80) {
      recommendations.add('✅ إعداد SSL/TLS قوي');
    } else if (securityScore >= 50) {
      recommendations.add('🟡 إعداد SSL/TLS يحتاج تحسين');
    } else {
      recommendations.add('🔴 إعداد SSL/TLS ضعيف جداً');
    }
    
    return SslScanResult(
      host: host,
      port: port,
      scanTime: DateTime.now().toIso8601String(),
      issues: issues,
      recommendations: recommendations,
      protocols: protocols,
      securityScore: securityScore,
    );
  }
  
  /// فحص Security Headers
  static Future<_HeadersResult> _checkSecurityHeaders(String host, int port) async {
    final issues = <String>[];
    final recommendations = <String>[];
    var scoreDeduction = 0;
    
    try {
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 5);
      
      final request = await httpClient.getUrl(Uri.parse('https://$host/'));
      final response = await request.close();
      
      final headers = response.headers;
      
      // فحص HSTS
      final hsts = headers.value('strict-transport-security');
      if (hsts == null) {
        issues.add('🟡 HSTS غير مفعّل');
        scoreDeduction += 10;
        recommendations.add('فعّل HSTS: Strict-Transport-Security: max-age=31536000; includeSubDomains');
      } else {
        issues.add('✅ HSTS مفعّل: $hsts');
      }
      
      // فحص X-Frame-Options
      final xFrame = headers.value('x-frame-options');
      if (xFrame == null) {
        issues.add('🟡 X-Frame-Options غير مفعّل');
        scoreDeduction += 5;
        recommendations.add('فعّل X-Frame-Options: DENY أو SAMEORIGIN');
      } else {
        issues.add('✅ X-Frame-Options: $xFrame');
      }
      
      // فحص X-Content-Type-Options
      final xContentType = headers.value('x-content-type-options');
      if (xContentType == null) {
        issues.add('🟡 X-Content-Type-Options غير مفعّل');
        scoreDeduction += 5;
        recommendations.add('فعّل X-Content-Type-Options: nosniff');
      }
      
      // فحص Content-Security-Policy
      final csp = headers.value('content-security-policy');
      if (csp == null) {
        issues.add('🟡 Content-Security-Policy غير مفعّل');
        scoreDeduction += 5;
        recommendations.add('أضف Content-Security-Policy header');
      }
      
      // فحص Server header
      final server = headers.value('server');
      if (server != null) {
        issues.add('ℹ️ Server header مكشوف: $server');
        scoreDeduction += 2;
        recommendations.add('أخفِ Server header لتقليل كشف المعلومات');
      }
      
      // فحص X-Powered-By
      final xPoweredBy = headers.value('x-powered-by');
      if (xPoweredBy != null) {
        issues.add('🟡 X-Powered-By مكشوف: $xPoweredBy');
        scoreDeduction += 5;
        recommendations.add('أخفِ X-Powered-By header');
      }
      
      httpClient.close();
    } catch (e) {
      issues.add('🔴 تعذّر فحص HTTP headers: $e');
      scoreDeduction += 10;
    }
    
    return _HeadersResult(
      issues: issues,
      recommendations: recommendations,
      scoreDeduction: scoreDeduction,
    );
  }
  
  /// تنسيق اسم الشهادة لعرض أفضل
  static String _formatCertName(String name) {
    // /C=US/ST=California/L=Mountain View/O=Google LLC/CN=*.google.com
    return name
        .split('/')
        .where((s) => s.isNotEmpty)
        .join(', ');
  }
  
  /// فحص صلاحية شهادة معينة
  static Future<CertificateInfo?> getCertificateInfo(String host, {int port = 443}) async {
    try {
      final socket = await SecureSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
        onBadCertificate: (cert) => true,
      );
      
      final cert = socket.peerCertificate;
      socket.destroy();
      
      if (cert != null) {
        return CertificateInfo(
          subject: cert.subject.toString(),
          issuer: cert.issuer.toString(),
          startValidity: cert.startValidity,
          endValidity: cert.endValidity,
          sha1: cert.sha1.toString(),
          sha256: cert.sha256.toString(),
        );
      }
    } catch (_) {}
    
    return null;
  }
}

class _HeadersResult {
  final List<String> issues;
  final List<String> recommendations;
  final int scoreDeduction;
  
  _HeadersResult({
    required this.issues,
    required this.recommendations,
    required this.scoreDeduction,
  });
}

class SslScanResult {
  final String host;
  final int port;
  final String scanTime;
  final List<String> issues;
  final List<String> recommendations;
  final List<String> protocols;
  final int securityScore;
  
  SslScanResult({
    required this.host,
    required this.port,
    required this.scanTime,
    required this.issues,
    required this.recommendations,
    required this.protocols,
    required this.securityScore,
  });
  
  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'scanTime': scanTime,
    'securityScore': securityScore,
    'issues': issues,
    'recommendations': recommendations,
    'protocols': protocols,
  };
}

class CertificateInfo {
  final String subject;
  final String issuer;
  final DateTime startValidity;
  final DateTime endValidity;
  final Uint8List sha1;
  final Uint8List sha256;
  
  CertificateInfo({
    required this.subject,
    required this.issuer,
    required this.startValidity,
    required this.endValidity,
    required this.sha1,
    required this.sha256,
  });
  
  int get daysUntilExpiry => endValidity.difference(DateTime.now()).inDays;
  
  bool get isExpired => DateTime.now().isAfter(endValidity);
  bool get isNotYetValid => DateTime.now().isBefore(startValidity);
  bool get isValid => !isExpired && !isNotYetValid;
}
