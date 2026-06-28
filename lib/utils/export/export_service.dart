import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/local/port_scanner.dart';
import '../services/local/network_discovery.dart';
import '../services/local/dns_service.dart';
import '../services/local/ping_service.dart';
import '../services/local/ssl_scanner.dart';

/// خدمة تصدير التقارير بصيغ متعددة
class ExportService {
  /// تصدير كـ JSON
  static Future<String> exportJson(ScanReport report) async {
    final json = _encodeJson(report.toJson());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/netguard_report_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    return file.path;
  }
  
  /// تصدير كـ CSV
  static Future<String> exportCsv(ScanReport report) async {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Category,Item,Value,Status,Risk Level');
    
    // Network Info
    if (report.networkInfo != null) {
      buffer.writeln('Network,Public IP,${report.networkInfo!.publicIp},Info,-');
      buffer.writeln('Network,ISP,${report.networkInfo!.ipInfo?.isp ?? "Unknown"},Info,-');
      buffer.writeln('Network,Country,${report.networkInfo!.ipInfo?.country ?? "Unknown"},Info,-');
    }
    
    // Port Scan Results
    if (report.portScan != null) {
      for (final port in report.portScan!.openPorts) {
        buffer.writeln('Port,${port.port},${port.service},Open,${_portRiskLevel(port.port)}');
      }
      buffer.writeln('Port Scan,Security Score,${report.portScan!.securityScore}/100,Score,-');
    }
    
    // Password Analysis
    if (report.passwordAnalysis != null) {
      buffer.writeln('Password,Score,${report.passwordAnalysis!.score}/100,${report.passwordAnalysis!.strength},-');
      buffer.writeln('Password,Length,${report.passwordAnalysis!.length},Info,-');
      buffer.writeln('Password,Entropy,${report.passwordAnalysis!.entropy} bits,Info,-');
      buffer.writeln('Password,Online Crack,${report.passwordAnalysis!.crackTime['online']},Info,-');
      buffer.writeln('Password,Offline Crack,${report.passwordAnalysis!.crackTime['offline']},Info,-');
    }
    
    // CVE Results
    if (report.cveResults != null) {
      for (final cve in report.cveResults!) {
        buffer.writeln('CVE,${cve.id},${cve.title},${cve.severity},${cve.cvss}');
      }
    }
    
    // Router Info
    if (report.routerInfo != null) {
      buffer.writeln('Router,Vendor,${report.routerInfo!.vendor ?? "Unknown"},Info,-');
      buffer.writeln('Router,Model,${report.routerInfo!.model ?? "Unknown"},Info,-');
      buffer.writeln('Router,Firmware,${report.routerInfo!.firmware ?? "Unknown"},Info,-');
    }
    
    // WPS Results
    if (report.wpsResults != null) {
      buffer.writeln('WPS,Vendor,${report.wpsResults!.detectedVendor},Info,-');
      if (report.wpsResults!.matchingAlgorithm != null) {
        buffer.writeln('WPS,PIN,${report.wpsResults!.matchingAlgorithm!.pin},${report.wpsResults!.matchingAlgorithm!.vulnerabilityLevel},High');
      }
    }
    
    // Devices
    if (report.discoveredDevices != null) {
      for (final device in report.discoveredDevices!) {
        buffer.writeln('Device,${device.ip},${device.vendor},${device.status},-');
      }
    }
    
    // SSL
    if (report.sslScan != null) {
      buffer.writeln('SSL,Score,${report.sslScan!.securityScore}/100,Score,-');
    }
    
    // DNS
    if (report.dnsLookup != null) {
      buffer.writeln('DNS,A Records,${report.dnsLookup!.aRecords.join("; ")},Info,-');
      buffer.writeln('DNS,Security Score,${report.dnsLookup!.securityAnalysis.securityScore}/100,Score,-');
    }
    
    // Save
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/netguard_report_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());
    return file.path;
  }
  
  /// تصدير PDF احترافي
  static Future<String> exportPdf(ScanReport report) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('NetGuard Pro', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                pw.Text('Security Audit Report', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              ],
            ),
            pw.Divider(color: PdfColors.green700, thickness: 2),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          // Executive Summary
          pw.Header(level: 1, text: 'Executive Summary'),
          pw.Paragraph(
            text: 'Generated: ${DateTime.now().toIso8601String()}',
          ),
          pw.Paragraph(
            text: 'Overall Security Score: ${report.overallScore}/100 (${report.riskLevel.toUpperCase()})',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _scoreColor(report.overallScore)),
          ),
          pw.SizedBox(height: 20),
          
          // Network Info
          if (report.networkInfo != null) ...[
            pw.Header(level: 1, text: 'Network Information'),
            pw.Table.fromTextArray(
              context: context,
              data: [
                ['Property', 'Value'],
                ['Public IP', report.networkInfo!.publicIp],
                ['ISP', report.networkInfo!.ipInfo?.isp ?? 'Unknown'],
                ['Country', report.networkInfo!.ipInfo?.country ?? 'Unknown'],
                ['City', report.networkInfo!.ipInfo?.city ?? 'Unknown'],
                ['ASN', report.networkInfo!.ipInfo?.asn ?? 'Unknown'],
              ],
              headerStyle: pw.TextStyle(bold: true, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(6),
            ),
            pw.SizedBox(height: 20),
          ],
          
          // Port Scan Results
          if (report.portScan != null) ...[
            pw.Header(level: 1, text: 'Port Scan Results'),
            pw.Paragraph(text: 'Target: ${report.portScan!.host}'),
            pw.Paragraph(text: 'Open Ports: ${report.portScan!.openPortsCount} / ${report.portScan!.totalPorts}'),
            pw.Paragraph(text: 'Security Score: ${report.portScan!.securityScore}/100'),
            if (report.portScan!.openPorts.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                context: context,
                data: [
                  ['Port', 'Service', 'Response Time', 'Banner'],
                  ...report.portScan!.openPorts.map((p) => [
                    p.port.toString(),
                    p.service,
                    p.responseTime != null ? '${p.responseTime}ms' : '-',
                    p.banner ?? '-',
                  ]),
                ],
                headerStyle: pw.TextStyle(bold: true, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
              ),
            ],
            pw.SizedBox(height: 20),
          ],
          
          // Password Analysis
          if (report.passwordAnalysis != null) ...[
            pw.Header(level: 1, text: 'Password Analysis'),
            pw.Table.fromTextArray(
              context: context,
              data: [
                ['Property', 'Value'],
                ['Score', '${report.passwordAnalysis!.score}/100'],
                ['Strength', report.passwordAnalysis!.strength],
                ['Length', report.passwordAnalysis!.length.toString()],
                ['Entropy', '${report.passwordAnalysis!.entropy} bits'],
                ['Online Crack Time', report.passwordAnalysis!.crackTime['online'] ?? 'Unknown'],
                ['Offline Crack Time (GPU)', report.passwordAnalysis!.crackTime['offline'] ?? 'Unknown'],
                ['WPA Compatibility', report.passwordAnalysis!.wpaRecommendation],
              ],
              headerStyle: pw.TextStyle(bold: true, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
            ),
            pw.SizedBox(height: 20),
          ],
          
          // Vulnerabilities (CVE)
          if (report.cveResults != null && report.cveResults!.isNotEmpty) ...[
            pw.Header(level: 1, text: 'Known Vulnerabilities (CVE)'),
            pw.Table.fromTextArray(
              context: context,
              data: [
                ['CVE ID', 'Severity', 'CVSS', 'Title'],
                ...report.cveResults!.map((cve) => [
                  cve.id,
                  cve.severity.toUpperCase(),
                  cve.cvss.toString(),
                  cve.title,
                ]),
              ],
              headerStyle: pw.TextStyle(bold: true, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
            ),
            pw.SizedBox(height: 20),
          ],
          
          // Router Info
          if (report.routerInfo != null) ...[
            pw.Header(level: 1, text: 'Router Information'),
            pw.Table.fromTextArray(
              context: context,
              data: [
                ['Property', 'Value'],
                ['IP', report.routerInfo!.ip],
                ['Vendor', report.routerInfo!.vendor ?? 'Unknown'],
                ['Model', report.routerInfo!.model ?? 'Unknown'],
                ['Firmware', report.routerInfo!.firmware ?? 'Unknown'],
              ],
              headerStyle: pw.TextStyle(bold: true, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
            ),
            pw.SizedBox(height: 20),
          ],
          
          // WPS Analysis
          if (report.wpsResults != null && report.wpsResults!.matchingAlgorithm != null) ...[
            pw.Header(level: 1, text: 'WPS PIN Analysis'),
            pw.Table.fromTextArray(
              context: context,
              data: [
                ['Property', 'Value'],
                ['Detected Vendor', report.wpsResults!.detectedVendor],
                ['Algorithm', report.wpsResults!.matchingAlgorithm!.algorithm],
                ['Calculated PIN', report.wpsResults!.matchingAlgorithm!.pin],
                ['Vulnerability', report.wpsResults!.matchingAlgorithm!.vulnerabilityLevel],
                ['Exploit Time', report.wpsResults!.matchingAlgorithm!.exploitTime],
              ],
              headerStyle: pw.TextStyle(bold: true, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
            ),
            pw.SizedBox(height: 20),
          ],
          
          // Discovered Devices
          if (report.discoveredDevices != null && report.discoveredDevices!.isNotEmpty) ...[
            pw.Header(level: 1, text: 'Discovered Devices'),
            pw.Table.fromTextArray(
              context: context,
              data: [
                ['IP', 'MAC', 'Vendor', 'Type'],
                ...report.discoveredDevices!.map((d) => [
                  d.ip,
                  d.mac,
                  d.vendor,
                  d.type,
                ]),
              ],
              headerStyle: pw.TextStyle(bold: true, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
            ),
            pw.SizedBox(height: 20),
          ],
          
          // SSL/TLS Scan
          if (report.sslScan != null) ...[
            pw.Header(level: 1, text: 'SSL/TLS Scan'),
            pw.Paragraph(text: 'Host: ${report.sslScan!.host}:${report.sslScan!.port}'),
            pw.Paragraph(text: 'Security Score: ${report.sslScan!.securityScore}/100'),
            if (report.sslScan!.issues.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Header(level: 2, text: 'Issues'),
              ...report.sslScan!.issues.map((issue) => pw.Paragraph(text: '• $issue')),
            ],
            pw.SizedBox(height: 20),
          ],
          
          // Recommendations
          if (report.recommendations.isNotEmpty) ...[
            pw.Header(level: 1, text: 'Recommendations'),
            ...report.recommendations.asMap().entries.map((entry) => pw.Paragraph(
              text: '${entry.key + 1}. ${entry.value}',
            )),
            pw.SizedBox(height: 20),
          ],
          
          // Conclusion
          pw.Header(level: 1, text: 'Conclusion'),
          pw.Paragraph(
            text: report.conclusion,
            style: const pw.TextStyle(fontSize: 12),
          ),
          
          // Footer
          pw.SizedBox(height: 40),
          pw.Divider(),
          pw.Center(
            child: pw.Text(
              'Generated by NetGuard Pro v3.0 | ${DateTime.now().toString()}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          ),
        ],
      ),
    );
    
    // Save file
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/netguard_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    
    return filePath;
  }
  
  /// مشاركة الملف
  static Future<void> shareFile(String filePath, {String? subject}) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: subject ?? 'NetGuard Pro Security Report',
      text: 'Security audit report from NetGuard Pro',
    );
  }
  
  /// تصدير شامل لكل الصيغ
  static Future<ExportResults> exportAll(ScanReport report) async {
    final jsonPath = await exportJson(report);
    final csvPath = await exportCsv(report);
    final pdfPath = await exportPdf(report);
    
    return ExportResults(
      jsonPath: jsonPath,
      csvPath: csvPath,
      pdfPath: pdfPath,
    );
  }
  
  static PdfColor _scoreColor(int score) {
    if (score >= 75) return PdfColors.green700;
    if (score >= 50) return PdfColors.orange700;
    return PdfColors.red700;
  }
  
  static String _portRiskLevel(int port) {
    const dangerous = [23, 21, 161, 389, 1433, 3389, 7547];
    const medium = [445, 139, 80, 8080];
    
    if (dangerous.contains(port)) return 'High';
    if (medium.contains(port)) return 'Medium';
    return 'Low';
  }
  
  static String _encodeJson(Map<String, dynamic> data) {
    // JSON encoding بسيط - في الإنتاج استخدم dart:convert
    final buffer = StringBuffer();
    buffer.write('{');
    
    final entries = data.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.write('"${entry.key}":');
      buffer.write(_encodeValue(entry.value));
      if (i < entries.length - 1) buffer.write(',');
    }
    
    buffer.write('}');
    return buffer.toString();
  }
  
  static String _encodeValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"${value.replaceAll('"', '\\"')}"';
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      return '[${value.map(_encodeValue).join(',')}]';
    }
    if (value is Map) {
      return _encodeJson(Map<String, dynamic>.from(value));
    }
    return 'null';
  }
}

class ScanReport {
  final int overallScore;
  final String riskLevel;
  final String conclusion;
  final List<String> recommendations;
  final NetworkInfo? networkInfo;
  final ScanSummary? portScan;
  final PasswordAnalysis? passwordAnalysis;
  final List<CVE>? cveResults;
  final RouterInfo? routerInfo;
  final WPSResult? wpsResults;
  final List<DiscoveredDevice>? discoveredDevices;
  final SslScanResult? sslScan;
  final DnsLookupResult? dnsLookup;
  final PingResult? pingResult;
  final WifiInfo? wifiInfo;
  
  ScanReport({
    required this.overallScore,
    required this.riskLevel,
    required this.conclusion,
    required this.recommendations,
    this.networkInfo,
    this.portScan,
    this.passwordAnalysis,
    this.cveResults,
    this.routerInfo,
    this.wpsResults,
    this.discoveredDevices,
    this.sslScan,
    this.dnsLookup,
    this.pingResult,
    this.wifiInfo,
  });
  
  Map<String, dynamic> toJson() => {
    'overallScore': overallScore,
    'riskLevel': riskLevel,
    'conclusion': conclusion,
    'recommendations': recommendations,
    'networkInfo': networkInfo?.toString(),
    'portScan': portScan?.toJson(),
    'passwordAnalysis': passwordAnalysis?.toString(),
    'cveResults': cveResults?.map((c) => c.toString()).toList(),
    'routerInfo': routerInfo?.toString(),
    'wpsResults': wpsResults?.toString(),
    'discoveredDevices': discoveredDevices?.map((d) => d.toJson()).toList(),
    'sslScan': sslScan?.toJson(),
    'timestamp': DateTime.now().toIso8601String(),
  };
}

class ExportResults {
  final String jsonPath;
  final String csvPath;
  final String pdfPath;
  
  ExportResults({
    required this.jsonPath,
    required this.csvPath,
    required this.pdfPath,
  });
}
