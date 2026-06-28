import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/local/network_discovery.dart';
import '../providers/history_provider.dart';
import '../utils/theme.dart';
import '../widgets/charts/network_map.dart';

class NetworkMapScreen extends StatefulWidget {
  const NetworkMapScreen({super.key});

  @override
  State<NetworkMapScreen> createState() => _NetworkMapScreenState();
}

class _NetworkMapScreenState extends State<NetworkMapScreen> {
  bool _scanning = false;
  NetworkDetails? _network;
  List<DiscoveredDevice> _devices = [];
  String? _error;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _scanning = true;
      _error = null;
      _progress = 0;
    });

    try {
      // الحصول على معلومات الشبكة
      final network = await NetworkDiscovery.getCurrentNetwork();
      if (network == null) {
        setState(() {
          _error = 'Unable to get network info. Make sure you\'re connected to WiFi.';
          _scanning = false;
        });
        return;
      }

      setState(() {
        _network = network;
        _progress = 0.2;
      });

      // كشف الأجهزة
      final devices = await NetworkDiscovery.fullDiscovery(network.networkBase);
      
      setState(() {
        _devices = devices;
        _progress = 1.0;
        _scanning = false;
      });

      // حفظ في السجل
      if (mounted) {
        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        historyProvider.addScan(ScanHistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'devices',
          title: 'Network Discovery',
          target: network.networkBase,
          score: devices.isEmpty ? 100 : 50,
          data: {'deviceCount': devices.length},
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _scanning = false;
      });
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
          // Header
          Row(
            children: [
              const Icon(Icons.hub, size: 28, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.t('nav.devices'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      loc.t('devices.title'),
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _scanning ? null : _startDiscovery,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Network Info
          if (_network != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wifi, color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          loc.t('signal.network_type'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoRow('SSID', _network!.ssid),
                    _infoRow('Your IP', _network!.ip),
                    _infoRow('Gateway', _network!.gateway),
                    _infoRow('Subnet', _network!.subnet),
                    if (_network!.bssid != 'Unknown')
                      _infoRow('BSSID', _network!.bssid),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          
          // Scanning Progress
          if (_scanning) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              _progress < 0.5 ? 'Getting network info...' : 'Scanning network...',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
          ],
          
          // Error
          if (_error != null)
            Card(
              color: AppTheme.error.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Text(loc.t('common.error'),
                          style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(
                      'Note: This feature requires location permission and may need root on some devices.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          
          // Network Map
          if (_devices.isNotEmpty) ...[
            NetworkMapWidget(
              devices: _devices,
              gateway: _network?.gateway,
              myIp: _network?.ip,
            ),
            const SizedBox(height: 16),
            
            // Device Type Chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Distribution',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DeviceTypeChart(devices: _devices),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Devices List
            Text(
              '${_devices.length} ${loc.t('devices.found')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...(_devices.map((device) => _buildDeviceCard(device))),
          ],
          
          if (!_scanning && _devices.isEmpty && _error == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.wifi_off, size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(loc.t('devices.unknown'),
                      style: TextStyle(color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ),
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
          Text(value, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  
  Widget _buildDeviceCard(DiscoveredDevice device) {
    final deviceIcon = _getDeviceIcon(device.type);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(deviceIcon, color: AppTheme.primary),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.vendor != 'Unknown' ? device.vendor : 'Device ${device.ip.split('.').last}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (device.responseTime != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${device.responseTime}ms',
                  style: const TextStyle(fontSize: 10, color: AppTheme.primary),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              device.ip,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(_statusIcon(device.status), size: 12, color: _statusColor(device.status)),
                const SizedBox(width: 4),
                Text(
                  device.type,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                if (device.mac != 'Unknown') ...[
                  const SizedBox(width: 8),
                  Text(
                    device.mac,
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontFamily: 'monospace'),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: () {
          // عرض تفاصيل أكثر
          _showDeviceDetails(device);
        },
      ),
    );
  }
  
  IconData _getDeviceIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('router')) return Icons.router;
    if (t.contains('apple') || t.contains('samsung') || t.contains('huawei') || t.contains('xiaomi')) return Icons.smartphone;
    if (t.contains('computer') || t.contains('laptop')) return Icons.laptop;
    if (t.contains('printer')) return Icons.print;
    if (t.contains('iot') || t.contains('smart')) return Icons.devices_other;
    if (t.contains('playstation') || t.contains('xbox')) return Icons.gamepad;
    return Icons.devices;
  }
  
  IconData _statusIcon(String status) {
    if (status == 'reachable' || status == 'static' || status == 'dynamic') return Icons.check_circle;
    return Icons.help_outline;
  }
  
  Color _statusColor(String status) {
    if (status == 'reachable' || status == 'static' || status == 'dynamic') return AppTheme.primary;
    return AppTheme.textMuted;
  }
  
  void _showDeviceDetails(DiscoveredDevice device) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.vendor != 'Unknown' ? device.vendor : 'Unknown Device',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _detailRow('IP Address', device.ip),
            _detailRow('MAC Address', device.mac),
            _detailRow('Vendor', device.vendor),
            _detailRow('Type', device.type),
            _detailRow('Status', device.status),
            if (device.hostname != null) _detailRow('Hostname', device.hostname!),
            if (device.responseTime != null) _detailRow('Response Time', '${device.responseTime}ms'),
            _detailRow('First Seen', device.firstSeen.toString()),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
