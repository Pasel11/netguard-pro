import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:netguard_pro/l10n/app_localizations.dart';
import 'package:netguard_pro/services/local/wifi_info_service.dart';
import 'package:netguard_pro/providers/history_provider.dart';
import 'package:netguard_pro/utils/theme.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  bool _testing = false;
  double _progress = 0;
  String _phase = '';
  SpeedTestResult? _result;
  String? _error;
  WifiInfo? _wifiInfo;
  PublicIpInfo? _publicIp;

  @override
  void initState() {
    super.initState();
    _loadInitialInfo();
  }

  Future<void> _loadInitialInfo() async {
    try {
      final wifiInfo = await WifiInfoService.getWifiInfo();
      final publicIp = await WifiInfoService.getPublicIpInfo();
      setState(() {
        _wifiInfo = wifiInfo;
        _publicIp = publicIp;
      });
    } catch (_) {}
  }

  Future<void> _startTest() async {
    setState(() {
      _testing = true;
      _error = null;
      _result = null;
      _progress = 0;
      _phase = 'Testing download speed...';
    });

    try {
      final result = await WifiInfoService.testInternetSpeed(
        onProgress: (progress) {
          setState(() {
            _progress = progress;
          });
        },
      );
      
      setState(() {
        _result = result;
        _testing = false;
        _phase = '';
      });

      // حفظ في السجل
      if (mounted) {
        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        historyProvider.addScan(ScanHistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'speedtest',
          title: 'Speed Test',
          target: _publicIp?.ip ?? 'Unknown',
          score: result.downloadSpeed > 10 ? 100 : 50,
          data: {
            'download': result.downloadSpeed,
            'upload': result.uploadSpeed,
          },
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _testing = false;
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
              const Icon(Icons.speed, size: 28, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Internet Speed Test',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Test your connection speed',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Network Info
          if (_wifiInfo != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi, color: AppTheme.primary, size: 18),
                        SizedBox(width: 8),
                        Text('Connection Info',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoRow('Connection Type', _wifiInfo!.connectionType),
                    if (_wifiInfo!.ssid != 'Unknown')
                      _infoRow('WiFi Name (SSID)', _wifiInfo!.ssid),
                    if (_wifiInfo!.ip != 'Unknown')
                      _infoRow('Local IP', _wifiInfo!.ip),
                    if (_wifiInfo!.gateway != 'Unknown')
                      _infoRow('Gateway', _wifiInfo!.gateway),
                    if (_publicIp != null) ...[
                      _infoRow('Public IP', _publicIp!.ip),
                      if (_publicIp!.isp != null)
                        _infoRow('ISP', _publicIp!.isp!),
                      if (_publicIp!.country != null)
                        _infoRow('Country', '${_publicIp!.country} (${_publicIp!.countryCode ?? ""})'),
                      if (_publicIp!.city != null)
                        _infoRow('City', _publicIp!.city!),
                    ],
                    _infoRow('Device', '${_wifiInfo!.manufacturer} ${_wifiInfo!.deviceModel}'),
                    _infoRow('OS', _wifiInfo!.osVersion),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          
          // Test Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _testing ? null : _startTest,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _testing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.play_arrow, size: 28),
              label: Text(
                _testing ? 'Testing...' : 'Start Speed Test',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Progress
          if (_testing) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 8),
                    Text(
                      _phase,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
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
            const SizedBox(height: 16),
            // Download Speed (Large)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.download, size: 48, color: AppTheme.primary),
                    const SizedBox(height: 8),
                    Text(
                      _result!.downloadSpeed.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Text('Mbps', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Text('Download Speed',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Upload Speed (Large)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.upload, size: 48, color: Colors.purple),
                    const SizedBox(height: 8),
                    Text(
                      _result!.uploadSpeed.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Text('Mbps', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Text('Upload Speed',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Additional Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Test Details',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _infoRow('Data Downloaded', '${(_result!.downloadSize / 1000000).toStringAsFixed(1)} MB'),
                    _infoRow('Data Uploaded', '${(_result!.uploadSize / 1000000).toStringAsFixed(1)} MB'),
                    _infoRow('Test Duration', '${_result!.duration.inSeconds} seconds'),
                    _infoRow('Timestamp', _result!.timestamp),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Quality Assessment
            Card(
              color: AppTheme.primary.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.assessment, color: AppTheme.primary),
                        SizedBox(width: 8),
                        Text('Quality Assessment',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...(_getQualityAssessment().map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['icon']!, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item['text']!,
                              style: const TextStyle(fontSize: 11)),
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
  
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
  
  List<Map<String, String>> _getQualityAssessment() {
    if (_result == null) return [];
    
    final dl = _result!.downloadSpeed;
    final ul = _result!.uploadSpeed;
    
    return [
      {
        'icon': dl >= 25 ? '✅' : dl >= 10 ? '🟡' : '🔴',
        'text': 'Download: ${dl >= 25 ? "Excellent for 4K streaming" : dl >= 10 ? "Good for HD streaming" : "Slow - basic browsing only"}',
      },
      {
        'icon': ul >= 5 ? '✅' : ul >= 1 ? '🟡' : '🔴',
        'text': 'Upload: ${ul >= 5 ? "Great for video calls & file sharing" : ul >= 1 ? "Acceptable for basic uploads" : "Slow - may affect video calls"}',
      },
      {
        'icon': dl > ul * 2 ? 'ℹ️' : '✅',
        'text': dl > ul * 2
          ? 'Asymmetric connection (typical for home internet)'
          : 'Symmetric connection (good for content creation)',
      },
      {
        'icon': _result!.duration.inSeconds < 10 ? '✅' : '🟡',
        'text': 'Test completed in ${_result!.duration.inSeconds}s',
      },
    ];
  }
}
