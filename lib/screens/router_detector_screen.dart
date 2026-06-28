import 'package:flutter/material.dart';
import 'package:netguard_pro/l10n/app_localizations.dart';
import 'package:netguard_pro/models/models.dart';
import 'package:netguard_pro/services/api_service.dart';
import 'package:netguard_pro/utils/theme.dart';

class RouterDetectorScreen extends StatefulWidget {
  const RouterDetectorScreen({super.key});
  @override
  State<RouterDetectorScreen> createState() => _RouterDetectorScreenState();
}

class _RouterDetectorScreenState extends State<RouterDetectorScreen> {
  final _ipController = TextEditingController(text: '192.168.1.1');
  bool _loading = false;
  RouterInfo? _info;

  Future<void> _detect() async {
    setState(() => _loading = true);
    try {
      final info = await ApiService.detectRouter(_ipController.text);
      setState(() => _info = info);
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
          Text(loc.t('router.title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  decoration: InputDecoration(labelText: loc.t('router.router_ip'), prefixIcon: const Icon(Icons.router)),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _loading ? null : _detect, child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(loc.t('router.detect'))),
            ],
          ),
          const SizedBox(height: 16),
          if (_info != null) _buildResult(loc),
        ],
      ),
    );
  }

  Widget _buildResult(AppLocalizations loc) {
    final i = _info!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: (i.detected ? AppTheme.primary : AppTheme.textMuted).withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
                  child: Icon(Icons.router, color: i.detected ? AppTheme.primary : AppTheme.textMuted),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.vendor ?? loc.t('router.not_detected'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(i.ip, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                if (i.detected) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primary)),
                  child: Text(loc.t('router.detected'), style: const TextStyle(color: AppTheme.primary, fontSize: 10)),
                ),
              ],
            ),
            if (i.model != null) ...[
              const SizedBox(height: 12),
              _infoRow(loc.t('router.model'), i.model!),
            ],
            if (i.firmware != null) _infoRow(loc.t('router.firmware'), i.firmware!),
            if (i.httpStatus != null) _infoRow('HTTP Status', '${i.httpStatus}'),
            const SizedBox(height: 16),
            if (i.risks.isNotEmpty) ...[
              Text(loc.t('router.notes'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...(i.risks.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('• '), Expanded(child: Text(r, style: const TextStyle(fontSize: 11)))]),
              )).toList()),
            ],
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
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
