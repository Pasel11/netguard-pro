import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class PasswordAnalyzerScreen extends StatefulWidget {
  const PasswordAnalyzerScreen({super.key});
  @override
  State<PasswordAnalyzerScreen> createState() => _PasswordAnalyzerScreenState();
}

class _PasswordAnalyzerScreenState extends State<PasswordAnalyzerScreen> {
  final _pwdController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  PasswordAnalysis? _analysis;

  Future<void> _analyze() async {
    if (_pwdController.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final result = await ApiService.analyzePassword(_pwdController.text);
      setState(() => _analysis = result);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final pwd = List.generate(20, (i) => chars[(DateTime.now().microsecondsSinceEpoch + i * 7) % chars.length]).join();
    _pwdController.text = pwd;
    setState(() => _analysis = null);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.t('password.title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _pwdController,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: loc.t('password.title'),
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _analyze,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.analytics),
                  label: Text(loc.t('password.analyze')),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _generatePassword,
                icon: const Icon(Icons.auto_awesome),
                label: Text(loc.t('password.generate_strong'), style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_analysis != null) _buildResult(loc),
        ],
      ),
    );
  }

  Widget _buildResult(AppLocalizations loc) {
    final a = _analysis!;
    final scoreColor = AppTheme.getScoreColor(a.score);
    final strengthLabel = {
      'very_weak': loc.t('password.very_weak'),
      'weak': loc.t('password.weak'),
      'fair': loc.t('password.fair'),
      'strong': loc.t('password.strong'),
      'very_strong': loc.t('password.very_strong'),
    }[a.strength] ?? a.strength;

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
                    Text(loc.t('password.strength_score')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: scoreColor)),
                      child: Text(strengthLabel, style: TextStyle(color: scoreColor, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${a.score}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: scoreColor)),
                    const Text('/100', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: a.score / 100, color: scoreColor, backgroundColor: AppTheme.surfaceVariant),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _infoCard(loc.t('password.length'), '${a.length}')),
            const SizedBox(width: 8),
            Expanded(child: _infoCard(loc.t('password.entropy'), '${a.entropy.toStringAsFixed(1)} bits')),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: AppTheme.error.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [const Icon(Icons.timer, color: AppTheme.error, size: 16), const SizedBox(width: 8), Text(loc.t('password.crack_time'), style: const TextStyle(fontWeight: FontWeight.bold))]),
                const SizedBox(height: 8),
                _infoRow(loc.t('password.online_attack'), a.crackTime['online'] ?? '—'),
                _infoRow(loc.t('password.offline_attack'), a.crackTime['offline'] ?? '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: AppTheme.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.t('password.wpa_compatible'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(a.wpaRecommendation),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.error, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
