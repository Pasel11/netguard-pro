import 'dart:async';
import 'dart:io';
import 'dart:isolate';

/// فاحص بورتات حقيقي يعمل محلياً على الموبايل
/// يستخدم Dart Sockets مباشرة بدون الحاجة لـ backend
class LocalPortScanner {
  static const List<int> commonPorts = [
    20, 21, 22, 23, 25, 53, 80, 110, 111, 135, 139, 143, 161, 389, 443,
    445, 514, 587, 636, 993, 995, 1080, 1433, 1521, 1723, 3306, 3389,
    5432, 5900, 6379, 8080, 8443, 8888, 27017, 49152, 49153, 7547,
  ];
  
  static const Map<int, String> portServices = {
    20: 'FTP Data',
    21: 'FTP',
    22: 'SSH',
    23: 'Telnet',
    25: 'SMTP',
    53: 'DNS',
    80: 'HTTP',
    110: 'POP3',
    111: 'RPC',
    135: 'MS-RPC',
    139: 'NetBIOS',
    143: 'IMAP',
    161: 'SNMP',
    389: 'LDAP',
    443: 'HTTPS',
    445: 'SMB',
    514: 'Syslog',
    587: 'SMTP Submission',
    636: 'LDAPS',
    993: 'IMAPS',
    995: 'POP3S',
    1080: 'SOCKS Proxy',
    1433: 'MSSQL',
    1521: 'Oracle',
    1723: 'PPTP',
    3306: 'MySQL',
    3389: 'RDP',
    5432: 'PostgreSQL',
    5900: 'VNC',
    6379: 'Redis',
    8080: 'HTTP Alt',
    8443: 'HTTPS Alt',
    8888: 'HTTP Proxy',
    27017: 'MongoDB',
    49152: 'UPnP',
    49153: 'UPnP',
    7547: 'TR-069 (CWMP)',
  };
  
  /// فحص بورت واحد
  static Future<PortScanResult> scanPort(String host, int port, {Duration timeout = const Duration(seconds: 3)}) async {
    final start = DateTime.now();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      final responseTime = DateTime.now().difference(start).inMilliseconds;
      
      // محاولة قراءة banner (للخدمات التي ترسل welcome message)
      String? banner;
      try {
        final data = await socket.first.timeout(const Duration(seconds: 2));
        banner = String.fromCharCodes(data).trim();
        if (banner.length > 100) banner = banner.substring(0, 100);
      } catch (_) {}
      
      socket.destroy();
      
      return PortScanResult(
        port: port,
        service: portServices[port] ?? 'Unknown',
        isOpen: true,
        responseTime: responseTime,
        banner: banner,
      );
    } on SocketException {
      return PortScanResult(
        port: port,
        service: portServices[port] ?? 'Unknown',
        isOpen: false,
      );
    } catch (_) {
      return PortScanResult(
        port: port,
        service: portServices[port] ?? 'Unknown',
        isOpen: false,
      );
    }
  }
  
  /// فحص عدة بورتات بالتوازي
  static Future<List<PortScanResult>> scanPorts(
    String host,
    List<int> ports, {
    int concurrency = 50,
    Duration timeout = const Duration(seconds: 3),
    Function(int scanned, int total)? onProgress,
  }) async {
    final results = <PortScanResult>[];
    var completed = 0;
    
    // تقسيم البورتات إلى batches
    for (var i = 0; i < ports.length; i += concurrency) {
      final batch = ports.skip(i).take(concurrency).toList();
      final batchResults = await Future.wait(
        batch.map((port) async {
          final result = await scanPort(host, port, timeout: timeout);
          completed++;
          onProgress?.call(completed, ports.length);
          return result;
        }),
      );
      results.addAll(batchResults);
    }
    
    return results;
  }
  
  /// فحص البورتات الشائعة
  static Future<ScanSummary> scanCommonPorts(
    String host, {
    Function(int scanned, int total)? onProgress,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final start = DateTime.now();
    final results = await scanPorts(host, commonPorts, onProgress: onProgress, timeout: timeout);
    final duration = DateTime.now().difference(start);
    
    final openPorts = results.where((r) => r.isOpen).toList();
    final closedPorts = results.where((r) => !r.isOpen).toList();
    
    // حساب درجة الأمان
    final securityScore = _calculateSecurityScore(openPorts);
    final risks = _identifyRisks(openPorts);
    final recommendations = _generateRecommendations(openPorts, securityScore);
    
    return ScanSummary(
      host: host,
      scanTime: start.toIso8601String(),
      duration: duration,
      totalPorts: results.length,
      openPortsCount: openPorts.length,
      closedPortsCount: closedPorts.length,
      openPorts: openPorts,
      closedPorts: closedPorts,
      securityScore: securityScore,
      risks: risks,
      recommendations: recommendations,
    );
  }
  
  /// فحص نطاق بورتات (مثلاً 1-1024)
  static Future<ScanSummary> scanPortRange(
    String host,
    int startPort,
    int endPort, {
    Function(int scanned, int total)? onProgress,
    Duration timeout = const Duration(seconds: 1),
    int concurrency = 100,
  }) async {
    final ports = List.generate(endPort - startPort + 1, (i) => startPort + i);
    final scanStart = DateTime.now();
    final results = await scanPorts(host, ports, concurrency: concurrency, onProgress: onProgress, timeout: timeout);
    final duration = DateTime.now().difference(scanStart);
    
    final openPorts = results.where((r) => r.isOpen).toList();
    final closedPorts = results.where((r) => !r.isOpen).toList();
    final securityScore = _calculateSecurityScore(openPorts);
    final risks = _identifyRisks(openPorts);
    final recommendations = _generateRecommendations(openPorts, securityScore);
    
    return ScanSummary(
      host: host,
      scanTime: scanStart.toIso8601String(),
      duration: duration,
      totalPorts: results.length,
      openPortsCount: openPorts.length,
      closedPortsCount: closedPorts.length,
      openPorts: openPorts,
      closedPorts: closedPorts,
      securityScore: securityScore,
      risks: risks,
      recommendations: recommendations,
    );
  }
  
  /// UDP scan (محدود لأنه يحتاج raw sockets)
  static Future<bool> scanUdpPort(String host, int port, {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      // UDP scanning محدود في Dart - نستخدم RawDatagramSocket
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.send(_createUdpProbe(port), InternetAddress(host), port);
      
      final completer = Completer<bool>();
      Timer timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          socket.close();
          completer.complete(false);
        }
      });
      
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final data = socket.receive();
          if (data != null && !completer.isCompleted) {
            timer.cancel();
            socket.close();
            completer.complete(true);
          }
        }
      });
      
      return completer.future;
    } catch (_) {
      return false;
    }
  }
  
  static List<int> _createUdpProbe(int port) {
    // DNS query بسيط للبورت 53، أو probe فارغ للباقي
    if (port == 53) {
      return [
        0x00, 0x00, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x07, 0x67, 0x6f, 0x6f,
        0x67, 0x6c, 0x65, 0x03, 0x63, 0x6f, 0x6d, 0x00,
        0x00, 0x01, 0x00, 0x01,
      ];
    }
    return [0x00];
  }
  
  static int _calculateSecurityScore(List<PortScanResult> openPorts) {
    int score = 100;
    final dangerousPorts = {23: 15, 21: 10, 161: 12, 389: 10, 1433: 10, 3389: 8, 7547: 15, 445: 8, 139: 8};
    
    for (final p in openPorts) {
      if (dangerousPorts.containsKey(p.port)) {
        score -= dangerousPorts[p.port]!;
      }
    }
    
    return score.clamp(0, 100);
  }
  
  static List<String> _identifyRisks(List<PortScanResult> openPorts) {
    final risks = <String>[];
    
    for (final p in openPorts) {
      switch (p.port) {
        case 23:
          risks.add('🔴 Telnet (${p.port}) - غير مشفّر، استخدم SSH بدلاً منه');
          break;
        case 21:
          risks.add('🔴 FTP (${p.port}) - غير مشفّر، استخدم SFTP/SCP');
          break;
        case 161:
          risks.add('🟡 SNMP (${p.port}) - قد يكشف معلومات حساسة');
          break;
        case 3389:
          risks.add('🟡 RDP (${p.port}) - قيّده بـ VPN');
          break;
        case 445:
          risks.add('🟡 SMB (${p.port}) - عرضة لهجمات WannaCry');
          break;
        case 7547:
          risks.add('🔴 TR-069 (${p.port}) - يمكن استغلاله للتحكم بالراوتر');
          break;
        case 49152:
        case 49153:
          risks.add('🟡 UPnP (${p.port}) - قد يسمح للأجهزة بفتح بورتات تلقائياً');
          break;
      }
    }
    
    return risks;
  }
  
  static List<String> _generateRecommendations(List<PortScanResult> openPorts, int score) {
    final recs = <String>[];
    
    if (score >= 80) {
      recs.add('✅ الشبكة آمنة بشكل جيد');
    } else if (score >= 50) {
      recs.add('⚠️ الشبكة تحتاج لتحسينات أمنية');
    } else {
      recs.add('🔴 الشبكة معرضة للخطر، تحسينات عاجلة مطلوبة');
    }
    
    for (final p in openPorts) {
      switch (p.port) {
        case 23:
          recs.add('🔴 عطّل Telnet من إعدادات الراوتر فوراً');
          break;
        case 21:
          recs.add('🔴 عطّل FTP أو استخدم SFTP');
          break;
        case 161:
          recs.add('🟡 استخدم SNMP v3 مع كلمة مرور قوية');
          break;
        case 3389:
          recs.add('🟡 قيّد RDP بـ VPN أو IP whitelist');
          break;
        case 7547:
          recs.add('🔴 عطّل TR-069/CWMP لو ما تستخدمه');
          break;
        case 445:
          recs.add('🟡 عطّل SMB على الإنترنت العام');
          break;
      }
    }
    
    return recs;
  }
}

class PortScanResult {
  final int port;
  final String service;
  final bool isOpen;
  final int? responseTime;
  final String? banner;
  
  PortScanResult({
    required this.port,
    required this.service,
    required this.isOpen,
    this.responseTime,
    this.banner,
  });
  
  Map<String, dynamic> toJson() => {
    'port': port,
    'service': service,
    'isOpen': isOpen,
    'responseTime': responseTime,
    'banner': banner,
  };
}

class ScanSummary {
  final String host;
  final String scanTime;
  final Duration duration;
  final int totalPorts;
  final int openPortsCount;
  final int closedPortsCount;
  final List<PortScanResult> openPorts;
  final List<PortScanResult> closedPorts;
  final int securityScore;
  final List<String> risks;
  final List<String> recommendations;
  
  ScanSummary({
    required this.host,
    required this.scanTime,
    required this.duration,
    required this.totalPorts,
    required this.openPortsCount,
    required this.closedPortsCount,
    required this.openPorts,
    required this.closedPorts,
    required this.securityScore,
    required this.risks,
    required this.recommendations,
  });
  
  Map<String, dynamic> toJson() => {
    'host': host,
    'scanTime': scanTime,
    'durationMs': duration.inMilliseconds,
    'totalPorts': totalPorts,
    'openPortsCount': openPortsCount,
    'closedPortsCount': closedPortsCount,
    'openPorts': openPorts.map((p) => p.toJson()).toList(),
    'securityScore': securityScore,
    'risks': risks,
    'recommendations': recommendations,
  };
}
