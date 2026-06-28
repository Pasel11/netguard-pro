// نموذج معلومات الشبكة
class NetworkInfo {
  final String publicIp;
  final String? city;
  final String? region;
  final String? country;
  final String? countryCode;
  final String? isp;
  final String? asn;
  final String? timezone;
  final double? latitude;
  final double? longitude;

  NetworkInfo({
    required this.publicIp,
    this.city,
    this.region,
    this.country,
    this.countryCode,
    this.isp,
    this.asn,
    this.timezone,
    this.latitude,
    this.longitude,
  });

  factory NetworkInfo.fromJson(Map<String, dynamic> json) {
    final ipInfo = json['ipInfo'] as Map<String, dynamic>?;
    return NetworkInfo(
      publicIp: json['publicIp'] ?? 'Unknown',
      city: ipInfo?['city'],
      region: ipInfo?['region'],
      country: ipInfo?['country'],
      countryCode: ipInfo?['countryCode'],
      isp: ipInfo?['isp'],
      asn: ipInfo?['asn'],
      timezone: ipInfo?['timezone'],
      latitude: ipInfo?['latitude']?.toDouble(),
      longitude: ipInfo?['longitude']?.toDouble(),
    );
  }
}

// نموذج نتيجة فحص البورتات
class PortScanResult {
  final String target;
  final String scanTime;
  final int totalPorts;
  final int openPortsCount;
  final int closedPortsCount;
  final List<PortResult> openPorts;
  final int securityScore;
  final List<String> risks;
  final List<String> recommendations;

  PortScanResult({
    required this.target,
    required this.scanTime,
    required this.totalPorts,
    required this.openPortsCount,
    required this.closedPortsCount,
    required this.openPorts,
    required this.securityScore,
    required this.risks,
    required this.recommendations,
  });

  factory PortScanResult.fromJson(Map<String, dynamic> json) {
    return PortScanResult(
      target: json['target'] ?? '',
      scanTime: json['scanTime'] ?? '',
      totalPorts: json['totalPorts'] ?? 0,
      openPortsCount: json['openPortsCount'] ?? 0,
      closedPortsCount: json['closedPortsCount'] ?? 0,
      openPorts: (json['openPorts'] as List<dynamic>?)
          ?.map((e) => PortResult.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      securityScore: json['securityScore'] ?? 0,
      risks: List<String>.from(json['risks'] ?? []),
      recommendations: List<String>.from(json['recommendation'] ?? []),
    );
  }
}

class PortResult {
  final int port;
  final String service;
  final bool isOpen;
  final int? responseTime;

  PortResult({
    required this.port,
    required this.service,
    required this.isOpen,
    this.responseTime,
  });

  factory PortResult.fromJson(Map<String, dynamic> json) {
    return PortResult(
      port: json['port'] ?? 0,
      service: json['service'] ?? 'Unknown',
      isOpen: json['isOpen'] ?? false,
      responseTime: json['responseTime'],
    );
  }
}

// نموذج نتيجة WPS PIN
class WPSResult {
  final String macAddress;
  final String oui;
  final String detectedVendor;
  final WPSAlgorithm? matchingAlgorithm;
  final List<WPSAlgorithm> allAlgorithms;
  final List<String> protectionAdvice;
  final String legalNotice;

  WPSResult({
    required this.macAddress,
    required this.oui,
    required this.detectedVendor,
    this.matchingAlgorithm,
    required this.allAlgorithms,
    required this.protectionAdvice,
    required this.legalNotice,
  });

  factory WPSResult.fromJson(Map<String, dynamic> json) {
    return WPSResult(
      macAddress: json['macAddress'] ?? '',
      oui: json['oui'] ?? '',
      detectedVendor: json['detectedVendor'] ?? 'Unknown',
      matchingAlgorithm: json['matchingAlgorithm'] != null
          ? WPSAlgorithm.fromJson(json['matchingAlgorithm'])
          : null,
      allAlgorithms: (json['allAlgorithms'] as List<dynamic>?)
          ?.map((e) => WPSAlgorithm.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      protectionAdvice: List<String>.from(json['protectionAdvice'] ?? []),
      legalNotice: json['legalNotice'] ?? '',
    );
  }
}

class WPSAlgorithm {
  final String vendor;
  final String algorithm;
  final String pin;
  final String vulnerabilityLevel;
  final String exploitTime;
  final String description;

  WPSAlgorithm({
    required this.vendor,
    required this.algorithm,
    required this.pin,
    required this.vulnerabilityLevel,
    required this.exploitTime,
    required this.description,
  });

  factory WPSAlgorithm.fromJson(Map<String, dynamic> json) {
    return WPSAlgorithm(
      vendor: json['vendor'] ?? '',
      algorithm: json['algorithm'] ?? '',
      pin: json['pin'] ?? '',
      vulnerabilityLevel: json['vulnerabilityLevel'] ?? 'low',
      exploitTime: json['exploitTime'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

// نموذج تحليل كلمة المرور
class PasswordAnalysis {
  final String password;
  final int score;
  final String strength;
  final int length;
  final Map<String, bool> characterSets;
  final double entropy;
  final Map<String, String> crackTime;
  final List<String> issues;
  final List<String> suggestions;
  final bool isCommonPassword;
  final String wpaRecommendation;

  PasswordAnalysis({
    required this.password,
    required this.score,
    required this.strength,
    required this.length,
    required this.characterSets,
    required this.entropy,
    required this.crackTime,
    required this.issues,
    required this.suggestions,
    required this.isCommonPassword,
    required this.wpaRecommendation,
  });

  factory PasswordAnalysis.fromJson(Map<String, dynamic> json) {
    return PasswordAnalysis(
      password: json['password'] ?? '',
      score: json['score'] ?? 0,
      strength: json['strength'] ?? 'weak',
      length: json['length'] ?? 0,
      characterSets: Map<String, bool>.from(json['characterSets'] ?? {}),
      entropy: (json['entropy'] ?? 0).toDouble(),
      crackTime: Map<String, String>.from(json['crackTime'] ?? {}),
      issues: List<String>.from(json['issues'] ?? []),
      suggestions: List<String>.from(json['suggestions'] ?? []),
      isCommonPassword: json['isCommonPassword'] ?? false,
      wpaRecommendation: json['wpaRecommendation'] ?? '',
    );
  }
}

// نموذج CVE
class CVE {
  final String id;
  final String vendor;
  final String model;
  final String severity;
  final double cvss;
  final String title;
  final String description;
  final String affected;
  final String solution;
  final String published;

  CVE({
    required this.id,
    required this.vendor,
    required this.model,
    required this.severity,
    required this.cvss,
    required this.title,
    required this.description,
    required this.affected,
    required this.solution,
    required this.published,
  });

  factory CVE.fromJson(Map<String, dynamic> json) {
    return CVE(
      id: json['id'] ?? '',
      vendor: json['vendor'] ?? '',
      model: json['model'] ?? '',
      severity: json['severity'] ?? 'low',
      cvss: (json['cvss'] ?? 0).toDouble(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      affected: json['affected'] ?? '',
      solution: json['solution'] ?? '',
      published: json['published'] ?? '',
    );
  }
}

// نموذج معلومات الراوتر
class RouterInfo {
  final String ip;
  final bool detected;
  final String? vendor;
  final String? model;
  final String? firmware;
  final int? httpStatus;
  final Map<String, String?> securityHeaders;
  final List<String> risks;
  final String? connectionError;

  RouterInfo({
    required this.ip,
    required this.detected,
    this.vendor,
    this.model,
    this.firmware,
    this.httpStatus,
    required this.securityHeaders,
    required this.risks,
    this.connectionError,
  });

  factory RouterInfo.fromJson(Map<String, dynamic> json) {
    return RouterInfo(
      ip: json['ip'] ?? '',
      detected: json['detected'] ?? false,
      vendor: json['vendor'],
      model: json['model'],
      firmware: json['firmware'],
      httpStatus: json['httpStatus'],
      securityHeaders: Map<String, String?>.from(json['securityHeaders'] ?? {}),
      risks: List<String>.from(json['risks'] ?? []),
      connectionError: json['connectionError'],
    );
  }
}
