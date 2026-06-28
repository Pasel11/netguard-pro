import 'dart:io';
import 'dart:async';
import 'dart:collection';

/// محلل حركة مرور الشبكة في الوقت الفعلي
/// يراقب حركة المرور ويحلل البروتوكولات والـ bandwidth
class TrafficAnalyzer {
  Timer? _monitorTimer;
  bool _isMonitoring = false;
  
  // بيانات تاريخية للحركة
  final Queue<TrafficSample> _samples = Queue();
  final int _maxSamples = 60; // 60 ثانية
  
  // إحصائيات تراكمية
  int _totalBytesReceived = 0;
  int _totalBytesSent = 0;
  int _totalPacketsReceived = 0;
  int _totalPacketsSent = 0;
  
  // أحدث قراءة
  TrafficSample? _lastSample;
  
  // تحليل البروتوكولات
  final Map<String, int> _protocolStats = {};
  
  // اتصالات نشطة
  final List<NetworkConnection> _activeConnections = [];
  
  final StreamController<TrafficSample> _sampleController = StreamController.broadcast();
  final StreamController<NetworkConnection> _connectionController = StreamController.broadcast();
  
  Stream<TrafficSample> get sampleStream => _sampleController.stream;
  Stream<NetworkConnection> get connectionStream => _connectionController.stream;
  
  List<TrafficSample> get samples => _samples.toList();
  TrafficSample? get lastSample => _lastSample;
  bool get isMonitoring => _isMonitoring;
  
  int get totalBytesReceived => _totalBytesReceived;
  int get totalBytesSent => _totalBytesSent;
  int get totalPacketsReceived => _totalPacketsReceived;
  int get totalPacketsSent => _totalPacketsSent;
  
  Map<String, int> get protocolStats => Map.unmodifiable(_protocolStats);
  List<NetworkConnection> get activeConnections => List.unmodifiable(_activeConnections);
  
  /// بدء المراقبة
  Future<bool> startMonitoring({Duration interval = const Duration(seconds: 1)}) async {
    if (_isMonitoring) return false;
    
    _isMonitoring = true;
    
    // قراءة /proc/net/dev (Linux/Android)
    _monitorTimer = Timer.periodic(interval, (_) => _readTrafficStats());
    
    // قراءة الاتصالات النشطة كل 5 ثوانٍ
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isMonitoring) return;
      _readActiveConnections();
    });
    
    return true;
  }
  
  /// إيقاف المراقبة
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
  }
  
  /// قراءة إحصائيات حركة المرور
  Future<void> _readTrafficStats() async {
    try {
      final file = File('/proc/net/dev');
      if (!await file.exists()) return;
      
      final lines = await file.readAsLines();
      if (lines.length < 3) return;
      
      // تجميع الإحصائيات لكل الواجهات
      int totalRx = 0;
      int totalTx = 0;
      int totalRxPackets = 0;
      int totalTxPackets = 0;
      
      // تجاوز أول سطرين (header)
      for (var i = 2; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        // تقسيم السطر
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 10) continue;
        
        final interface = parts[0].replaceAll(':', '');
        // تجاهل loopback
        if (interface == 'lo') continue;
        
        final rxBytes = int.tryParse(parts[1]) ?? 0;
        final rxPackets = int.tryParse(parts[2]) ?? 0;
        final txBytes = int.tryParse(parts[9]) ?? 0;
        final txPackets = int.tryParse(parts[10]) ?? 0;
        
        totalRx += rxBytes;
        totalTx += txBytes;
        totalRxPackets += rxPackets;
        totalTxPackets += txPackets;
      }
      
      // حساب الفرق منذ آخر قراءة
      final previousSample = _lastSample;
      int deltaRx = 0;
      int deltaTx = 0;
      int deltaRxPackets = 0;
      int deltaTxPackets = 0;
      
      if (previousSample != null) {
        deltaRx = totalRx - previousSample.totalRxBytes;
        deltaTx = totalTx - previousSample.totalTxBytes;
        deltaRxPackets = totalRxPackets - previousSample.totalRxPackets;
        deltaTxPackets = totalTxPackets - previousSample.totalTxPackets;
      }
      
      // حساب المعدل (bps)
      final sample = TrafficSample(
        timestamp: DateTime.now(),
        rxBytes: deltaRx,
        txBytes: deltaTx,
        rxPackets: deltaRxPackets,
        txPackets: deltaTxPackets,
        totalRxBytes: totalRx,
        totalTxBytes: totalTx,
        totalRxPackets: totalRxPackets,
        totalTxPackets: totalTxPackets,
        rxBps: deltaRx * 8,
        txBps: deltaTx * 8,
      );
      
      _lastSample = sample;
      _samples.add(sample);
      
      // الحفاظ على آخر 60 عينة فقط
      while (_samples.length > _maxSamples) {
        _samples.removeFirst();
      }
      
      _totalBytesReceived = totalRx;
      _totalBytesSent = totalTx;
      _totalPacketsReceived = totalRxPackets;
      _totalPacketsSent = totalTxPackets;
      
      _sampleController.add(sample);
    } catch (_) {}
  }
  
  /// قراءة الاتصالات النشطة
  Future<void> _readActiveConnections() async {
    try {
      // قراءة /proc/net/tcp و /proc/net/udp
      await _readTcpConnections();
    } catch (_) {}
  }
  
  /// قراءة اتصالات TCP
  Future<void> _readTcpConnections() async {
    try {
      final file = File('/proc/net/tcp');
      if (!await file.exists()) return;
      
      final lines = await file.readAsLines();
      final newConnections = <NetworkConnection>[];
      
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 10) continue;
        
        // تنسيق: sl local_address rem_address st tx_queue rx_queue ...
        // local_address: "0100007F:1F90" (hex IP:port)
        final localAddr = parts[1];
        final remoteAddr = parts[2];
        final state = parts[3];
        
        final localIp = _parseHexIp(localAddr.split(':')[0]);
        final localPort = int.parse(localAddr.split(':')[1], radix: 16);
        final remoteIp = _parseHexIp(remoteAddr.split(':')[0]);
        final remotePort = int.parse(remoteAddr.split(':')[1], radix: 16);
        
        final connectionState = _parseTcpState(state);
        
        // تجاهل loopback
        if (localIp == '127.0.0.1' || remoteIp == '127.0.0.1') continue;
        if (remoteIp == '0.0.0.0') continue;
        
        final protocol = _guessProtocol(remotePort);
        
        final connection = NetworkConnection(
          protocol: 'TCP',
          localIp: localIp,
          localPort: localPort,
          remoteIp: remoteIp,
          remotePort: remotePort,
          state: connectionState,
          service: protocol,
          timestamp: DateTime.now(),
        );
        
        newConnections.add(connection);
        
        // تحديث إحصائيات البروتوكول
        _protocolStats[protocol] = (_protocolStats[protocol] ?? 0) + 1;
      }
      
      _activeConnections.clear();
      _activeConnections.addAll(newConnections);
      
      // إرسال الاتصالات الجديدة عبر stream
      for (final conn in newConnections) {
        _connectionController.add(conn);
      }
    } catch (_) {}
  }
  
  /// تحويل hex IP إلى dotted decimal
  String _parseHexIp(String hex) {
    if (hex.length != 8) return '0.0.0.0';
    
    // تنسيق /proc/net/tcp: reversed bytes
    // مثال: "0100007F" = 127.0.0.1
    final b1 = int.parse(hex.substring(6, 8), radix: 16);
    final b2 = int.parse(hex.substring(4, 6), radix: 16);
    final b3 = int.parse(hex.substring(2, 4), radix: 16);
    final b4 = int.parse(hex.substring(0, 2), radix: 16);
    
    return '$b1.$b2.$b3.$b4';
  }
  
  /// تحويل state code إلى نص
  String _parseTcpState(String state) {
    const states = {
      '01': 'ESTABLISHED',
      '02': 'SYN_SENT',
      '03': 'SYN_RECV',
      '04': 'FIN_WAIT1',
      '05': 'FIN_WAIT2',
      '06': 'TIME_WAIT',
      '07': 'CLOSE',
      '08': 'CLOSE_WAIT',
      '09': 'LAST_ACK',
      '0A': 'LISTEN',
      '0B': 'CLOSING',
    };
    return states[state] ?? 'UNKNOWN';
  }
  
  /// تخمين البروتوكول من البورت
  String _guessProtocol(int port) {
    const protocols = {
      80: 'HTTP',
      443: 'HTTPS',
      53: 'DNS',
      22: 'SSH',
      21: 'FTP',
      25: 'SMTP',
      110: 'POP3',
      143: 'IMAP',
      993: 'IMAPS',
      995: 'POP3S',
      587: 'SMTPS',
      3389: 'RDP',
      5432: 'PostgreSQL',
      3306: 'MySQL',
      6379: 'Redis',
      27017: 'MongoDB',
      8080: 'HTTP-Alt',
      8443: 'HTTPS-Alt',
    };
    return protocols[port] ?? 'Unknown';
  }
  
  /// الحصول على متوسط السرعة (آخر 10 ثوانٍ)
  TrafficStats? getAverageStats() {
    if (_samples.length < 2) return null;
    
    final recentSamples = _samples.toList().reversed.take(10).toList();
    
    int totalRx = 0;
    int totalTx = 0;
    
    for (final s in recentSamples) {
      totalRx += s.rxBps;
      totalTx += s.txBps;
    }
    
    return TrafficStats(
      avgRxBps: totalRx ~/ recentSamples.length,
      avgTxBps: totalTx ~/ recentSamples.length,
      avgRxMbps: (totalRx / recentSamples.length) / 1000000,
      avgTxMbps: (totalTx / recentSamples.length) / 1000000,
    );
  }
  
  /// الحصول على ذروة السرعة
  TrafficStats? getPeakStats() {
    if (_samples.isEmpty) return null;
    
    int peakRx = 0;
    int peakTx = 0;
    
    for (final s in _samples) {
      if (s.rxBps > peakRx) peakRx = s.rxBps;
      if (s.txBps > peakTx) peakTx = s.txBps;
    }
    
    return TrafficStats(
      avgRxBps: peakRx,
      avgTxBps: peakTx,
      avgRxMbps: peakRx / 1000000,
      avgTxMbps: peakTx / 1000000,
    );
  }
  
  void dispose() {
    stopMonitoring();
    _sampleController.close();
    _connectionController.close();
  }
}

class TrafficSample {
  final DateTime timestamp;
  final int rxBytes;        // bytes received in this sample
  final int txBytes;        // bytes sent in this sample
  final int rxPackets;
  final int txPackets;
  final int totalRxBytes;   // total since monitor started
  final int totalTxBytes;
  final int totalRxPackets;
  final int totalTxPackets;
  final int rxBps;          // bits per second
  final int txBps;
  
  TrafficSample({
    required this.timestamp,
    required this.rxBytes,
    required this.txBytes,
    required this.rxPackets,
    required this.txPackets,
    required this.totalRxBytes,
    required this.totalTxBytes,
    required this.totalRxPackets,
    required this.totalTxPackets,
    required this.rxBps,
    required this.txBps,
  });
  
  double get rxMbps => rxBps / 1000000;
  double get txMbps => txBps / 1000000;
}

class TrafficStats {
  final int avgRxBps;
  final int avgTxBps;
  final double avgRxMbps;
  final double avgTxMbps;
  
  TrafficStats({
    required this.avgRxBps,
    required this.avgTxBps,
    required this.avgRxMbps,
    required this.avgTxMbps,
  });
}

class NetworkConnection {
  final String protocol;
  final String localIp;
  final int localPort;
  final String remoteIp;
  final int remotePort;
  final String state;
  final String service;
  final DateTime timestamp;
  
  NetworkConnection({
    required this.protocol,
    required this.localIp,
    required this.localPort,
    required this.remoteIp,
    required this.remotePort,
    required this.state,
    required this.service,
    required this.timestamp,
  });
  
  bool get isEstablished => state == 'ESTABLISHED';
  bool get isListening => state == 'LISTEN';
  bool get isHttps => remotePort == 443 || remotePort == 8443;
  bool get isHttp => remotePort == 80 || remotePort == 8080;
}
