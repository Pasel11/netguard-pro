import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/security/dns_leak_test.dart';
import '../../services/security/webrtc_leak_test.dart';
import '../../services/security/captive_firewall.dart';
import '../../providers/history_provider.dart';
import '../../utils/theme.dart';

/// شاشة موحدة لكشف كل أنواع التسريبات
class LeakDetectionScreen extends StatefulWidget {
  const LeakDetectionScreen({super.key});

  @override
  State<LeakDetectionScreen> createState() => _LeakDetectionScreenState();
}

class _LeakDetectionScreenState extends State<LeakDetectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _dnsLoading = false;
  bool _webrtcLoading = false;
  bool _captiveLoading = false;
  bool _firewallLoading = false;
  
  DnsLeakResult? _dnsResult;
  WebRtcLeakResult? _webrtcResult;
  List<CaptivePortalResult>? _captiveResults;
  FirewallTestResult? _firewallResult;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.security, size: 28, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Leak Detection',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'DNS, WebRTC, Captive Portal & Firewall',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Tab Bar
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'DNS Leak', icon: Icon(Icons.dns, size: 16)),
            Tab(text: 'WebRTC', icon: Icon(Icons.videocam, size: 16)),
            Tab(text: 'Captive', icon: Icon(Icons.wifi_lock, size: 16)),
            Tab(text: 'Firewall', icon: Icon(Icons.fire_extinguisher, size: 16)),
          ],
        ),
        
        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDnsTab(loc),
              _buildWebRtcTab(loc),
              _buildCaptiveTab(loc),
              _buildFirewallTab(loc),
            ],
          ),
        ),
      ],
    );
  }
  
  // ===== DNS Leak Tab =====
  Widget _buildDnsTab(AppLocalizations loc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppTheme.primary.withOpacity(0.1),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'DNS Leak Test يكتشف إذا كانت استعلامات DNS مكشوفة لـ ISP رغم استخدام VPN',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _dnsLoading ? null : _runDnsTest,
              icon: _dnsLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(_dnsLoading ? 'Testing...' : 'Run DNS Leak Test'),
            ),
          ),
          const SizedBox(height: 16),
          if (_dnsResult != null) ...[
            _buildResultCard(
              'Result',
              _dnsResult!.hasLeak 
                ? '🔴 DNS Leak Detected!' 
                : '✅ No DNS Leak',
              _dnsResult!.hasLeak ? AppTheme.error : AppTheme.primary,
            ),
            const SizedBox(height: 8),
            _buildInfoCard('Your IP', _dnsResult!.yourIp),
            _buildInfoCard('Location', _dnsResult!.yourLocation),
            _buildInfoCard('Expected DNS', _dnsResult!.expectedDns),
            _buildInfoCard('Actual DNS', _dnsResult!.actualDns),
            const SizedBox(height: 16),
            if (_dnsResult!.detectedServers.isNotEmpty) ...[
              const Text('Detected DNS Servers:',
                style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...(_dnsResult!.detectedServers.map((server) => Card(
                child: ListTile(
                  leading: const Icon(Icons.dns, color: AppTheme.primary),
                  title: Text('${server.name} (${server.ip})'),
                  subtitle: Text('${server.location} • ${server.responseTime}ms'),
                  trailing: Text('${server.responseTime}ms',
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
              )).toList()),
            ],
            const SizedBox(height: 16),
            _buildRecommendationsCard(_dnsResult!.recommendations),
          ],
        ],
      ),
    );
  }
  
  // ===== WebRTC Tab =====
  Widget _buildWebRtcTab(AppLocalizations loc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppTheme.primary.withOpacity(0.1),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'WebRTC Leak يكشف IP الحقيقي حتى مع VPN نشط',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _webrtcLoading ? null : _runWebRtcTest,
              icon: _webrtcLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(_webrtcLoading ? 'Testing...' : 'Run WebRTC Test'),
            ),
          ),
          const SizedBox(height: 16),
          if (_webrtcResult != null) ...[
            _buildResultCard(
              'Result',
              _webrtcResult!.summary,
              _webrtcResult!.hasLeak ? AppTheme.error : AppTheme.primary,
            ),
            const SizedBox(height: 8),
            _buildInfoCard('Public IP', _webrtcResult!.publicIp),
            _buildInfoCard('Local IP', _webrtcResult!.localIp),
            _buildInfoCard('VPN Active', _webrtcResult!.vpnActive ? 'Yes' : 'No'),
            if (_webrtcResult!.vpnIp != null)
              _buildInfoCard('VPN IP', _webrtcResult!.vpnIp!),
            if (_webrtcResult!.allIps.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('All Detected IPs:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...(_webrtcResult!.allIps.map((ip) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('  • $ip', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              )).toList()),
            ],
            if (_webrtcResult!.leakedIps.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: AppTheme.error.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning, color: AppTheme.error),
                          SizedBox(width: 8),
                          Text('Leaked IPs', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...(_webrtcResult!.leakedIps.map((ip) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(ip, style: const TextStyle(fontFamily: 'monospace', color: AppTheme.error)),
                      )).toList())),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildRecommendationsCard(_webrtcResult!.recommendations),
          ],
        ],
      ),
    );
  }
  
  // ===== Captive Portal Tab =====
  Widget _buildCaptiveTab(AppLocalizations loc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppTheme.primary.withOpacity(0.1),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Captive Portal Detector يكتشف إذا كنت خلف بوابة أسيرة (login required)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _captiveLoading ? null : _runCaptiveTest,
              icon: _captiveLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(_captiveLoading ? 'Testing...' : 'Run Captive Portal Test'),
            ),
          ),
          const SizedBox(height: 16),
          if (_captiveResults != null) ...[
            ...(_captiveResults!.map((result) => Card(
              child: ListTile(
                leading: Icon(
                  result.hasCaptivePortal ? Icons.warning : Icons.check_circle,
                  color: result.hasCaptivePortal ? AppTheme.error : AppTheme.primary,
                ),
                title: Text(result.hasCaptivePortal ? 'Portal Detected' : 'No Portal'),
                subtitle: Text(result.description),
              ),
            )).toList()),
          ],
        ],
      ),
    );
  }
  
  // ===== Firewall Tab =====
  Widget _buildFirewallTab(AppLocalizations loc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppTheme.primary.withOpacity(0.1),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Firewall Tester يفحص إذا كان جدار الحماية يعمل بشكل صحيح',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _firewallLoading ? null : _runFirewallTest,
              icon: _firewallLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(_firewallLoading ? 'Testing...' : 'Run Firewall Test'),
            ),
          ),
          const SizedBox(height: 16),
          if (_firewallResult != null) ...[
            _buildResultCard(
              'Firewall Score',
              '${_firewallResult!.firewallScore}/100',
              AppTheme.getScoreColor(_firewallResult!.firewallScore),
            ),
            const SizedBox(height: 16),
            const Text('Inbound Ports:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(_firewallResult!.inboundResults.map((r) => _buildPortResult(r)).toList()),
            const SizedBox(height: 16),
            const Text('Outbound Ports:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(_firewallResult!.outboundResults.map((r) => _buildPortResult(r)).toList()),
            const SizedBox(height: 16),
            if (_firewallResult!.issues.isNotEmpty) ...[
              Card(
                color: AppTheme.error.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Issues:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
                      const SizedBox(height: 8),
                      ...(_firewallResult!.issues.map((issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(issue, style: const TextStyle(fontSize: 12)),
                      )).toList())),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildRecommendationsCard(_firewallResult!.recommendations),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPortResult(FirewallPortResult r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          r.isBlocked ? Icons.lock : Icons.lock_open,
          color: r.direction == 'inbound'
            ? (r.isBlocked ? AppTheme.primary : AppTheme.error)
            : (r.isBlocked ? AppTheme.error : AppTheme.primary),
          size: 20,
        ),
        title: Text('Port ${r.port} (${r.direction})',
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
        subtitle: Text(r.description, style: const TextStyle(fontSize: 10)),
        trailing: Text(
          r.isBlocked ? 'Blocked' : 'Open',
          style: TextStyle(
            fontSize: 10,
            color: r.direction == 'inbound'
              ? (r.isBlocked ? AppTheme.primary : AppTheme.error)
              : (r.isBlocked ? AppTheme.error : AppTheme.primary),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildResultCard(String title, String value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
      ),
    );
  }
  
  Widget _buildRecommendationsCard(List<String> recommendations) {
    return Card(
      color: AppTheme.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Recommendations', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 12),
            ...(recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppTheme.primary)),
                  Expanded(child: Text(rec, style: const TextStyle(fontSize: 12))),
                ],
              ),
            )).toList())),
          ],
        ),
      ),
    );
  }
  
  // ===== Test Runners =====
  Future<void> _runDnsTest() async {
    setState(() => _dnsLoading = true);
    try {
      final result = await DnsLeakTest().performTest();
      setState(() => _dnsResult = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _dnsLoading = false);
    }
  }
  
  Future<void> _runWebRtcTest() async {
    setState(() => _webrtcLoading = true);
    try {
      final result = await WebRtcLeakTest().performTest();
      setState(() => _webrtcResult = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _webrtcLoading = false);
    }
  }
  
  Future<void> _runCaptiveTest() async {
    setState(() => _captiveLoading = true);
    try {
      final results = await CaptivePortalDetector().performFullScan();
      setState(() => _captiveResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _captiveLoading = false);
    }
  }
  
  Future<void> _runFirewallTest() async {
    setState(() => _firewallLoading = true);
    try {
      final result = await FirewallTester().performTest();
      setState(() => _firewallResult = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _firewallLoading = false);
    }
  }
}
