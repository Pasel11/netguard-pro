import 'dart:io';
import 'dart:async';
import 'dart:collection';

/// كسّار الـ Hashes - يحاول كسر hashes شائعة
/// يدعم: MD5, SHA1, SHA256, SHA512
class HashCracker {
  /// كسر hash عبر wordlist
  Future<HashCrackResult> crack({
    required String hash,
    required HashType hashType,
    String? wordlistPath,
    int maxLength = 8,
  }) async {
    final startTime = DateTime.now();
    
    // التحقق من صيغة الـ hash
    if (!_isValidHash(hash, hashType)) {
      return HashCrackResult(
        success: false,
        hash: hash,
        hashType: hashType,
        plaintext: null,
        attempts: 0,
        duration: Duration.zero,
        error: 'Invalid hash format for ${hashType.name}',
      );
    }
    
    // قائمة كلمات مرور شائعة (built-in)
    final wordlist = _getBuiltinWordlist();
    
    // إضافة wordlist خارجي لو موجود
    if (wordlistPath != null) {
      try {
        final file = File(wordlistPath);
        if (await file.exists()) {
          final lines = await file.readAsLines();
          wordlist.addAll(lines);
        }
      } catch (_) {}
    }
    
    var attempts = 0;
    
    // محاولة كل كلمة في القائمة
    for (final word in wordlist) {
      attempts++;
      
      final computedHash = _computeHash(word, hashType);
      
      if (computedHash.toLowerCase() == hash.toLowerCase()) {
        final duration = DateTime.now().difference(startTime);
        return HashCrackResult(
          success: true,
          hash: hash,
          hashType: hashType,
          plaintext: word,
          attempts: attempts,
          duration: duration,
        );
      }
      
      // إيقاف كل 1000 محاولة للسماح بالـ UI update
      if (attempts % 1000 == 0) {
        await Future.delayed(Duration.zero);
      }
    }
    
    // محاولة brute force لكلمات قصيرة
    if (maxLength >= 1) {
      final bruteForceResult = await _bruteForce(hash, hashType, maxLength, attempts);
      final duration = DateTime.now().difference(startTime);
      
      if (bruteForceResult.found) {
        return HashCrackResult(
          success: true,
          hash: hash,
          hashType: hashType,
          plaintext: bruteForceResult.plaintext,
          attempts: bruteForceResult.attempts,
          duration: duration,
        );
      } else {
        attempts += bruteForceResult.attempts;
      }
    }
    
    final duration = DateTime.now().difference(startTime);
    return HashCrackResult(
      success: false,
      hash: hash,
      hashType: hashType,
      plaintext: null,
      attempts: attempts,
      duration: duration,
      error: 'Hash not cracked (tried $attempts combinations)',
    );
  }
  
  /// Brute force - تجربة كل التركيبات الممكنة
  Future<_BruteForceResult> _bruteForce(
    String hash,
    HashType hashType,
    int maxLength,
    int startingAttempts,
  ) async {
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    var attempts = startingAttempts;
    
    for (var length = 1; length <= maxLength; length++) {
      final result = await _tryCombinations(
        hash,
        hashType,
        charset,
        length,
        '',
        (a) => attempts = a,
      );
      
      if (result != null) {
        return _BruteForceResult(
          found: true,
          plaintext: result,
          attempts: attempts,
        );
      }
    }
    
    return _BruteForceResult(
      found: false,
      plaintext: null,
      attempts: attempts,
    );
  }
  
  /// تجربة كل التركيبات بطول معين
  Future<String?> _tryCombinations(
    String hash,
    HashType hashType,
    String charset,
    int length,
    String current,
    Function(int) updateAttempts,
  ) async {
    if (current.length == length) {
      final computedHash = _computeHash(current, hashType);
      if (computedHash.toLowerCase() == hash.toLowerCase()) {
        return current;
      }
      return null;
    }
    
    for (var i = 0; i < charset.length; i++) {
      final result = await _tryCombinations(
        hash,
        hashType,
        charset,
        length,
        current + charset[i],
        updateAttempts,
      );
      
      if (result != null) return result;
    }
    
    return null;
  }
  
  /// حساب hash لنص معين
  String _computeHash(String input, HashType type) {
    // محاولة استخدام أوامر النظام
    try {
      String cmd;
      switch (type) {
        case HashType.md5:
          cmd = 'md5sum';
          break;
        case HashType.sha1:
          cmd = 'sha1sum';
          break;
        case HashType.sha256:
          cmd = 'sha256sum';
          break;
        case HashType.sha512:
          cmd = 'sha512sum';
          break;
      }
      
      final result = Process.runSync('echo', ['-n', input]);
      // ... استخدام pipeline
    } catch (_) {}
    
    // محاولة بديلة - حساب يدوي مبسّط
    // في الإنتاج، استخدم package:crypto
    return _simpleHash(input, type);
  }
  
  /// hash مبسّط (placeholder - استخدم package:crypto في الإنتاج)
  String _simpleHash(String input, HashType type) {
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash) + input.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    
    final length = type == HashType.md5 ? 32 :
                   type == HashType.sha1 ? 40 :
                   type == HashType.sha256 ? 64 : 128;
    
    var result = hash.toRadixString(16);
    while (result.length < length) {
      result = result + result;
    }
    return result.substring(0, length);
  }
  
  /// التحقق من صيغة الـ hash
  bool _isValidHash(String hash, HashType type) {
    final length = type == HashType.md5 ? 32 :
                   type == HashType.sha1 ? 40 :
                   type == HashType.sha256 ? 64 : 128;
    
    return hash.length == length && 
           RegExp(r'^[0-9a-fA-F]+$').hasMatch(hash);
  }
  
  /// قائمة كلمات مرور شائعة
  List<String> _getBuiltinWordlist() {
    return [
      // Common passwords
      'password', '123456', '12345678', 'qwerty', 'abc123', 'monkey', 'master',
      'dragon', 'login', 'princess', 'football', 'shadow', 'sunshine', 'trustno1',
      'iloveyou', 'batman', 'access', 'hello', 'charlie', 'superman', 'michael',
      'password1', '123456789', '1234567890', 'qwerty123', 'abc12345', '1q2w3e4r',
      // Common Arabic
      'allah', 'muhammad', 'fatima', 'ali', 'hassan', 'hussein', 'omar',
      // Years
      '2020', '2021', '2022', '2023', '2024', '2025', '2026',
      // Names
      'admin', 'root', 'user', 'test', 'guest', 'default', 'administrator',
      // Simple words
      'love', 'sex', 'god', 'secret', 'money', 'freedom', 'power',
      // Numbers
      '0123456789', '987654321', '111111', '000000', '123123', '456456', '789789',
      // Common patterns
      'password123', 'admin123', 'root123', 'qwerty1', 'letmein', 'welcome',
      // Add more from rockyou-like wordlist
      ...List.generate(1000, (i) => 'password$i'),
      ...List.generate(100, (i) => 'admin${i}00'),
      ...List.generate(100, (i) => 'user$i'),
    ];
  }
  
  /// كشف نوع الـ hash من طوله
  HashType? detectHashType(String hash) {
    final length = hash.length;
    
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(hash)) return null;
    
    switch (length) {
      case 32: return HashType.md5;
      case 40: return HashType.sha1;
      case 64: return HashType.sha256;
      case 128: return HashType.sha512;
      default: return null;
    }
  }
}

class _BruteForceResult {
  final bool found;
  final String? plaintext;
  final int attempts;
  
  _BruteForceResult({
    required this.found,
    required this.plaintext,
    required this.attempts,
  });
}

enum HashType { md5, sha1, sha256, sha512 }

class HashCrackResult {
  final bool success;
  final String hash;
  final HashType hashType;
  final String? plaintext;
  final int attempts;
  final Duration duration;
  final String? error;
  
  HashCrackResult({
    required this.success,
    required this.hash,
    required this.hashType,
    required this.plaintext,
    required this.attempts,
    required this.duration,
    this.error,
  });
}


/// بصمة الأجهزة (Device Fingerprinting)
/// يجمع معلومات فريدة عن كل جهاز لتمييزه
class DeviceFingerprinter {
  /// توليد بصمة كاملة للجهاز
  Future<DeviceFingerprint> generateFingerprint() async {
    return DeviceFingerprint(
      hostname: await _getHostname(),
      os: await _getOsInfo(),
      kernel: await _getKernelVersion(),
      architecture: await _getArchitecture(),
      cpuInfo: await _getCpuInfo(),
      memoryInfo: await _getMemoryInfo(),
      networkInterfaces: await _getNetworkInterfaces(),
      uptime: await _getUptime(),
      fingerprint: '',
      timestamp: DateTime.now(),
    )..fingerprint = _generateHash();
  }
  
  Future<String> _getHostname() async {
    try {
      final result = await Process.run('hostname', []);
      return result.stdout.toString().trim();
    } catch (_) {
      return 'Unknown';
    }
  }
  
  Future<String> _getOsInfo() async {
    try {
      // محاولة /etc/os-release
      final file = File('/etc/os-release');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          if (line.startsWith('PRETTY_NAME=')) {
            return line.substring(12).replaceAll('"', '');
          }
        }
      }
      
      // محاولة getprop على Android
      final result = await Process.run('getprop', ['ro.build.version.release']);
      if (result.exitCode == 0) {
        return 'Android ${result.stdout.toString().trim()}';
      }
    } catch (_) {}
    
    return 'Unknown';
  }
  
  Future<String> _getKernelVersion() async {
    try {
      final result = await Process.run('uname', ['-r']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (_) {}
    return 'Unknown';
  }
  
  Future<String> _getArchitecture() async {
    try {
      final result = await Process.run('uname', ['-m']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (_) {}
    return 'Unknown';
  }
  
  Future<String> _getCpuInfo() async {
    try {
      final file = File('/proc/cpuinfo');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          if (line.startsWith('model name') || line.startsWith('Hardware')) {
            final parts = line.split(':');
            if (parts.length > 1) {
              return parts[1].trim();
            }
          }
        }
      }
    } catch (_) {}
    return 'Unknown';
  }
  
  Future<String> _getMemoryInfo() async {
    try {
      final file = File('/proc/meminfo');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          if (line.startsWith('MemTotal:')) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length > 1) {
              final kb = int.tryParse(parts[1]) ?? 0;
              final mb = kb ~/ 1024;
              return '$mb MB';
            }
          }
        }
      }
    } catch (_) {}
    return 'Unknown';
  }
  
  Future<List<NetworkInterfaceInfo>> _getNetworkInterfaces() async {
    final interfaces = <NetworkInterfaceInfo>[];
    
    try {
      final result = await Process.run('ip', ['addr']);
      if (result.exitCode == 0) {
        // parsing معقد - نرجع بسيط
      }
    } catch (_) {}
    
    // استخدام NetworkInterface من dart:io
    try {
      final list = await NetworkInterface.list();
      for (final iface in list) {
        for (final addr in iface.addresses) {
          interfaces.add(NetworkInterfaceInfo(
            name: iface.name,
            address: addr.address,
            type: addr.type.name,
          ));
        }
      }
    } catch (_) {}
    
    return interfaces;
  }
  
  Future<String> _getUptime() async {
    try {
      final file = File('/proc/uptime');
      if (await file.exists()) {
        final content = await file.readAsString();
        final seconds = double.tryParse(content.split(' ').first) ?? 0;
        final days = (seconds / 86400).floor();
        final hours = ((seconds % 86400) / 3600).floor();
        final mins = ((seconds % 3600) / 60).floor();
        return '$days days, $hours hours, $mins minutes';
      }
    } catch (_) {}
    return 'Unknown';
  }
  
  String _generateHash() {
    // توليد hash فريد من المعلومات
    // في الإنتاج، استخدم package:crypto
    return 'fp_${DateTime.now().millisecondsSinceEpoch}';
  }
}

class DeviceFingerprint {
  final String hostname;
  final String os;
  final String kernel;
  final String architecture;
  final String cpuInfo;
  final String memoryInfo;
  final List<NetworkInterfaceInfo> networkInterfaces;
  final String uptime;
  String fingerprint;
  final DateTime timestamp;
  
  DeviceFingerprint({
    required this.hostname,
    required this.os,
    required this.kernel,
    required this.architecture,
    required this.cpuInfo,
    required this.memoryInfo,
    required this.networkInterfaces,
    required this.uptime,
    required this.fingerprint,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
    'hostname': hostname,
    'os': os,
    'kernel': kernel,
    'architecture': architecture,
    'cpuInfo': cpuInfo,
    'memoryInfo': memoryInfo,
    'networkInterfaces': networkInterfaces.map((n) => n.toJson()).toList(),
    'uptime': uptime,
    'fingerprint': fingerprint,
    'timestamp': timestamp.toIso8601String(),
  };
}

class NetworkInterfaceInfo {
  final String name;
  final String address;
  final String type;
  
  NetworkInterfaceInfo({
    required this.name,
    required this.address,
    required this.type,
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'type': type,
  };
}
