import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/local/network_discovery.dart';
import '../utils/theme.dart';

/// رسم بياني تفاعلي للشبكة
class NetworkMapWidget extends StatefulWidget {
  final List<DiscoveredDevice> devices;
  final String? gateway;
  final String? myIp;
  
  const NetworkMapWidget({
    super.key,
    required this.devices,
    this.gateway,
    this.myIp,
  });
  
  @override
  State<NetworkMapWidget> createState() => _NetworkMapWidgetState();
}

class _NetworkMapWidgetState extends State<NetworkMapWidget> {
  int? _selectedDeviceIndex;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Network Map',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${widget.devices.length} devices',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPaint(
              painter: _NetworkMapPainter(
                devices: widget.devices,
                gateway: widget.gateway,
                myIp: widget.myIp,
                selectedIndex: _selectedDeviceIndex,
                onTap: (index) {
                  setState(() {
                    _selectedDeviceIndex = _selectedDeviceIndex == index ? null : index;
                  });
                },
              ),
              child: Container(),
            ),
          ),
          if (_selectedDeviceIndex != null)
            _buildDeviceDetails(widget.devices[_selectedDeviceIndex!]),
        ],
      ),
    );
  }
  
  Widget _buildDeviceDetails(DiscoveredDevice device) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            device.vendor,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
          const SizedBox(height: 4),
          Text('IP: ${device.ip}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          if (device.mac != 'Unknown')
            Text('MAC: ${device.mac}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          Text('Type: ${device.type}', style: const TextStyle(fontSize: 11)),
          if (device.hostname != null)
            Text('Hostname: ${device.hostname}', style: const TextStyle(fontSize: 11)),
          if (device.responseTime != null)
            Text('Response: ${device.responseTime}ms', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _NetworkMapPainter extends CustomPainter {
  final List<DiscoveredDevice> devices;
  final String? gateway;
  final String? myIp;
  final int? selectedIndex;
  final Function(int) onTap;
  
  _NetworkMapPainter({
    required this.devices,
    this.gateway,
    this.myIp,
    this.selectedIndex,
    required this.onTap,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // رسم الـ router في المنتصف
    final routerPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 25, routerPaint);
    
    // رسم عنوان الـ router
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Router',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + 30),
    );
    
    if (gateway != null) {
      final ipPainter = TextPainter(
        text: TextSpan(
          text: gateway,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 8, fontFamily: 'monospace'),
        ),
        textDirection: TextDirection.ltr,
      );
      ipPainter.layout();
      ipPainter.paint(
        canvas,
        Offset(center.dx - ipPainter.width / 2, center.dy + 44),
      );
    }
    
    // رسم الأجهزة حول الـ router
    if (devices.isEmpty) return;
    
    final radius = size.width * 0.35;
    
    for (var i = 0; i < devices.length; i++) {
      final device = devices[i];
      final angle = (i / devices.length) * 2 * 3.14159265 - 3.14159265 / 2;
      
      final deviceX = center.dx + radius * 0.7 * (i.isEven ? 1 : -1);
      final deviceY = center.dy + (i.isEven ? -1 : 1) * (40 + (i ~/ 2) * 60);
      
      final deviceOffset = Offset(
        center.dx + radius * 0.6 * (i.isEven ? -1 : 1),
        center.dy + ((i ~/ 2) * 60 - 20) * (i.isEven ? -1 : 1) * (i < 2 ? 1 : -1),
      );
      
      // رسم خط الاتصال
      final linePaint = Paint()
        ..color = (selectedIndex == i ? AppTheme.primary : AppTheme.border).withOpacity(0.5)
        ..strokeWidth = selectedIndex == i ? 2 : 1;
      
      canvas.drawLine(center, deviceOffset, linePaint);
      
      // رسم الجهاز
      final devicePaint = Paint()
        ..color = _getDeviceColor(device)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(deviceOffset, 15, devicePaint);
      
      // رسم حدود الجهاز المحدد
      if (selectedIndex == i) {
        final borderPaint = Paint()
          ..color = AppTheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(deviceOffset, 18, borderPaint);
      }
      
      // رسم اسم الجهاز
      final deviceName = _getDeviceShortName(device);
      final namePainter = TextPainter(
        text: TextSpan(
          text: deviceName,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      namePainter.layout();
      namePainter.paint(
        canvas,
        Offset(
          deviceOffset.dx - namePainter.width / 2,
          deviceOffset.dy + 20,
        ),
      );
    }
  }
  
  Color _getDeviceColor(DiscoveredDevice device) {
    final type = device.type.toLowerCase();
    if (type.contains('router')) return AppTheme.primary;
    if (type.contains('apple') || type.contains('samsung')) return Colors.blue;
    if (type.contains('computer') || type.contains('laptop')) return Colors.purple;
    if (type.contains('iot') || type.contains('smart')) return Colors.orange;
    if (type.contains('printer')) return Colors.red;
    if (type.contains('unknown')) return AppTheme.textMuted;
    return AppTheme.primaryLight;
  }
  
  String _getDeviceShortName(DiscoveredDevice device) {
    if (device.vendor != 'Unknown') {
      return device.vendor.split(' ').first;
    }
    return device.ip.split('.').last;
  }
  
  @override
  bool shouldRepaint(covariant _NetworkMapPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex || 
           oldDelegate.devices.length != devices.length;
  }
}

/// رسم بياني لتوزيع أنواع الأجهزة
class DeviceTypeChart extends StatelessWidget {
  final List<DiscoveredDevice> devices;
  
  const DeviceTypeChart({super.key, required this.devices});
  
  @override
  Widget build(BuildContext context) {
    final typeCounts = <String, int>{};
    for (final device in devices) {
      final type = device.type;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    
    if (typeCounts.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: typeCounts.entries.map((entry) {
            final index = typeCounts.keys.toList().indexOf(entry.key);
            return PieChartSectionData(
              value: entry.value.toDouble(),
              title: '${entry.value}',
              color: _getColorForType(entry.key),
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }
  
  Color _getColorForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('router')) return Colors.green;
    if (t.contains('apple')) return Colors.blue;
    if (t.contains('samsung')) return Colors.purple;
    if (t.contains('huawei')) return Colors.red;
    if (t.contains('computer') || t.contains('laptop')) return Colors.orange;
    if (t.contains('iot') || t.contains('smart')) return Colors.teal;
    if (t.contains('printer')) return Colors.pink;
    return Colors.grey;
  }
}

/// رسم بياني لدرجات الأمان عبر الوقت
class SecurityScoreChart extends StatelessWidget {
  final List<int> scores;
  
  const SecurityScoreChart({super.key, required this.scores});
  
  @override
  Widget build(BuildContext context) {
    if (scores.length < 2) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    'Scan ${value.toInt() + 1}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: scores.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), e.value.toDouble());
              }).toList(),
              isCurved: true,
              color: AppTheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primary.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
