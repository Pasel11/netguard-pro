import 'package:flutter_test/flutter_test.dart';
import 'package:netguard_pro/models/models.dart';

void main() {
  group('NetworkInfo Model', () {
    test('should parse from JSON correctly', () {
      final json = {
        'publicIp': '8.8.8.8',
        'ipInfo': {
          'city': 'Mountain View',
          'country': 'United States',
          'countryCode': 'US',
          'isp': 'Google LLC',
          'asn': 'AS15169',
          'timezone': 'America/Los_Angeles',
        }
      };
      
      final info = NetworkInfo.fromJson(json);
      
      expect(info.publicIp, '8.8.8.8');
      expect(info.city, 'Mountain View');
      expect(info.country, 'United States');
      expect(info.countryCode, 'US');
      expect(info.isp, 'Google LLC');
      expect(info.asn, 'AS15169');
      expect(info.timezone, 'America/Los_Angeles');
    });
    
    test('should handle null ipInfo', () {
      final json = {
        'publicIp': '1.1.1.1',
        'ipInfo': null,
      };
      
      final info = NetworkInfo.fromJson(json);
      
      expect(info.publicIp, '1.1.1.1');
      expect(info.city, null);
      expect(info.country, null);
    });
    
    test('should handle empty JSON', () {
      final info = NetworkInfo.fromJson({});
      
      expect(info.publicIp, 'Unknown');
      expect(info.city, null);
    });
  });
  
  group('WPSAlgorithm Model', () {
    test('should parse from JSON correctly', () {
      final json = {
        'vendor': 'TP-Link',
        'algorithm': 'Viehböck (2012)',
        'pin': '12345670',
        'vulnerabilityLevel': 'critical',
        'exploitTime': '2-4 hours',
        'description': 'Common vulnerability',
      };
      
      final algo = WPSAlgorithm.fromJson(json);
      
      expect(algo.vendor, 'TP-Link');
      expect(algo.algorithm, 'Viehböck (2012)');
      expect(algo.pin, '12345670');
      expect(algo.vulnerabilityLevel, 'critical');
      expect(algo.exploitTime, '2-4 hours');
    });
    
    test('should handle missing fields', () {
      final algo = WPSAlgorithm.fromJson({});
      
      expect(algo.vendor, '');
      expect(algo.pin, '');
      expect(algo.vulnerabilityLevel, 'low');
    });
  });
  
  group('PasswordAnalysis Model', () {
    test('should parse from JSON correctly', () {
      final json = {
        'password': '********',
        'score': 85,
        'strength': 'strong',
        'length': 12,
        'characterSets': {
          'lowercase': true,
          'uppercase': true,
          'numbers': true,
          'symbols': false,
        },
        'entropy': 75.5,
        'crackTime': {
          'online': '100 years',
          'offline': '1 year',
        },
        'issues': [],
        'suggestions': ['Add symbols'],
        'isCommonPassword': false,
        'wpaRecommendation': 'Strong',
      };
      
      final analysis = PasswordAnalysis.fromJson(json);
      
      expect(analysis.score, 85);
      expect(analysis.strength, 'strong');
      expect(analysis.length, 12);
      expect(analysis.entropy, 75.5);
      expect(analysis.characterSets['lowercase'], true);
      expect(analysis.characterSets['symbols'], false);
      expect(analysis.crackTime['online'], '100 years');
      expect(analysis.isCommonPassword, false);
    });
  });
  
  group('CVE Model', () {
    test('should parse from JSON correctly', () {
      final json = {
        'id': 'CVE-2024-1234',
        'vendor': 'TP-Link',
        'model': 'Archer C7',
        'severity': 'critical',
        'cvss': 9.8,
        'title': 'Command Injection',
        'description': 'RCE vulnerability',
        'affected': 'All versions',
        'solution': 'Update firmware',
        'published': '2024-01-15',
      };
      
      final cve = CVE.fromJson(json);
      
      expect(cve.id, 'CVE-2024-1234');
      expect(cve.vendor, 'TP-Link');
      expect(cve.severity, 'critical');
      expect(cve.cvss, 9.8);
    });
  });
  
  group('PortScanResult Model', () {
    test('should parse from JSON correctly', () {
      final json = {
        'target': '8.8.8.8',
        'scanTime': '2024-01-01T00:00:00Z',
        'totalPorts': 30,
        'openPortsCount': 2,
        'closedPortsCount': 28,
        'openPorts': [
          {'port': 53, 'service': 'DNS', 'isOpen': true, 'responseTime': 10},
          {'port': 443, 'service': 'HTTPS', 'isOpen': true, 'responseTime': 15},
        ],
        'securityScore': 100,
        'risks': [],
        'recommendation': ['All good'],
      };
      
      final result = PortScanResult.fromJson(json);
      
      expect(result.target, '8.8.8.8');
      expect(result.totalPorts, 30);
      expect(result.openPortsCount, 2);
      expect(result.openPorts.length, 2);
      expect(result.openPorts[0].port, 53);
      expect(result.openPorts[0].service, 'DNS');
      expect(result.securityScore, 100);
    });
  });
}
