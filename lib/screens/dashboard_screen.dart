import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shimmer/shimmer.dart';

import 'package:netguard_pro/l10n/app_localizations.dart';
import 'package:netguard_pro/models/models.dart';
import 'package:netguard_pro/services/api_service.dart';
import 'package:netguard_pro/utils/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  NetworkInfo? _networkInfo;
  bool _loading = true;
  String? _error;
  int _securityScore = 0;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
  }

  Future<void> _loadNetworkInfo() async {
    try {
      final info = await ApiService.getNetworkInfo();
      setState(() {
        _networkInfo = info;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _calculateSecurityScore() {
    setState(() {
      _scanning = true;
    });
    
    // حساب مبسّط لدرجة الأمان
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _securityScore = 75; // درجة مبدئية
        _scanning = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return RefreshIndicator(
      onRefresh: _loadNetworkInfo,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            _buildStatusBanner(loc),
            const SizedBox(height: 16),
            
            // Connection Info Grid
            _buildConnectionGrid(loc),
            const SizedBox(height: 16),
            
            // Geographic Info
            if (_networkInfo?.country != null) _buildGeographicInfo(loc),
            const SizedBox(height: 16),
            
            // Security Score
            _buildSecurityScore(loc),
            const SizedBox(height: 16),
            
            // Quick Actions
            _buildQuickActions(loc),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(AppLocalizations loc) {
    return StreamBuilder<ConnectivityResult>(
      stream: Connectivity().onConnectivityChanged,
      initialData: ConnectivityResult.none,
      builder: (context, snapshot) {
        final isConnected = snapshot.data != ConnectivityResult.none;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isConnected ? AppTheme.primary : AppTheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.t('dashboard.system_active'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isConnected 
                          ? loc.t('dashboard.connected')
                          : loc.t('dashboard.disconnected'),
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionGrid(AppLocalizations loc) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: [
        _buildInfoCard(
          icon: Icons.public,
          title: loc.t('dashboard.public_ip'),
          value: _loading ? null : _networkInfo?.publicIp ?? 'Unknown',
        ),
        _buildInfoCard(
          icon: Icons.speed,
          title: loc.t('dashboard.download_speed'),
          value: '— Mbps',
        ),
        _buildInfoCard(
          icon: Icons.wifi,
          title: loc.t('dashboard.latency'),
          value: '— ms',
        ),
        _buildInfoCard(
          icon: Icons.business,
          title: loc.t('dashboard.isp'),
          value: _loading ? null : _networkInfo?.isp ?? 'Unknown',
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    String? value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.textSecondary),
                const Spacer(),
                Icon(Icons.more_vert, size: 12, color: AppTheme.textMuted),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            if (value == null)
              Shimmer.fromColors(
                baseColor: AppTheme.surfaceVariant,
                highlightColor: AppTheme.border,
                child: Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )
            else
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeographicInfo(AppLocalizations loc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.public, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  loc.t('dashboard.geographic_info'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(loc.t('dashboard.country'), 
                '${_networkInfo?.country ?? '—'} (${_networkInfo?.countryCode ?? '—'})'),
            if (_networkInfo?.city != null)
              _buildInfoRow(loc.t('dashboard.city'), _networkInfo!.city!),
            if (_networkInfo?.asn != null)
              _buildInfoRow(loc.t('dashboard.timezone'), _networkInfo!.asn!),
            if (_networkInfo?.timezone != null)
              _buildInfoRow(loc.t('dashboard.timezone'), _networkInfo!.timezone!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSecurityScore(AppLocalizations loc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  loc.t('dashboard.security_score'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_scanning)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_securityScore == 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _scanning ? null : _calculateSecurityScore,
                  icon: const Icon(Icons.security),
                  label: Text(loc.t('dashboard.start_scan')),
                ),
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '$_securityScore',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getScoreColor(_securityScore),
                        ),
                      ),
                      const Text('/100', style: TextStyle(color: AppTheme.textSecondary)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.getScoreColor(_securityScore).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.getScoreColor(_securityScore),
                          ),
                        ),
                        child: Text(
                          _securityScore >= 75 
                              ? loc.t('dashboard.secure')
                              : _securityScore >= 50
                                  ? loc.t('dashboard.medium')
                                  : loc.t('dashboard.weak'),
                          style: TextStyle(
                            color: AppTheme.getScoreColor(_securityScore),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _securityScore / 100,
                    backgroundColor: AppTheme.surfaceVariant,
                    color: AppTheme.getScoreColor(_securityScore),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(AppLocalizations loc) {
    final actions = [
      {'icon': Icons.lock, 'title': loc.t('nav.ports'), 'index': 2},
      {'icon': Icons.calculate, 'title': loc.t('nav.wps'), 'index': 1},
      {'icon': Icons.key, 'title': loc.t('nav.password'), 'index': 3},
      {'icon': Icons.bug_report, 'title': loc.t('nav.cve'), 'index': 4},
    ];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.t('dashboard.quick_actions'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3,
              children: actions.map((action) {
                return OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Navigate to specific screen
                  },
                  icon: Icon(action['icon'] as IconData, size: 18),
                  label: Text(action['title'] as String, style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
