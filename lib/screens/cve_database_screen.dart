import 'package:flutter/material.dart';
import 'package:netguard_pro/l10n/app_localizations.dart';
import 'package:netguard_pro/models/models.dart';
import 'package:netguard_pro/services/api_service.dart';
import 'package:netguard_pro/utils/theme.dart';

class CVEDatabaseScreen extends StatefulWidget {
  const CVEDatabaseScreen({super.key});
  @override
  State<CVEDatabaseScreen> createState() => _CVEDatabaseScreenState();
}

class _CVEDatabaseScreenState extends State<CVEDatabaseScreen> {
  List<CVE> _allCVEs = [];
  List<CVE> _filtered = [];
  bool _loading = true;
  String? _selectedVendor;

  final _vendors = ['TP-Link', 'D-Link', 'Netgear', 'Huawei', 'Cisco', 'Zyxel', 'Arcadyan', 'Mikrotik'];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final cves = await ApiService.getCVEs();
      setState(() {
        _allCVEs = cves;
        _filtered = cves;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _search() async {
    if (_selectedVendor == null) return;
    setState(() => _loading = true);
    try {
      final cves = await ApiService.getCVEs(vendor: _selectedVendor);
      setState(() {
        _filtered = cves;
        _loading = false;
      });
    } catch (e) {
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
          Text(loc.t('cve.title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Stats
          Row(
            children: [
              Expanded(child: _statCard(loc.t('cve.total'), _allCVEs.length, AppTheme.primary)),
              const SizedBox(width: 8),
              Expanded(child: _statCard(loc.t('cve.critical'), _allCVEs.where((c) => c.severity == 'critical').length, AppTheme.critical)),
              const SizedBox(width: 8),
              Expanded(child: _statCard(loc.t('cve.high'), _allCVEs.where((c) => c.severity == 'high').length, AppTheme.error)),
            ],
          ),
          const SizedBox(height: 16),
          // Search
          DropdownButtonFormField<String>(
            value: _selectedVendor,
            decoration: InputDecoration(labelText: loc.t('cve.vendor'), prefixIcon: const Icon(Icons.business)),
            items: _vendors.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _selectedVendor = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: _search, icon: const Icon(Icons.search), label: Text(loc.t('cve.search')))),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () { setState(() => _filtered = _allCVEs); }, child: Text(loc.t('cve.show_all'))),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading) const Center(child: CircularProgressIndicator())
          else ...(_filtered.map((cve) => _buildCVECard(cve, loc)).toList()),
        ],
      ),
    );
  }

  Widget _statCard(String label, int value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildCVECard(CVE cve, AppLocalizations loc) {
    final sevColor = AppTheme.getSeverityColor(cve.severity);
    return Card(
      color: sevColor.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(cve.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: sevColor)),
                  child: Text(cve.severity.toUpperCase(), style: TextStyle(color: sevColor, fontSize: 9)),
                ),
                const Spacer(),
                Text('CVSS: ${cve.cvss}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              ],
            ),
            const SizedBox(height: 4),
            Text(cve.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(cve.description, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('${cve.vendor} - ${cve.model}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield, color: AppTheme.primary, size: 14),
                  const SizedBox(width: 4),
                  Expanded(child: Text('${loc.t('cve.solution')}: ${cve.solution}', style: const TextStyle(fontSize: 10))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
