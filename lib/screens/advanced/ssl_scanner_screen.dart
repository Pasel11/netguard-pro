import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/local/ssl_scanner.dart';
import '../providers/history_provider.dart';
import '../utils/theme.dart';

class SslScannerScreen extends StatefulWidget {
  const SslScannerScreen({super.key});

  @override
  State<SslScannerScreen> createState() => _SslScannerScreenState();
}

class _SslScannerScreenState extends State<SslScannerScreen> {
  final _hostController = TextEditingController(text: 'google.com');
  final _portController = TextEditingController(text: '443');
  bool _loading = false;
  SslScanResult? _result;
  CertificateInfo? _certInfo;
  String? _error;

  Future<void> _scan() async {
    if (_hostController.text.isEmpty) return;
    
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _certInfo = null;
    });

    try {
      final port = int.tryParse(_portController.text) ?? 443;
      
      // فحص SSL بشكل متوازي
      final results = await Future.wait([
        SslScanner.scan(_hostController.text, port: port),
        SslScanner.getCertificateInfo(_hostController.text, port: port),
      ]);
      
      setState(() {
        _result = results[0] as SslScanResult;
        _certInfo = results[1] as CertificateInfo?;
        _loading = false;
      });

      // حفظ في السجل
      if (mounted && _result != null) {
        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        historyProvider.addScan(ScanHistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'ssl',
          title: 'SSL/TLS Scan',
          target: '${_hostController.text}:${_portController.text}',
          score: _result!.securityScore,
          data: {'issues': _result!.issues.length},
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.https, size: 28, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SSL/TLS Scanner',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Certificate & security headers analysis',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Input
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host',
                    hintText: 'example.com',
                    prefixIcon: Icon(Icons.language),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Quick hosts
          Wrap(
            spacing: 8,
            children: ['google.com', 'github.com', 'cloudflare.com', 'apple.com'].map((host) {
              return ActionChip(
                label: Text(host),
                onPressed: () {
                  _hostController.text = host;
                  _portController.text = '443';
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Scan Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _scan,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.security),
              label: Text(_loading ? 'Scanning...' : 'Scan SSL/TLS'),
            ),
          ),
          const SizedBox(height: 24),
          
          // Error
          if (_error != null)
            Card(
              color: AppTheme.error.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $_error',
                  style: const TextStyle(color: AppTheme.error, fontSize: 12)),
              ),
            ),
          
          // Results
          if (_result != null) ...[
            // Security Score
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        const Text('SSL/TLS Security Score',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.getScoreColor(_result!.securityScore).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.getScoreColor(_result!.securityScore)),
                          ),
                          child: Text(
                            '${_result!.securityScore}/100',
                            style: TextStyle(
                              color: AppTheme.getScoreColor(_result!.securityScore),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _result!.securityScore / 100,
                      color: AppTheme.getScoreColor(_result!.securityScore),
                      backgroundColor: AppTheme.surfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Certificate Info
            if (_certInfo != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.badge, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('Certificate Information',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _certRow('Subject', _formatCertField(_certInfo!.subject)),
                      _certRow('Issuer', _formatCertField(_certInfo!.issuer)),
                      _certRow('Valid From', _certInfo!.startValidity.toString()),
                      _certRow('Valid Until', _certInfo!.endValidity.toString()),
                      _certRow('Days Until Expiry', '${_certInfo!.daysUntilExpiry} days'),
                      _certRow('Status', _certInfo!.isValid ? 'Valid ✅' : 'Invalid ❌',
                        valueColor: _certInfo!.isValid ? AppTheme.primary : AppTheme.error),
                      _certRow('SHA-256 Fingerprint', _certInfo!.sha256.toString()),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            
            // Issues & Recommendations
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.list, color: AppTheme.primary),
                        SizedBox(width: 8),
                        Text('Findings',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...(_result!.issues.map((issue) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getIssueIcon(issue), style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(issue, style: const TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    )).toList())),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Recommendations
            if (_result!.recommendations.isNotEmpty)
              Card(
                color: AppTheme.primary.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('Recommendations',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...(_result!.recommendations.map((rec) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: AppTheme.primary)),
                            Expanded(
                              child: Text(rec, style: const TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      )).toList())),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
  
  Widget _certRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: valueColor ?? AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatCertField(String field) {
    // تنسيق /C=US/ST=California/O=Google LLC/CN=*.google.com
    return field
        .split('/')
        .where((s) => s.isNotEmpty)
        .join('\n');
  }
  
  String _getIssueIcon(String issue) {
    if (issue.startsWith('✅')) return '✅';
    if (issue.startsWith('🟡')) return '🟡';
    if (issue.startsWith('🔴')) return '🔴';
    if (issue.startsWith('ℹ️')) return 'ℹ️';
    return '•';
  }
}
