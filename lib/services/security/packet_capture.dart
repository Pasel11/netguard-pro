import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

/// خدمة التقاط حزم الشبكة
/// تتطلب root على الأندرويد أو بدائل للنظام
/// تستخدم tcpdump عبر Process.run أو pcap محلي
class PacketCaptureService {
  Process? _tcpdumpProcess;
  bool _isCapturing = false;
  final List<Packet> _capturedPackets = [];
  final StreamController<Packet> _packetController = StreamController.broadcast();
  
  Stream<Packet> get packetStream => _packetController.stream;
  List<Packet> get capturedPackets => List.unmodifiable(_capturedPackets);
  bool get isCapturing => _isCapturing;
  int get capturedCount => _capturedPackets.length;
  
  /// بدء التقاط الحزم
  Future<bool> startCapture({
    String interface = 'wlan0',
    int maxPackets = 1000,
    String? filter,
    Duration? timeout,
  }) async {
    if (_isCapturing) return false;
    
    try {
      // التحقق من توفر tcpdump
      final whichResult = await Process.run('which', ['tcpdump']);
      if (whichResult.exitCode != 0) {
        // محاولة استخدام بديل
        return await _startWithPcap(interface, maxPackets, filter, timeout);
      }
      
      // بناء الأمر
      final args = <String>[
        '-i', interface,
        '-c', maxPackets.toString(),
        '-w', '-', // إخراج إلى stdout
        '-nn', // لا تحلل الأسماء
        '-tttt', // timestamp كامل
      ];
      
      if (filter != null) {
        args.add(filter);
      }
      
      // قد نحتاج sudo
      _tcpdumpProcess = await Process.start('su', ['-c', 'tcpdump ${args.join(" ")}']);
      
      _isCapturing = true;
      _capturedPackets.clear();
      
      // قراءة الإخراج
      _tcpdumpProcess!.stdout.transform(const SystemEncoding().decoder).listen(
        (data) => _parsePcapData(data),
        onDone: () => _stopCapture(),
        onError: (e) => _stopCapture(),
      );
      
      _tcpdumpProcess!.stderr.listen((data) {
        // تجاهل أخطاء stderr (عادة تحذيرات)
      });
      
      // timeout
      if (timeout != null) {
        Timer(timeout, () => stopCapture());
      }
      
      return true;
    } catch (e) {
      // فشل - نرجع false
      return false;
    }
  }
  
  /// بدء التقاط بدون root باستخدام pcap
  Future<bool> _startWithPcap(
    String interface,
    int maxPackets,
    String? filter,
    Duration? timeout,
  ) async {
    // على الأندرويد بدون root، نستخدم VPN service
    // لكن هذا يتطلب native code
    // نرجع false حالياً
    return false;
  }
  
  /// إيقاف التقاط
  Future<void> stopCapture() async {
    await _stopCapture();
  }
  
  Future<void> _stopCapture() async {
    if (_tcpdumpProcess != null) {
      _tcpdumpProcess!.kill(ProcessSignal.sigterm);
      await _tcpdumpProcess!.exitCode;
      _tcpdumpProcess = null;
    }
    _isCapturing = false;
  }
  
  /// تحليل بيانات pcap الناتجة
  void _parsePcapData(String data) {
    final lines = data.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      final packet = _parsePacketLine(line);
      if (packet != null) {
        _capturedPackets.add(packet);
        _packetController.add(packet);
      }
    }
  }
  
  /// تحليل سطر واحد من tcpdump
  Packet? _parsePacketLine(String line) {
    try {
      // مثال: 10:30:45.123456 IP 192.168.1.100.50123 > 8.8.8.8.53: 12345+ A? google.com. (32)
      final ipMatch = RegExp(
        r'(\d{2}:\d{2}:\d{2}\.\d+)\s+IP\s+(\d+\.\d+\.\d+\.\d+)\.(\d+)\s+>\s+(\d+\.\d+\.\d+\.\d+)\.(\d+):\s+(.*)'
      ).firstMatch(line);
      
      if (ipMatch != null) {
        final timestamp = ipMatch.group(1)!;
        final srcIp = ipMatch.group(2)!;
        final srcPort = int.tryParse(ipMatch.group(3)!) ?? 0;
        final dstIp = ipMatch.group(4)!;
        final dstPort = int.tryParse(ipMatch.group(5)!) ?? 0;
        final info = ipMatch.group(6)!;
        
        // تحديد البروتوكول
        final protocol = _detectProtocol(srcPort, dstPort, info);
        final size = _extractPacketSize(info);
        
        return Packet(
          timestamp: timestamp,
          sourceIp: srcIp,
          sourcePort: srcPort,
          destinationIp: dstIp,
          destinationPort: dstPort,
          protocol: protocol,
          info: info,
          size: size,
        );
      }
    } catch (_) {}
    
    return null;
  }
  
  String _detectProtocol(int srcPort, int dstPort, String info) {
    if (dstPort == 80 || srcPort == 80) return 'HTTP';
    if (dstPort == 443 || srcPort == 443) return 'HTTPS';
    if (dstPort == 53 || srcPort == 53) return 'DNS';
    if (dstPort == 22 || srcPort == 22) return 'SSH';
    if (dstPort == 21 || srcPort == 21) return 'FTP';
    if (info.contains('TCP')) return 'TCP';
    if (info.contains('UDP')) return 'UDP';
    if (info.contains('ICMP')) return 'ICMP';
    if (info.contains('ARP')) return 'ARP';
    return 'Other';
  }
  
  int _extractPacketSize(String info) {
    final match = RegExp(r'\((\d+)\)').firstMatch(info);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }
  
  /// تحليل الحزم الملتقطة
  PacketAnalysis analyzePackets() {
    if (_capturedPackets.isEmpty) {
      return PacketAnalysis(
        totalPackets: 0,
        protocolCounts: {},
        topSources: [],
        topDestinations: [],
        totalBytes: 0,
        suspiciousPackets: [],
      );
    }
    
    final protocolCounts = <String, int>{};
    final sourceCounts = <String, int>{};
    final destinationCounts = <String, int>{};
    final suspiciousPackets = <SuspiciousPacket>[];
    var totalBytes = 0;
    
    for (final packet in _capturedPackets) {
      protocolCounts[packet.protocol] = (protocolCounts[packet.protocol] ?? 0) + 1;
      sourceCounts[packet.sourceIp] = (sourceCounts[packet.sourceIp] ?? 0) + 1;
      destinationCounts[packet.destinationIp] = (destinationCounts[packet.destinationIp] ?? 0) + 1;
      totalBytes += packet.size;
      
      // كشف حزم مشبوهة
      final suspicious = _detectSuspiciousActivity(packet);
      if (suspicious != null) {
        suspiciousPackets.add(suspicious);
      }
    }
    
    final topSources = sourceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDestinations = destinationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return PacketAnalysis(
      totalPackets: _capturedPackets.length,
      protocolCounts: protocolCounts,
      topSources: topSources.take(10).map((e) => MapEntry(e.key, e.value)).toList(),
      topDestinations: topDestinations.take(10).map((e) => MapEntry(e.key, e.value)).toList(),
      totalBytes: totalBytes,
      suspiciousPackets: suspiciousPackets,
    );
  }
  
  /// كشف النشاط المشبوه
  SuspiciousPacket? _detectSuspiciousActivity(Packet packet) {
    // فحص بورتات خطيرة
    const maliciousPorts = [1337, 31337, 4444, 6667, 6666, 9999];
    
    if (maliciousPorts.contains(packet.destinationPort) || 
        maliciousPorts.contains(packet.sourcePort)) {
      return SuspiciousPacket(
        packet: packet,
        reason: 'بورت مرتبط ببرامج خبيثة',
        severity: 'high',
      );
    }
    
    // فحص حمولة كبيرة بشكل غير عادي
    if (packet.size > 65535) {
      return SuspiciousPacket(
        packet: packet,
        reason: 'حزمة بحجم غير عادي',
        severity: 'medium',
      );
    }
    
    // فحص IPs خاصة بـ botnets معروفة
    const knownBadIps = ['185.220.101.1', '185.220.101.2']; // أمثلة
    if (knownBadIps.contains(packet.sourceIp) || 
        knownBadIps.contains(packet.destinationIp)) {
      return SuspiciousPacket(
        packet: packet,
        reason: 'اتصال بـ IP معروف بأنه خبيث',
        severity: 'critical',
      );
    }
    
    // فحص DNS tunneling (DNS queries طويلة)
    if (packet.protocol == 'DNS' && packet.info.length > 100) {
      return SuspiciousPacket(
        packet: packet,
        reason: 'احتمال DNS tunneling',
        severity: 'medium',
      );
    }
    
    return null;
  }
  
  /// حفظ الحزم الملتقطة في ملف pcap
  Future<String?> saveToPcap(String outputPath) async {
    if (_capturedPackets.isEmpty) return null;
    
    try {
      final file = File(outputPath);
      final buffer = StringBuffer();
      
      // كتابة header
      buffer.writeln('# Packet capture from NetGuard Pro');
      buffer.writeln('# Date: ${DateTime.now().toIso8601String()}');
      buffer.writeln('# Total packets: ${_capturedPackets.length}');
      buffer.writeln('');
      
      for (final packet in _capturedPackets) {
        buffer.writeln(packet.toString());
      }
      
      await file.writeAsString(buffer.toString());
      return outputPath;
    } catch (_) {
      return null;
    }
  }
  
  void dispose() {
    _stopCapture();
    _packetController.close();
  }
}

class Packet {
  final String timestamp;
  final String sourceIp;
  final int sourcePort;
  final String destinationIp;
  final int destinationPort;
  final String protocol;
  final String info;
  final int size;
  
  Packet({
    required this.timestamp,
    required this.sourceIp,
    required this.sourcePort,
    required this.destinationIp,
    required this.destinationPort,
    required this.protocol,
    required this.info,
    required this.size,
  });
  
  @override
  String toString() {
    return '$timestamp $protocol $sourceIp:$sourcePort -> $destinationIp:$destinationPort ($size bytes) $info';
  }
  
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'sourceIp': sourceIp,
    'sourcePort': sourcePort,
    'destinationIp': destinationIp,
    'destinationPort': destinationPort,
    'protocol': protocol,
    'info': info,
    'size': size,
  };
}

class PacketAnalysis {
  final int totalPackets;
  final Map<String, int> protocolCounts;
  final List<MapEntry<String, int>> topSources;
  final List<MapEntry<String, int>> topDestinations;
  final int totalBytes;
  final List<SuspiciousPacket> suspiciousPackets;
  
  PacketAnalysis({
    required this.totalPackets,
    required this.protocolCounts,
    required this.topSources,
    required this.topDestinations,
    required this.totalBytes,
    required this.suspiciousPackets,
  });
  
  double get averagePacketSize => 
    totalPackets > 0 ? totalBytes / totalPackets : 0;
  
  String get formattedTotalBytes {
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1048576) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    return '${(totalBytes / 1048576).toStringAsFixed(1)} MB';
  }
}

class SuspiciousPacket {
  final Packet packet;
  final String reason;
  final String severity;
  
  SuspiciousPacket({
    required this.packet,
    required this.reason,
    required this.severity,
  });
}
