import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class SignalAnalyzerScreen extends StatefulWidget {
  const SignalAnalyzerScreen({super.key});
  @override
  State<SignalAnalyzerScreen> createState() => _SignalAnalyzerScreenState();
}

class _SignalAnalyzerScreenState extends State<SignalAnalyzerScreen> {
  bool _loading = false;
  Map<String, dynamic>? _analysis;
  String? _error;

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final connectionInfo = {
        'effectiveType': connectivityResult.name,
        'downlink': 10,
        'rtt': 50,
        'saveData': false,
      };
      final result = await ApiService.analyzeWifiSignal(connectionInfo);
      setState(() => _analysis = result);
    } catch (e) {
      setState(() => _error = e.toString());
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
          Text(loc.t('signal.title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(loc.t('signal.subtitle'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi),
              label: Text(loc.t('signal.analyze')),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) Text('Error: $_error', style: const TextStyle(color: AppTheme.error)),
          if (_analysis != null) _buildResult(loc),
        ],
      ),
    );
  }

  Widget _buildResult(AppLocalizations loc) {
    final analysis = _analysis!['analysis'] as Map<String, dynamic>;
    final qualityScore = analysis['qualityScore'] as int? ?? 0;
    final scoreColor = AppTheme.getScoreColor(qualityScore);
    
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
                    Text(loc.t('signal.signal_quality')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: scoreColor)),
                      child: Text(analysis['signalQuality'] ?? '—', style: TextStyle(color: scoreColor, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('$qualityScore', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: scoreColor)),
                    const Text('/100', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: qualityScore / 100, color: scoreColor, backgroundColor: AppTheme.surfaceVariant),
                const SizedBox(height: 8),
                Text(analysis['recommendation'] ?? '', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.t('signal.tips'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...((_analysis!['tips'] as List).map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(tip, style: const TextStyle(fontSize: 11)),
                )).toList()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
