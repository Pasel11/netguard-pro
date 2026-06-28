import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _loading = false;
  Map<String, dynamic>? _report;

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final scanResults = {
        'networkInfo': prefs.getString('netguard-network'),
        'portScan': prefs.getString('netguard-ports'),
        'passwordAnalysis': prefs.getString('netguard-password'),
        'cveResults': prefs.getString('netguard-cve'),
        'routerInfo': prefs.getString('netguard-router'),
        'wpsResults': prefs.getString('netguard-wps'),
      };
      final result = await ApiService.generateReport(scanResults);
      setState(() => _report = result);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.t('report.title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(loc.t('report.subtitle'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.assessment),
              label: Text(loc.t('report.generate')),
            ),
          ),
          const SizedBox(height: 16),
          if (_report != null) _buildReport(loc),
        ],
      ),
    );
  }

  Widget _buildReport(AppLocalizations loc) {
    final summary = _report!['summary'] as Map<String, dynamic>;
    final finalScore = summary['finalScore'] as int? ?? 0;
    final grade = summary['overallGrade'] as String? ?? '—';
    final scoreColor = AppTheme.getScoreColor(finalScore);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(loc.t('report.final_score')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: scoreColor)),
                      child: Text('Grade: $grade', style: TextStyle(color: scoreColor, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('$finalScore', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: scoreColor)),
                    const Text('/100', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: finalScore / 100, color: scoreColor, backgroundColor: AppTheme.surfaceVariant),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _statCard(loc.t('report.total_vulns'), summary['totalVulnerabilities'] ?? 0, AppTheme.error)),
            const SizedBox(width: 8),
            Expanded(child: _statCard(loc.t('report.open_ports'), summary['openPortsCount'] ?? 0, AppTheme.primary)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: AppTheme.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.t('report.conclusion'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_report!['conclusion'] ?? '', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, int value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(label.contains('Vuln') ? Icons.warning : Icons.shield, color: color, size: 20),
            const SizedBox(height: 4),
            Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
