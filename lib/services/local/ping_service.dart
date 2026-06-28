import 'dart:io';
import 'dart:async';

/// خدمة Ping و Traceroute حقيقية - تشتغل محلياً
class PingService {
  /// Ping واحد لعنوان معين
  static Future<PingResult> ping(String host, {int count = 4, int timeout = 2}) async {
    final results = <PingReply>[];
    var totalSent = 0;
    var totalReceived = 0;
    var totalRtt = 0;
    
    for (var i = 0; i < count; i++) {
      totalSent++;
      final reply = await _singlePing(host, timeout);
      
      if (reply.success) {
        totalReceived++;
        totalRtt += reply.rtt ?? 0;
      }
      
      results.add(reply);
      
      // انتظار قصير بين الـ pings
      if (i < count - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    final loss = ((totalSent - totalReceived) / totalSent * 100).round();
    final avgRtt = totalReceived > 0 ? (totalRtt / totalReceived).round() : 0;
    
    return PingResult(
      host: host,
      timestamp: DateTime.now().toIso8601String(),
      replies: results,
      packetsSent: totalSent,
      packetsReceived: totalReceived,
      packetLoss: loss,
      minRtt: results.where((r) => r.success).map((r) => r.rtt ?? 0).fold<int>(9999, (a, b) => a < b ? a : b),
      maxRtt: results.where((r) => r.success).map((r) => r.rtt ?? 0).fold<int>(0, (a, b) => a > b ? a : b),
      avgRtt: avgRtt,
    );
  }
  
  /// ping واحد
  static Future<PingReply> _singlePing(String host, int timeout) async {
    final start = DateTime.now();
    
    try {
      // محاولة استخدام أمر ping للنظام
      final result = await Process.run(
        'ping',
        ['-c', '1', '-W', timeout.toString(), host],
      ).timeout(Duration(seconds: timeout + 1));
      
      final rtt = DateTime.now().difference(start).inMilliseconds;
      final output = result.stdout.toString();
      
      if (result.exitCode == 0 || output.contains('bytes from')) {
        final timeMatch = RegExp(r'time=([\d.]+)\s*ms').firstMatch(output);
        final actualRtt = timeMatch != null 
            ? double.tryParse(timeMatch.group(1)!)?.round() ?? rtt
            : rtt;
        
        final ttlMatch = RegExp(r'ttl=(\d+)').firstMatch(output);
        final ttl = ttlMatch != null ? int.tryParse(ttlMatch.group(1)!) : null;
        
        return PingReply(
          success: true,
          rtt: actualRtt,
          ttl: ttl,
          error: null,
        );
      } else {
        return PingReply(
          success: false,
          rtt: null,
          ttl: null,
          error: 'Host unreachable',
        );
      }
    } on TimeoutException {
      return PingReply(
        success: false,
        rtt: null,
        ttl: null,
        error: 'Request timed out',
      );
    } catch (e) {
      // محاولة بديلة عبر TCP ping
      return _tcpPing(host, 80, Duration(seconds: timeout));
    }
  }
  
  /// TCP Ping (بديل عندما ICMP ممنوع)
  static Future<PingReply> _tcpPing(String host, int port, Duration timeout) async {
    final start = DateTime.now();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      final rtt = DateTime.now().difference(start).inMilliseconds;
      socket.destroy();
      
      return PingReply(
        success: true,
        rtt: rtt,
        ttl: null,
        error: null,
      );
    } catch (_) {
      return PingReply(
        success: false,
        rtt: null,
        ttl: null,
        error: 'Connection failed',
      );
    }
  }
  
  /// Traceroute حقيقي
  static Future<TracerouteResult> traceroute(String host, {int maxHops = 30, int timeout = 3}) async {
    final hops = <TracerouteHop>[];
    
    // محاولة استخدام traceroute للنظام
    try {
      final result = await Process.run(
        'traceroute',
        ['-m', maxHops.toString(), '-w', timeout.toString(), host],
      ).timeout(Duration(seconds: maxHops * timeout + 10));
      
      final lines = result.stdout.toString().split('\n');
      
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final hop = _parseTracerouteLine(line, i);
        if (hop != null) {
          hops.add(hop);
        }
      }
    } catch (_) {
      // إذا فشل traceroute، نستخدم طريقة بديلة عبر TTL manipulation
      // لكن هذا يحتاج raw sockets غير متاحة بسهولة في Dart
      hops.add(TracerouteHop(
        hopNumber: 1,
        host: 'Traceroute not available',
        ip: '',
        rtt1: null,
        rtt2: null,
        rtt3: null,
      ));
    }
    
    return TracerouteResult(
      host: host,
      timestamp: DateTime.now().toIso8601String(),
      hops: hops,
      totalHops: hops.length,
      reachedDestination: hops.isNotEmpty && hops.last.ip == host,
    );
  }
  
  /// Parse سطر من ناتج traceroute
  static TracerouteHop? _parseTracerouteLine(String line, int hopNumber) {
    try {
      final parts = line.split(RegExp(r'\s+'));
      if (parts.isEmpty) return null;
      
      String? ip;
      List<double?> rtts = [];
      
      for (var i = 1; i < parts.length; i++) {
        final part = parts[i];
        
        // IP address
        if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(part) ||
            RegExp(r'^[0-9a-fA-F:]+$').hasMatch(part)) {
          ip ??= part;
        }
        // RTT (ms)
        else if (part.endsWith('ms')) {
          final rttStr = part.replaceAll('ms', '');
          final rtt = double.tryParse(rttStr);
          if (rtt != null) rtts.add(rtt);
        }
      }
      
      return TracerouteHop(
        hopNumber: hopNumber,
        host: parts.length > 1 ? parts[1] : '',
        ip: ip ?? '',
        rtt1: rtts.isNotEmpty ? rtts[0].round() : null,
        rtt2: rtts.length > 1 ? rtts[1].round() : null,
        rtt3: rtts.length > 2 ? rtts[2].round() : null,
      );
    } catch (_) {
      return null;
    }
  }
  
  /// فحص Latency لعدة hosts
  static Future<Map<String, PingResult>> pingMultiple(List<String> hosts) async {
    final results = <String, PingResult>{};
    
    for (final host in hosts) {
      try {
        final result = await ping(host, count: 1, timeout: 2);
        results[host] = result;
      } catch (_) {
        // skip failed
      }
    }
    
    return results;
  }
}

class PingReply {
  final bool success;
  final int? rtt;
  final int? ttl;
  final String? error;
  
  PingReply({
    required this.success,
    required this.rtt,
    required this.ttl,
    required this.error,
  });
}

class PingResult {
  final String host;
  final String timestamp;
  final List<PingReply> replies;
  final int packetsSent;
  final int packetsReceived;
  final int packetLoss;
  final int minRtt;
  final int maxRtt;
  final int avgRtt;
  
  PingResult({
    required this.host,
    required this.timestamp,
    required this.replies,
    required this.packetsSent,
    required this.packetsReceived,
    required this.packetLoss,
    required this.minRtt,
    required this.maxRtt,
    required this.avgRtt,
  });
  
  Map<String, dynamic> toJson() => {
    'host': host,
    'timestamp': timestamp,
    'packetsSent': packetsSent,
    'packetsReceived': packetsReceived,
    'packetLoss': packetLoss,
    'minRtt': minRtt,
    'maxRtt': maxRtt,
    'avgRtt': avgRtt,
    'replies': replies.map((r) => {
      'success': r.success,
      'rtt': r.rtt,
      'ttl': r.ttl,
      'error': r.error,
    }).toList(),
  };
}

class TracerouteHop {
  final int hopNumber;
  final String host;
  final String ip;
  final int? rtt1;
  final int? rtt2;
  final int? rtt3;
  
  TracerouteHop({
    required this.hopNumber,
    required this.host,
    required this.ip,
    required this.rtt1,
    required this.rtt2,
    required this.rtt3,
  });
  
  double? get avgRtt {
    final rtts = [rtt1, rtt2, rtt3].whereType<int>().toList();
    if (rtts.isEmpty) return null;
    return rtts.reduce((a, b) => a + b) / rtts.length;
  }
}

class TracerouteResult {
  final String host;
  final String timestamp;
  final List<TracerouteHop> hops;
  final int totalHops;
  final bool reachedDestination;
  
  TracerouteResult({
    required this.host,
    required this.timestamp,
    required this.hops,
    required this.totalHops,
    required this.reachedDestination,
  });
}
