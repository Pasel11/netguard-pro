import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:netguard_pro/l10n/app_localizations.dart';
import 'package:netguard_pro/services/local/ping_service.dart';
import 'package:netguard_pro/providers/history_provider.dart';
import 'package:netguard_pro/utils/theme.dart';

class PingScreen extends StatefulWidget {
  const PingScreen({super.key});

  @override
  State<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends State<PingScreen> {
  final _hostController = TextEditingController(text: '8.8.8.8');
  bool _loading = false;
  PingResult? _pingResult;
  TracerouteResult? _tracerouteResult;
  String? _error;
  int _pingCount = 4;

  Future<void> _ping() async {
    if (_hostController.text.isEmpty) return;
    
    setState(() {
      _loading = true;
      _error = null;
      _pingResult = null;
      _tracerouteResult = null;
    });

    try {
      final result = await PingService.ping(
        _hostController.text,
        count: _pingCount,
        timeout: 2,
      );
      
      setState(() {
        _pingResult = result;
        _loading = false;
      });

      // حفظ في السجل
      if (mounted) {
        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        historyProvider.addScan(ScanHistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'ping',
          title: 'Ping',
          target: _hostController.text,
          score: result.packetLoss == 0 ? 100 : 50,
          data: {'avgRtt': result.avgRtt, 'loss': result.packetLoss},
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _traceroute() async {
    if (_hostController.text.isEmpty) return;
    
    setState(() {
      _loading = true;
      _error = null;
      _pingResult = null;
      _tracerouteResult = null;
    });

    try {
      final result = await PingService.traceroute(_hostController.text, maxHops: 15);
      setState(() {
        _tracerouteResult = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
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
              const Icon(Icons.network_ping, size: 28, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ping & Traceroute',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Test network connectivity and path',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host (IP or Domain)',
                    hintText: '8.8.8.8 or google.com',
                    prefixIcon: Icon(Icons.computer),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Quick hosts
          Wrap(
            spacing: 8,
            children: ['8.8.8.8', '1.1.1.1', 'google.com', 'github.com'].map((host) {
              return ActionChip(
                label: Text(host),
                onPressed: () {
                  _hostController.text = host;
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _ping,
                  icon: _loading && _pingResult == null
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.ping),
                  label: const Text('Ping'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _traceroute,
                  icon: _loading && _tracerouteResult == null
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.route),
                  label: const Text('Traceroute'),
                ),
              ),
            ],
          ),
          
          // Ping Count Selector
          if (_pingResult == null && _tracerouteResult == null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Text('Ping count: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 4,
                    children: [1, 4, 10].map((count) {
                      return ChoiceChip(
                        label: Text('$count'),
                        selected: _pingCount == count,
                        onSelected: (selected) {
                          if (selected) setState(() => _pingCount = count);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 24),
          
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
          
          // Ping Results
          if (_pingResult != null) ...[
            // Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        const Text('Ping Results',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (_pingResult!.packetLoss == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary),
                            ),
                            child: const Text('Online',
                              style: TextStyle(color: AppTheme.primary, fontSize: 10)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.error),
                            ),
                            child: Text('${_pingResult!.packetLoss}% loss',
                              style: const TextStyle(color: AppTheme.error, fontSize: 10)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _statBox('Sent', '${_pingResult!.packetsSent}'),
                        _statBox('Received', '${_pingResult!.packetsReceived}'),
                        _statBox('Loss', '${_pingResult!.packetLoss}%'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _statBox('Min', '${_pingResult!.minRtt}ms'),
                        _statBox('Avg', '${_pingResult!.avgRtt}ms'),
                        _statBox('Max', '${_pingResult!.maxRtt}ms'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Individual Replies
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Individual Pings',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...(_pingResult!.replies.asMap().entries.map((entry) {
                      final reply = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text('${entry.key + 1}.',
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFamily: 'monospace')),
                            ),
                            Icon(
                              reply.success ? Icons.check_circle : Icons.error,
                              size: 14,
                              color: reply.success ? AppTheme.primary : AppTheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reply.success
                                    ? 'Reply from ${_pingResult!.host}: time=${reply.rtt}ms TTL=${reply.ttl ?? "?"}'
                                    : 'Request failed: ${reply.error}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: reply.success ? AppTheme.textPrimary : AppTheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList())),
                  ],
                ),
              ),
            ),
          ],
          
          // Traceroute Results
          if (_tracerouteResult != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.route, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        const Text('Traceroute Results',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${_tracerouteResult!.totalHops} hops',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...(_tracerouteResult!.hops.map((hop) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text('${hop.hopNumber}',
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hop.ip.isNotEmpty ? hop.ip : '*',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: hop.ip.isNotEmpty ? AppTheme.textPrimary : AppTheme.textMuted,
                                    ),
                                  ),
                                  if (hop.host.isNotEmpty && hop.host != hop.ip)
                                    Text(
                                      hop.host,
                                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                    ),
                                  if (hop.avgRtt != null)
                                    Text(
                                      '${hop.avgRtt!.toStringAsFixed(1)} ms',
                                      style: TextStyle(fontSize: 10, color: AppTheme.primary),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList())),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _statBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
            Text(label, style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
