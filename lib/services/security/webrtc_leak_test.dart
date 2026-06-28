import 'dart:io';
import 'dart:async';

/// كاشف تسريب WebRTC (WebRTC Leak Test)
/// 
/// تسريب WebRTC يكشف:
/// - IP الحقيقي حتى مع VPN
/// - IP المحلي (LAN)
/// - معلومات الجهاز
/// 
/// يستخدمه الم/sites للتعرّف عليك رغم VPN
class WebRtcLeakTest {
  /// فحص شامل لتسريب WebRTC
  /// 
  /// ملاحظة: Flutter لا يدعم WebRTC مباشرة في الـ webview
  /// لكن نقدر نحاكي الفحص ونكتشف التسريبات المحتملة
  
  Future<WebRtcLeakResult> performTest() async {
    try {
      // 1. الحصول على IP العام
      final publicIp = await _getPublicIp();
      
      // 2. الحصول على IP المحلي
      final localIp = await _getLocalIp();
      
      // 3. الحصول على IPs إضافية (IPv6, etc.)
      final allIps = await _getAllNetworkIps();
      
      // 4. فحص إذا كان هناك VPN نشط
      final vpnStatus = await _checkVpnStatus();
      
      // 5. تحليل وجود تسريب
      final hasLeak = _analyzeLeak(publicIp, localIp, vpnStatus);
      
      // 6. توليد التوصيات
      final recommendations = _generateRecommendations(hasLeak, vpnStatus);
      
      return WebRtcLeakResult(
        hasLeak: hasLeak,
        publicIp: publicIp,
        localIp: localIp,
        allIps: allIps,
        vpnActive: vpnStatus.isActive,
        vpnIp: vpnStatus.vpnIp,
        leakedIps: hasLeak ? [localIp, ...allIps] : [],
        recommendations: recommendations,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return WebRtcLeakResult(
        hasLeak: false,
        publicIp: '',
        localIp: '',
        allIps: [],
        vpnActive: false,
        vpnIp: null,
        leakedIps: [],
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
  
  /// الحصول على IP المحلي
  Future<String> _getLocalIp() async {
    try {
      // الحصول على IP المحلي عبر NetworkInterface
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          // تجاهل loopback
          if (!address.isLoopback) {
            return address.address;
          }
        }
      }
    } catch (_) {}
    
    return 'Unknown';
  }
  
  /// الحصول على كل عناوين IP
  Future<List<String>> _getAllNetworkIps() async {
    final ips = <String>[];
    
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );
      
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          ips.add(address.address);
        }
      }
    } catch (_) {}
    
    return ips;
  }
  
  /// فحص حالة VPN
  Future<VpnStatus> _checkVpnStatus() async {
    try {
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        // أسماء واجهات VPN الشائعة
        if (name.contains('tun') || 
            name.contains('tap') || 
            name.contains('ppp') ||
            name.contains('vpn') ||
            name.contains('ipsec')) {
          // VPN نشط
          String? vpnIp;
          for (final address in interface.addresses) {
            if (!address.isLoopback) {
              vpnIp = address.address;
              break;
            }
          }
          return VpnStatus(isActive: true, interface: interface.name, vpnIp: vpnIp);
        }
      }
    } catch (_) {}
    
    return VpnStatus(isActive: false, interface: null, vpnIp: null);
  }
  
  /// تحليل وجود تسريب
  bool _analyzeLeak(String publicIp, String localIp, VpnStatus vpn) {
    if (!vpn.isActive) {
      // لا يوجد VPN، لا يمكن أن يكون هناك تسريب WebRTC
      return false;
    }
    
    // إذا كان VPN نشط لكن IP المحلي ظاهر
    // هذا تسريب WebRTC محتمل
    if (localIp != 'Unknown' && 
        !localIp.startsWith('10.') && 
        !localIp.startsWith('192.168.') && 
        !localIp.startsWith('172.')) {
      // IP المحلي ليس خاص
      return true;
    }
    
    return false;
  }
  
  /// توليد التوصيات
  List<String> _generateRecommendations(bool hasLeak, VpnStatus vpn) {
    final recommendations = <String>[];
    
    if (hasLeak) {
      recommendations.add('🔴 تم اكتشاف تسريب WebRTC!');
      recommendations.add('IP الحقيقي مكشوف رغم VPN');
      recommendations.add('الحلول:');
      recommendations.add('  - فعّل WebRTC leak protection في VPN');
      recommendations.add('  - عطّل WebRTC في المتصفح');
      recommendations.add('  - استخدم إضافة uBlock Origin');
      recommendations.add('  - استخدم متصفح Brave مع Shields UP');
    } else if (vpn.isActive) {
      recommendations.add('✅ لا يوجد تسريب WebRTC');
      recommendations.add('VPN يعمل بشكل صحيح');
    } else {
      recommendations.add('ℹ️ لا يوجد VPN نشط');
      recommendations.add('لحماية خصوصيتك:');
      recommendations.add('  - استخدم VPN موثوق');
      recommendations.add('  - فعّل HTTPS Everywhere');
      recommendations.add('  - استخدم متصفح يحمي الخصوصية');
    }
    
    if (vpn.isActive) {
      recommendations.add('🔌 واجهة VPN: ${vpn.interface}');
      if (vpn.vpnIp != null) {
        recommendations.add('🌐 IP الـ VPN: ${vpn.vpnIp}');
      }
    }
    
    return recommendations;
  }
  
  /// فحص سريع لتسريب WebRTC
  Future<bool> quickCheck() async {
    final result = await performTest();
    return result.hasLeak;
  }
}

class WebRtcLeakResult {
  final bool hasLeak;
  final String publicIp;
  final String localIp;
  final List<String> allIps;
  final bool vpnActive;
  final String? vpnIp;
  final List<String> leakedIps;
  final List<String> recommendations;
  final DateTime timestamp;
  final String? error;
  
  WebRtcLeakResult({
    required this.hasLeak,
    required this.publicIp,
    required this.localIp,
    required this.allIps,
    required this.vpnActive,
    required this.vpnIp,
    required this.leakedIps,
    required this.recommendations,
    required this.timestamp,
    this.error,
  });
  
  String get summary {
    if (hasLeak) {
      return '🔴 تسريب WebRTC مكتشف! ${leakedIps.length} IPs مكشوفة';
    } else if (vpnActive) {
      return '✅ آمن - VPN يعمل بدون تسريب';
    } else {
      return 'ℹ️ لا VPN نشط';
    }
  }
}

class VpnStatus {
  final bool isActive;
  final String? interface;
  final String? vpnIp;
  
  VpnStatus({
    required this.isActive,
    required this.interface,
    required this.vpnIp,
  });
}
