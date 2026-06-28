import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:netguard_pro/l10n/app_localizations.dart';
import 'package:netguard_pro/services/security/intrusion_detection.dart';
import 'package:netguard_pro/utils/theme.dart';

class IdsMonitorScreen extends StatefulWidget {
  const IdsMonitorScreen({super.key});

  @override
  State<IdsMonitorScreen> createState() => _IdsMonitorScreenState();
}

class _IdsMonitorScreenState extends State<IdsMonitorScreen> {
  final IntrusionDetectionService _ids = IntrusionDetectionService();
  bool _isMonitoring = false;
  
  @override
  void initState() {
    super.initState();
    _ids.alertStream.listen((alert) {
      if (mounted) setState(() {});
    });
  }
  
  @override
  void dispose() {
    _ids.dispose();
    super.dispose();
  }
  
  Future<void> _toggleMonitoring() async {
    if (_isMonitoring) {
      _ids.stopMonitoring();
      setState(() => _isMonitoring = false);
    } else {
      final success = await _ids.startMonitoring();
      if (success) {
        setState(() => _isMonitoring = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start monitoring. Check permissions.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final stats = _ids.getAlertStats();
    final alerts = _ids.alerts.reversed.toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.security, size: 28, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Intrusion Detection',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Real-time network security monitoring',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Status Card
          Card(
            color: _isMonitoring 
              ? AppTheme.primary.withOpacity(0.1)
              : AppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _isMonitoring ? AppTheme.primary : AppTheme.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isMonitoring ? 'Monitoring Active' : 'Monitoring Stopped',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _isMonitoring 
                                ? 'Scanning for threats every 30 seconds'
                                : 'Click start to begin monitoring',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isMonitoring,
                        onChanged: (_) => _toggleMonitoring(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Stats Grid
          if (_ids.alertCount > 0) ...[
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.5,
              children: [
                _buildStatCard(
                  'Critical',
                  stats[AlertSeverity.critical] ?? 0,
                  AppTheme.error,
                ),
                _buildStatCard(
                  'High',
                  stats[AlertSeverity.high] ?? 0,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Medium',
                  stats[AlertSeverity.medium] ?? 0,
                  AppTheme.warning,
                ),
                _buildStatCard(
                  'Total Alerts',
                  _ids.alertCount,
                  AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          // Alerts List
          if (alerts.isEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      _isMonitoring ? Icons.shield : Icons.shield_moon,
                      size: 64,
                      color: AppTheme.textMuted.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isMonitoring 
                        ? 'No threats detected yet'
                        : 'Start monitoring to detect threats',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Text('Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _ids.clearAlerts()),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...(alerts.map((alert) => _buildAlertCard(alert)).toList()),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, int count, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAlertCard(SecurityAlert alert) {
    final severityColor = _getSeverityColor(alert.severity);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: severityColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: severityColor.withOpacity(0.3)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: severityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getAlertIcon(alert.type),
            color: severityColor,
            size: 20,
          ),
        ),
        title: Text(
          alert.title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: severityColor),
              ),
              child: Text(
                alert.severity.displayName,
                style: TextStyle(color: severityColor, fontSize: 9),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTime(alert.timestamp),
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.description, style: const TextStyle(fontSize: 12)),
                if (alert.sourceIp != null) ...[
                  const SizedBox(height: 8),
                  Text('Source: ${alert.sourceIp}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textSecondary)),
                ],
                if (alert.sourceMac != null) ...[
                  Text('MAC: ${alert.sourceMac}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textSecondary)),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb, color: AppTheme.primary, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          alert.recommendation,
                          style: const TextStyle(fontSize: 11, color: AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical: return AppTheme.error;
      case AlertSeverity.high: return Colors.orange;
      case AlertSeverity.medium: return AppTheme.warning;
      case AlertSeverity.low: return AppTheme.primary;
      case AlertSeverity.info: return AppTheme.textSecondary;
    }
  }
  
  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.newDevice: return Icons.devices;
      case AlertType.macSpoofing: return Icons.fingerprint;
      case AlertType.openPort: return Icons.lock_open;
      case AlertType.deauthAttack: return Icons.wifi_off;
      case AlertType.rogueAp: return Icons.wifi_tethering;
      case AlertType.dnsLeak: return Icons.dns;
      case AlertType.webrtcLeak: return Icons.videocam;
      case AlertType.portScan: return Icons.radar;
      case AlertType.bruteForce: return Icons.password;
      case AlertType.malware: return Icons.bug_report;
      case AlertType.suspiciousTraffic: return Icons.warning;
    }
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
