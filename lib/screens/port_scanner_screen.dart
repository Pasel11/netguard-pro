import 'package:flutter/material.dart';
import 'package:netguard_pro/l10n/app_localizations.dart';
import 'package:netguard_pro/models/models.dart';
import 'package:netguard_pro/services/api_service.dart';
import 'package:netguard_pro/utils/theme.dart';

class PortScannerScreen extends StatefulWidget {
  const PortScannerScreen({super.key});
  @override
  State<PortScannerScreen> createState() => _PortScannerScreenState();
}

class _PortScannerScreenState extends State<PortScannerScreen> {
  final _ipController = TextEditingController(text: '8.8.8.8');
  bool _scanning = false;
  double _progress = 0;
  PortScanResult? _result;

  Future<void> _scan() async {
    if (_ipController.text.isEmpty) return;
    setState(() {
      _scanning = true;
      _progress = 0;
      _result = null;
    });

    // simulate progress
    final timer = Stream.periodic(const Duration(milliseconds: 300), (i) => (i + 1) * 10.0)
        .take(9);
    timer.listen((p) {
      if (!_scanning) return;
      setState(() => _progress = p);
    });

    try {
      final result = await ApiService.scanPorts(_ipController.text);
      setState(() {
        _result = result;
        _progress = 100;
        _scanning = false;
      });
    } catch (e) {
      setState(() => _scanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
          Text(loc.t('ports.title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: loc.t('ports.target_ip'),
                    prefixIcon: const Icon(Icons.computer),
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _scanning ? null : _scan,
                child: _scanning
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(loc.t('ports.start_scan')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_scanning) ...[
            LinearProgressIndicator(value: _progress / 100),
            const SizedBox(height: 8),
            Text('${_progress.toInt()}% - ${loc.t('ports.scan_progress')}'),
          ],
          if (_result != null) ...[
            _buildSummary(loc),
            const SizedBox(height: 16),
            _buildOpenPorts(loc),
            const SizedBox(height: 16),
            _buildRisksAndRecs(loc),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary(AppLocalizations loc) {
    final r = _result!;
    return Row(
      children: [
        Expanded(child: _statCard(loc.t('ports.open'), r.openPortsCount, AppTheme.primary)),
        const SizedBox(width: 8),
        Expanded(child: _statCard(loc.t('ports.closed'), r.closedPortsCount, AppTheme.textSecondary)),
        const SizedBox(width: 8),
        Expanded(child: _statCard(loc.t('ports.total'), r.totalPorts, AppTheme.textSecondary)),
      ],
    );
  }

  Widget _statCard(String label, int value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(Icons.check_circle, color: color, size: 20),
            const SizedBox(height: 4),
            Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenPorts(AppLocalizations loc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.t('ports.open'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(_result!.openPorts.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('${p.port}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.service, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
                  if (p.responseTime != null)
                    Text('${p.responseTime}ms', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            )).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildRisksAndRecs(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_result!.risks.isNotEmpty) ...[
          Card(
            color: AppTheme.error.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.t('ports.risks'), style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...(_result!.risks.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $r', style: const TextStyle(fontSize: 11)),
                  )).toList()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_result!.recommendations.isNotEmpty)
          Card(
            color: AppTheme.primary.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.t('ports.recommendations'), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...(_result!.recommendations.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $r', style: const TextStyle(fontSize: 11)),
                  )).toList()),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
