import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:netguard_pro/l10n/app_localizations.dart';
import 'package:netguard_pro/services/wireless/bluetooth_scanner.dart';
import 'package:netguard_pro/providers/history_provider.dart';
import 'package:netguard_pro/utils/theme.dart';

class BluetoothScannerScreen extends StatefulWidget {
  const BluetoothScannerScreen({super.key});

  @override
  State<BluetoothScannerScreen> createState() => _BluetoothScannerScreenState();
}

class _BluetoothScannerScreenState extends State<BluetoothScannerScreen> {
  final BluetoothScanner _scanner = BluetoothScanner();
  bool _scanning = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _scanner.deviceStream.listen((_) {
      if (mounted) setState(() {});
    });
  }
  
  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }
  
  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    
    final success = await _scanner.startScan(timeout: const Duration(seconds: 15));
    
    if (!success) {
      setState(() {
        _error = 'Bluetooth scan requires root or hcitool. Some features may not work.';
      });
    }
    
    setState(() => _scanning = false);
    
    if (_scanner.devices.isNotEmpty && mounted) {
      final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
      historyProvider.addScan(ScanHistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'bluetooth',
        title: 'Bluetooth Scan',
        target: 'Bluetooth',
        score: _scanner.devices.isEmpty ? 100 : 50,
        data: {'deviceCount': _scanner.devices.length},
        timestamp: DateTime.now(),
      ));
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
              const Icon(Icons.bluetooth, size: 28, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bluetooth Scanner',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Discover nearby Bluetooth devices',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Warning
          Card(
            color: AppTheme.warning.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bluetooth scanning requires root access on most devices. Without root, only basic information is available.',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Scan Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _scanning ? null : _startScan,
              icon: _scanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: Text(_scanning ? 'Scanning...' : 'Start Bluetooth Scan'),
            ),
          ),
          const SizedBox(height: 16),
          
          // Error
          if (_error != null)
            Card(
              color: AppTheme.error.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppTheme.error)),
                    ),
                  ],
                ),
              ),
            ),
          
          // Devices List
          if (_scanner.devices.isNotEmpty) ...[
            Text(
              'Discovered Devices (${_scanner.devices.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...(_scanner.devices.map((device) => _buildDeviceCard(device)).toList()),
          ],
          
          if (!_scanning && _scanner.devices.isEmpty && _error == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_disabled,
                      size: 64,
                      color: AppTheme.textMuted.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No devices discovered yet',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDeviceCard(BluetoothDevice device) {
    final deviceIcon = _getDeviceIcon(device.type);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(deviceIcon, color: AppTheme.primary),
        ),
        title: Text(
          device.name != 'Unknown' ? device.name : 'Unknown Device',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              device.mac,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (device.rssi != null) ...[
                  Icon(Icons.signal_cellular_4_bar, size: 12, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${device.rssi}dBm',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.category, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  device.type,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Vendor', device.vendor),
                _detailRow('MAC Address', device.mac),
                _detailRow('Type', device.type),
                if (device.deviceClass != null) _detailRow('Device Class', device.deviceClass!),
                if (device.manufacturer != null) _detailRow('Manufacturer', device.manufacturer!),
                if (device.rssi != null) ...[
                  _detailRow('Signal Strength', '${device.rssi} dBm'),
                  _detailRow('Signal Quality', device.signalQuality),
                ],
                if (device.services.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Services:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  ...(device.services.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.settings, size: 12, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${s.name}${s.protocol != null ? " (${s.protocol})" : ""}${s.port != null ? " :${s.port}" : ""}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  )).toList()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getDeviceIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('smartphone') || t.contains('phone')) return Icons.smartphone;
    if (t.contains('earbuds') || t.contains('headphone')) return Icons.headphones;
    if (t.contains('watch')) return Icons.watch;
    if (t.contains('speaker')) return Icons.speaker;
    if (t.contains('tv')) return Icons.tv;
    if (t.contains('keyboard')) return Icons.keyboard;
    if (t.contains('mouse')) return Icons.mouse;
    if (t.contains('laptop')) return Icons.laptop;
    return Icons.bluetooth;
  }
  
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
