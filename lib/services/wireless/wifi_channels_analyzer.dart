import 'dart:io';
import 'dart:async';

/// محلل قنوات WiFi
/// يفحص ازدحام كل قناة ويوصي بأفضل قناة
class WifiChannelsAnalyzer {
  bool _isScanning = false;
  final List<WifiChannelInfo> _channels = [];
  
  List<WifiChannelInfo> get channels => List.unmodifiable(_channels);
  bool get isScanning => _isScanning;
  
  /// فحص شامل لكل قنوات WiFi
  Future<WifiChannelsAnalysis> performScan() async {
    if (_isScanning) {
      return WifiChannelsAnalysis(
        channels: [],
        recommendations: [],
        bestChannel24Ghz: null,
        bestChannel5Ghz: null,
        timestamp: DateTime.now(),
        error: 'Scan already running',
      );
    }
    
    _isScanning = true;
    _channels.clear();
    
    try {
      // محاولة استخدام iwlist (تحتاج root على بعض الأجهزة)
      final result = await Process.run('iwlist', ['wlan0', 'scan'])
          .timeout(const Duration(seconds: 15));
      
      if (result.exitCode == 0) {
        _parseIwlistOutput(result.stdout.toString());
      }
      
      // حساب الازدحام لكل قناة
      _calculateChannelCongestion();
      
      // توليد التوصيات
      final recommendations = _generateRecommendations();
      final best24 = _findBestChannel('2.4GHz');
      final best5 = _findBestChannel('5GHz');
      
      _isScanning = false;
      
      return WifiChannelsAnalysis(
        channels: _channels,
        recommendations: recommendations,
        bestChannel24Ghz: best24,
        bestChannel5Ghz: best5,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _isScanning = false;
      return WifiChannelsAnalysis(
        channels: [],
        recommendations: [],
        bestChannel24Ghz: null,
        bestChannel5Ghz: null,
        timestamp: DateTime.now(),
        error: e.toString(),
      );
    }
  }
  
  /// تحليل ناتج iwlist
  void _parseIwlistOutput(String output) {
    final lines = output.split('\n');
    WifiChannelInfo? currentChannel;
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      // Channel:6
      final channelMatch = RegExp(r'Channel:(\d+)').firstMatch(trimmed);
      if (channelMatch != null) {
        if (currentChannel != null) _channels.add(currentChannel);
        final channelNum = int.parse(channelMatch.group(1)!);
        currentChannel = WifiChannelInfo(
          channel: channelNum,
          frequency: _channelToFrequency(channelNum),
          band: _channelToBand(channelNum),
          networksCount: 0,
          totalSignal: 0,
          networks: [],
        );
        continue;
      }
      
      if (currentChannel == null) continue;
      
      // Frequency:2.437 GHz (Channel 6)
      final freqMatch = RegExp(r'Frequency:([\d.]+)\s*GHz').firstMatch(trimmed);
      if (freqMatch != null) {
        currentChannel = WifiChannelInfo(
          channel: currentChannel.channel,
          frequency: double.parse(freqMatch.group(1)!),
          band: currentChannel.band,
          networksCount: currentChannel.networksCount,
          totalSignal: currentChannel.totalSignal,
          networks: currentChannel.networks,
        );
        continue;
      }
      
      // Signal level=-40 dBm
      final signalMatch = RegExp(r'Signal level=(-?\d+)\s*dBm').firstMatch(trimmed);
      if (signalMatch != null) {
        currentChannel.networksCount++;
        currentChannel.totalSignal += int.parse(signalMatch.group(1)!);
        currentChannel.networks.add(NetworkSignal(
          ssid: '',
          bssid: '',
          signal: int.parse(signalMatch.group(1)!),
          channel: currentChannel.channel,
        ));
        continue;
      }
      
      // ESSID:"NetworkName"
      final essidMatch = RegExp(r'ESSID:"([^"]*)"').firstMatch(trimmed);
      if (essidMatch != null && currentChannel.networks.isNotEmpty) {
        currentChannel.networks.last.ssid = essidMatch.group(1)!;
      }
      
      // Address: AA:BB:CC:DD:EE:FF
      final addrMatch = RegExp(r'Address:\s*([0-9A-Fa-f:]{17})').firstMatch(trimmed);
      if (addrMatch != null && currentChannel.networks.isNotEmpty) {
        currentChannel.networks.last.bssid = addrMatch.group(1)!;
      }
    }
    
    if (currentChannel != null) _channels.add(currentChannel);
    
    // دمج نفس القناة في عنصر واحد
    _mergeSameChannels();
  }
  
  /// دمج القنوات المتكررة
  void _mergeSameChannels() {
    final merged = <int, WifiChannelInfo>{};
    
    for (final channel in _channels) {
      if (!merged.containsKey(channel.channel)) {
        merged[channel.channel] = channel;
      } else {
        final existing = merged[channel.channel]!;
        existing.networksCount += channel.networksCount;
        existing.totalSignal += channel.totalSignal;
        existing.networks.addAll(channel.networks);
      }
    }
    
    _channels.clear();
    _channels.addAll(merged.values);
    _channels.sort((a, b) => a.channel.compareTo(b.channel));
  }
  
  /// حساب ازدحام كل قناة
  void _calculateChannelCongestion() {
    for (final channel in _channels) {
      // الازدحام بناءً على عدد الشبكات
      channel.congestionLevel = _calculateCongestion(channel.networksCount);
      
      // متوسط قوة الإشارة
      if (channel.networksCount > 0) {
        channel.averageSignal = channel.totalSignal ~/ channel.networksCount;
      }
      
      // احتساب تداخل القنوات المتجاورة (2.4GHz فقط)
      if (channel.band == '2.4GHz') {
        channel.interference = _calculateInterference(channel.channel);
      }
    }
  }
  
  /// حساب مستوى الازدحام
  CongestionLevel _calculateCongestion(int networksCount) {
    if (networksCount == 0) return CongestionLevel.empty;
    if (networksCount <= 2) return CongestionLevel.low;
    if (networksCount <= 5) return CongestionLevel.medium;
    if (networksCount <= 10) return CongestionLevel.high;
    return CongestionLevel.critical;
  }
  
  /// حساب التداخل مع القنوات المجاورة
  int _calculateInterference(int channel) {
    if (channel < 1 || channel > 14) return 0;
    
    int interference = 0;
    
    for (final other in _channels) {
      if (other.channel == channel) continue;
      if (other.band != '2.4GHz') continue;
      
      // تداخل القنوات في 2.4GHz (كل قناة تتداخل مع ±5)
      final diff = (other.channel - channel).abs();
      if (diff <= 5) {
        // كلما اقتربنا، زاد التداخل
        interference += other.networksCount * (6 - diff);
      }
    }
    
    return interference;
  }
  
  /// توليد التوصيات
  List<String> _generateRecommendations() {
    final recs = <String>[];
    
    final best24 = _findBestChannel('2.4GHz');
    if (best24 != null) {
      recs.add('🟢 أفضل قناة في 2.4GHz: ${best24.channel} (ازدحام: ${best24.congestionText})');
    }
    
    final best5 = _findBestChannel('5GHz');
    if (best5 != null) {
      recs.add('🟢 أفضل قناة في 5GHz: ${best5.channel} (ازدحام: ${best5.congestionText})');
    }
    
    // قنوات مزدحمة يجب تجنبها
    final crowded = _channels.where(
      (c) => c.congestionLevel == CongestionLevel.high || 
             c.congestionLevel == CongestionLevel.critical,
    ).toList();
    
    if (crowded.isNotEmpty) {
      recs.add('🔴 تجنّب القنوات المزدحمة: ${crowded.map((c) => "${c.channel}").join(", ")}');
    }
    
    // توصيات عامة
    recs.add('💡 استخدم 5GHz دائماً لو متاح - أقل ازدحاماً وأسرع');
    recs.add('💡 في 2.4GHz، استخدم فقط القنوات 1, 6, 11 (لا تتداخل)');
    recs.add('💡 لو منزلك كبير، فكّر في إضافة WiFi extender');
    
    return recs;
  }
  
  /// إيجاد أفضل قناة في نطاق معين
  WifiChannelInfo? _findBestChannel(String band) {
    final bandChannels = _channels.where((c) => c.band == band).toList();
    if (bandChannels.isEmpty) return null;
    
    // ترتيب حسب: 1) الازدحام 2) التداخل
    bandChannels.sort((a, b) {
      final congestionCompare = a.networksCount.compareTo(b.networksCount);
      if (congestionCompare != 0) return congestionCompare;
      return (a.interference ?? 0).compareTo((b.interference ?? 0));
    });
    
    return bandChannels.first;
  }
  
  /// تحويل رقم القناة إلى تردد
  double _channelToFrequency(int channel) {
    if (channel >= 1 && channel <= 14) {
      // 2.4 GHz
      return 2412 + (channel - 1) * 5 - (channel == 14 ? 7 : 0);
    } else if (channel >= 36 && channel <= 165) {
      // 5 GHz
      return 5000 + channel * 5;
    }
    return 0;
  }
  
  /// تحويل رقم القناة إلى النطاق
  String _channelToBand(int channel) {
    if (channel >= 1 && channel <= 14) return '2.4GHz';
    if (channel >= 36) return '5GHz';
    return 'Unknown';
  }
}

class WifiChannelInfo {
  final int channel;
  final double frequency;
  final String band;
  int networksCount;
  int totalSignal;
  List<NetworkSignal> networks;
  CongestionLevel? congestionLevel;
  int? averageSignal;
  int? interference;
  
  WifiChannelInfo({
    required this.channel,
    required this.frequency,
    required this.band,
    required this.networksCount,
    required this.totalSignal,
    required this.networks,
    this.congestionLevel,
    this.averageSignal,
    this.interference,
  });
  
  String get congestionText {
    switch (congestionLevel) {
      case CongestionLevel.empty: return 'فارغة';
      case CongestionLevel.low: return 'منخفض';
      case CongestionLevel.medium: return 'متوسط';
      case CongestionLevel.high: return 'عالي';
      case CongestionLevel.critical: return 'حرج';
      default: return 'Unknown';
    }
  }
  
  String get congestionColor {
    switch (congestionLevel) {
      case CongestionLevel.empty: return '#10B981';
      case CongestionLevel.low: return '#10B981';
      case CongestionLevel.medium: return '#F59E0B';
      case CongestionLevel.high: return '#EF4444';
      case CongestionLevel.critical: return '#DC2626';
      default: return '#606060';
    }
  }
}

class NetworkSignal {
  String ssid;
  String bssid;
  final int signal;
  final int channel;
  
  NetworkSignal({
    required this.ssid,
    required this.bssid,
    required this.signal,
    required this.channel,
  });
}

enum CongestionLevel { empty, low, medium, high, critical }

class WifiChannelsAnalysis {
  final List<WifiChannelInfo> channels;
  final List<String> recommendations;
  final WifiChannelInfo? bestChannel24Ghz;
  final WifiChannelInfo? bestChannel5Ghz;
  final DateTime timestamp;
  final String? error;
  
  WifiChannelsAnalysis({
    required this.channels,
    required this.recommendations,
    this.bestChannel24Ghz,
    this.bestChannel5Ghz,
    required this.timestamp,
    this.error,
  });
}
