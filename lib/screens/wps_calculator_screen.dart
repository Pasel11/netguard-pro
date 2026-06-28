import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:netguard_pro/l10n/app_localizations.dart';
import 'package:netguard_pro/models/models.dart';
import 'package:netguard_pro/services/api_service.dart';
import 'package:netguard_pro/providers/premium_provider.dart';
import 'package:netguard_pro/providers/history_provider.dart';
import 'package:netguard_pro/utils/theme.dart';
import 'package:netguard_pro/widgets/custom/glass_card.dart';
import 'package:netguard_pro/widgets/custom/score_indicator.dart';

class WPSCalculatorScreen extends StatefulWidget {
  const WPSCalculatorScreen({super.key});

  @override
  State<WPSCalculatorScreen> createState() => _WPSCalculatorScreenState();
}

class _WPSCalculatorScreenState extends State<WPSCalculatorScreen>
    with SingleTickerProviderStateMixin {
  final _macController = TextEditingController();
  final _vendorController = TextEditingController();
  bool _loading = false;
  WPSResult? _result;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _macController.dispose();
    _vendorController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String _formatMac(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length && i < 12; i++) {
      if (i > 0 && i % 2 == 0) buffer.write(':');
      buffer.write(cleaned[i]);
    }
    return buffer.toString();
  }

  Future<void> _calculate() async {
    if (_macController.text.isEmpty) {
      _showError('Please enter MAC address');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await ApiService.calculateWPS(_macController.text);
      
      // حفظ في السجل
      if (mounted) {
        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        final score = result.matchingAlgorithm != null ? _getScoreFromVuln(result.matchingAlgorithm!.vulnerabilityLevel) : 50;
        historyProvider.addScan(ScanHistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'wps',
          title: result.detectedVendor,
          target: _macController.text,
          score: score,
          data: {'result': result.toString()},
          timestamp: DateTime.now(),
        ));
      }
      
      setState(() {
        _result = result;
        _loading = false;
      });
      _animController.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int _getScoreFromVuln(String level) {
    switch (level) {
      case 'critical': return 10;
      case 'high': return 30;
      case 'medium': return 60;
      case 'low': return 80;
      default: return 50;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied: $text')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final premium = Provider.of<PremiumProvider>(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Banner لو مش premium
          if (!premium.canUseAdvancedScan())
            _buildPremiumBanner(loc, premium),
          
          // Legal Warning
          GlassCard(
            color: AppTheme.warning.withOpacity(0.1),
            borderColor: AppTheme.warning.withOpacity(0.3),
            child: Row(
              children: [
                const Icon(Icons.warning, color: AppTheme.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.t('legal.warning'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Title
          Text(
            loc.t('wps.title'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            loc.t('wps.subtitle'),
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          
          // MAC Input
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.t('wps.mac_address'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _macController,
                  decoration: InputDecoration(
                    hintText: loc.t('wps.mac_placeholder'),
                    prefixIcon: const Icon(Icons.router),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          _macController.text = _formatMac(data!.text!);
                        }
                      },
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f:]')),
                    LengthLimitingTextInputFormatter(17),
                  ],
                  onChanged: (value) {
                    final formatted = _formatMac(value);
                    _macController.value = _macController.value.copyWith(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  loc.t('wps.mac_hint'),
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Calculate Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _calculate,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.calculate),
              label: Text(_loading ? 'Calculating...' : loc.t('wps.calculate')),
            ),
          ),
          const SizedBox(height: 24),
          
          // Error
          if (_error != null)
            GlassCard(
              color: AppTheme.error.withOpacity(0.1),
              borderColor: AppTheme.error,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Text(
                        'Error',
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _calculate,
                    icon: const Icon(Icons.refresh),
                    label: Text(loc.t('common.retry')),
                  ),
                ],
              ),
            ),
          
          // Results
          if (_result != null)
            FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Detected Vendor
                  _buildDetectedVendorCard(loc),
                  const SizedBox(height: 16),
                  
                  // Matching Algorithm (الأهم)
                  if (_result!.matchingAlgorithm != null) ...[
                    _buildMatchingAlgorithmCard(loc),
                    const SizedBox(height: 16),
                  ],
                  
                  // All Algorithms
                  if (premium.canUseAdvancedScan()) ...[
                    _buildAllAlgorithmsCard(loc),
                    const SizedBox(height: 16),
                  ] else
                    _buildLockedCard(loc, premium),
                  
                  // Protection Advice
                  _buildProtectionCard(loc),
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareResult(),
                          icon: const Icon(Icons.share),
                          label: Text(loc.t('common.share')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(_result!.matchingAlgorithm?.pin ?? ''),
                          icon: const Icon(Icons.copy),
                          label: Text(loc.t('common.copy_pin')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumBanner(AppLocalizations loc, PremiumProvider premium) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: AppTheme.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.t('wps.premium_required'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            child: Text(loc.t('settings.upgrade')),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedVendorCard(AppLocalizations loc) {
    return GlassCard(
      color: AppTheme.primary.withOpacity(0.05),
      borderColor: AppTheme.primary.withOpacity(0.2),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bolt, color: AppTheme.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.t('wps.detected_vendor'),
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
                Text(
                  _result!.detectedVendor,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'OUI: ${_result!.oui}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchingAlgorithmCard(AppLocalizations loc) {
    final algo = _result!.matchingAlgorithm!;
    final severityColor = AppTheme.getSeverityColor(algo.vulnerabilityLevel);
    
    return GlassCard(
      color: severityColor.withOpacity(0.05),
      borderColor: severityColor.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, size: 18),
              const SizedBox(width: 8),
              Text(
                loc.t('wps.matching_algorithm'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: severityColor),
                ),
                child: Text(
                  algo.vulnerabilityLevel.toUpperCase(),
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // PIN Display - مميز
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: severityColor.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: severityColor.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  loc.t('wps.expected_pin'),
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _copyToClipboard(algo.pin),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        algo.pin,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          letterSpacing: 6,
                          color: severityColor,
                          shadows: [
                            Shadow(
                              color: severityColor.withOpacity(0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy, size: 16, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Algorithm Info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.t('wps.algorithm'),
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      algo.algorithm,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.t('wps.exploit_time'),
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      algo.exploitTime,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            algo.description,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          
          // Vulnerability Indicator
          const SizedBox(height: 16),
          ScoreIndicator(
            score: _getScoreFromVuln(algo.vulnerabilityLevel),
            label: loc.t('wps.vulnerability'),
            reverseColor: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAllAlgorithmsCard(AppLocalizations loc) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list, size: 18),
              const SizedBox(width: 8),
              Text(
                loc.t('wps.calculated_pins'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_result!.allAlgorithms.length} ${loc.t('wps.algorithms')}',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_result!.allAlgorithms.map((algo) {
            final severityColor = AppTheme.getSeverityColor(algo.vulnerabilityLevel);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: severityColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          algo.vendor,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          algo.algorithm,
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => _copyToClipboard(algo.pin),
                        child: Text(
                          algo.pin,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: severityColor),
                        ),
                        child: Text(
                          algo.vulnerabilityLevel,
                          style: TextStyle(color: severityColor, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList()),
        ],
      ),
    );
  }

  Widget _buildLockedCard(AppLocalizations loc, PremiumProvider premium) {
    return GlassCard(
      color: AppTheme.warning.withOpacity(0.05),
      borderColor: AppTheme.warning.withOpacity(0.2),
      child: Column(
        children: [
          const Icon(Icons.lock, size: 48, color: AppTheme.warning),
          const SizedBox(height: 16),
          Text(
            loc.t('wps.all_algorithms_premium'),
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            loc.t('wps.unlock_all'),
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: () => premium.startTrial(),
                icon: const Icon(Icons.play_arrow),
                label: Text(loc.t('settings.start_trial')),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                icon: const Icon(Icons.workspace_premium),
                label: Text(loc.t('settings.upgrade')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionCard(AppLocalizations loc) {
    return GlassCard(
      color: AppTheme.primary.withOpacity(0.05),
      borderColor: AppTheme.primary.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                loc.t('wps.protection'),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_result!.protectionAdvice.map((advice) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(advice, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          )).toList()),
        ],
      ),
    );
  }

  void _shareResult() {
    if (_result?.matchingAlgorithm == null) return;
    final pin = _result!.matchingAlgorithm!.pin;
    final vendor = _result!.detectedVendor;
    // استخدم share_plus لمشاركة النتيجة
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing: $vendor - PIN: $pin')),
    );
  }
}
