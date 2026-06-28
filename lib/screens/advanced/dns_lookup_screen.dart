import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:netguard_pro/l10n/app_localizations.dart';
import 'package:netguard_pro/services/local/dns_service.dart';
import 'package:netguard_pro/providers/history_provider.dart';
import 'package:netguard_pro/utils/theme.dart';

class DnsLookupScreen extends StatefulWidget {
  const DnsLookupScreen({super.key});

  @override
  State<DnsLookupScreen> createState() => _DnsLookupScreenState();
}

class _DnsLookupScreenState extends State<DnsLookupScreen> {
  final _domainController = TextEditingController(text: 'google.com');
  bool _loading = false;
  DnsLookupResult? _result;
  String? _error;

  Future<void> _lookup() async {
    if (_domainController.text.isEmpty) return;
    
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await DnsService.fullLookup(_domainController.text);
      setState(() {
        _result = result;
        _loading = false;
      });

      // حفظ في السجل
      if (mounted) {
        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        historyProvider.addScan(ScanHistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'dns',
          title: 'DNS Lookup',
          target: _domainController.text,
          score: result.securityAnalysis.securityScore,
          data: {'aRecords': result.aRecords.length},
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
              const Icon(Icons.dns, size: 28, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DNS Lookup',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Complete DNS records lookup & analysis',
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
                child: TextField(
                  controller: _domainController,
                  decoration: const InputDecoration(
                    labelText: 'Domain Name',
                    hintText: 'example.com',
                    prefixIcon: Icon(Icons.language),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loading ? null : _lookup,
                child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Lookup'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Quick domains
          Wrap(
            spacing: 8,
            children: ['google.com', 'github.com', 'cloudflare.com', 'apple.com'].map((domain) {
              return ActionChip(
                label: Text(domain),
                onPressed: () {
                  _domainController.text = domain;
                  _lookup();
                },
              );
            }).toList(),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        const Text('DNS Security Score',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.getScoreColor(_result!.securityAnalysis.securityScore).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.getScoreColor(_result!.securityAnalysis.securityScore)),
                          ),
                          child: Text(
                            '${_result!.securityAnalysis.securityScore}/100',
                            style: TextStyle(
                              color: AppTheme.getScoreColor(_result!.securityAnalysis.securityScore),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // A Records
            if (_result!.aRecords.isNotEmpty) _buildRecordCard(
              'A Records (IPv4)',
              Icons.public,
              _result!.aRecords.map((ip) => {'type': 'A', 'value': ip}).toList(),
            ),
            
            // AAAA Records
            if (_result!.aaaaRecords.isNotEmpty) _buildRecordCard(
              'AAAA Records (IPv6)',
              Icons.public,
              _result!.aaaaRecords.map((ip) => {'type': 'AAAA', 'value': ip}).toList(),
            ),
            
            // MX Records
            if (_result!.mxRecords.isNotEmpty) _buildRecordCard(
              'MX Records (Mail)',
              Icons.email,
              _result!.mxRecords.map((r) => {'type': 'MX', 'value': r.toString()}).toList(),
            ),
            
            // NS Records
            if (_result!.nsRecords.isNotEmpty) _buildRecordCard(
              'NS Records (Nameservers)',
              Icons.dns,
              _result!.nsRecords.map((r) => {'type': 'NS', 'value': r.toString()}).toList(),
            ),
            
            // TXT Records
            if (_result!.txtRecords.isNotEmpty) _buildRecordCard(
              'TXT Records',
              Icons.text_snippet,
              _result!.txtRecords.map((r) => {'type': 'TXT', 'value': r.toString()}).toList(),
            ),
            
            // CNAME Records
            if (_result!.cnameRecords.isNotEmpty) _buildRecordCard(
              'CNAME Records',
              Icons.link,
              _result!.cnameRecords.map((r) => {'type': 'CNAME', 'value': r.toString()}).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Security Analysis
            if (_result!.securityAnalysis.issues.isNotEmpty || 
                _result!.securityAnalysis.foundRecords.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('Security Analysis',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Found Records
                      if (_result!.securityAnalysis.foundRecords.isNotEmpty) ...[
                        const Text('Found:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 4),
                        ...(_result!.securityAnalysis.foundRecords.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4, right: 8),
                          child: Text(r, style: const TextStyle(fontSize: 11)),
                        )).toList()),
                      ],
                      
                      // Issues
                      if (_result!.securityAnalysis.issues.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Issues:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 4),
                        ...(_result!.securityAnalysis.issues.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4, right: 8),
                          child: Text(r, style: const TextStyle(fontSize: 11)),
                        )).toList()),
                      ],
                      
                      // Recommendations
                      if (_result!.securityAnalysis.recommendations.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Recommendations:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 4),
                        ...(_result!.securityAnalysis.recommendations.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4, right: 8),
                          child: Text(r, style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
                        )).toList()),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildRecordCard(String title, IconData icon, List<Map<String, String>> records) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title),
        subtitle: Text('${records.length} records', style: const TextStyle(fontSize: 11)),
        children: records.map((r) => ListTile(
          dense: true,
          title: Text(r['value']!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          trailing: Text(r['type']!, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        )).toList(),
      ),
    );
  }
}
