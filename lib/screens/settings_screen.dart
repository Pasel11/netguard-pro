import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/history_provider.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final premiumProvider = Provider.of<PremiumProvider>(context);
    final historyProvider = Provider.of<HistoryProvider>(context);
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Premium Status
        if (premiumProvider.isPremium)
          _buildPremiumBanner(loc)
        else
          _buildPremiumUpgradeCard(loc, premiumProvider),
        const SizedBox(height: 16),
        
        // Appearance Section
        _buildSectionTitle(loc.t('settings.appearance')),
        Card(
          child: Column(
            children: [
              // Theme
              ListTile(
                leading: const Icon(Icons.palette),
                title: Text(loc.t('settings.theme')),
                trailing: DropdownButton<ThemeMode>(
                  value: themeProvider.themeMode,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text(loc.t('settings.dark')),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text(loc.t('settings.light')),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text(loc.t('settings.system')),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) themeProvider.setThemeMode(mode);
                  },
                ),
              ),
              const Divider(height: 1),
              // Language
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(loc.t('settings.language')),
                trailing: DropdownButton<String>(
                  value: localeProvider.locale.languageCode,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(value: 'ar', child: Text(loc.t('settings.arabic'))),
                    DropdownMenuItem(value: 'en', child: Text(loc.t('settings.english'))),
                  ],
                  onChanged: (code) {
                    if (code != null) {
                      localeProvider.setLocale(Locale(code));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Security Section
        _buildSectionTitle(loc.t('settings.security')),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications),
                title: Text(loc.t('settings.notifications')),
                value: true,
                onChanged: (value) {},
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: Text(loc.t('settings.biometric_lock')),
                value: false,
                onChanged: (value) {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Data Section
        _buildSectionTitle(loc.t('settings.data')),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(loc.t('settings.scan_history')),
                subtitle: Text('${historyProvider.totalScans} ${loc.t('settings.scans')}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/history'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cleaning_services),
                title: Text(loc.t('settings.clear_cache')),
                onTap: () => _showClearCacheDialog(context, loc),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: AppTheme.error),
                title: Text(loc.t('settings.clear_history'), 
                  style: const TextStyle(color: AppTheme.error)),
                onTap: () => _showClearHistoryDialog(context, loc, historyProvider),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // About Section
        _buildSectionTitle(loc.t('settings.about')),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info),
                title: Text(loc.t('settings.version')),
                trailing: Text('$_version+$_buildNumber', 
                  style: const TextStyle(fontFamily: 'monospace')),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(loc.t('settings.open_source')),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _launchUrl('https://github.com/aircrack-ng/aircrack-ng'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: Text(loc.t('settings.privacy_policy')),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _launchUrl('https://your-app.vercel.app/privacy'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description),
                title: Text(loc.t('settings.terms')),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _launchUrl('https://your-app.vercel.app/terms'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // Footer
        Center(
          child: Column(
            children: [
              Text(
                'NetGuard Pro v$_version',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                'Made with ❤️ using Flutter',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        ),
      ),
    );
  }
  
  Widget _buildPremiumBanner(AppLocalizations loc) {
    return Card(
      color: AppTheme.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: AppTheme.primary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.t('settings.premium_active'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    loc.t('settings.thank_you'),
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPremiumUpgradeCard(AppLocalizations loc, PremiumProvider premium) {
    return Card(
      color: AppTheme.warning.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.warning),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium, color: AppTheme.warning, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loc.t('settings.upgrade_premium'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              loc.t('settings.premium_benefits'),
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => premium.startTrial(),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(loc.t('settings.start_trial')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPurchaseDialog(context, loc, premium),
                    icon: const Icon(Icons.shopping_cart),
                    label: Text(loc.t('settings.buy_now')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showPurchaseDialog(BuildContext context, AppLocalizations loc, PremiumProvider premium) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('settings.upgrade_premium')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _priceOption(loc, '1 Month', '\$2.99', () {}),
            _priceOption(loc, '1 Year', '\$19.99', () {}),
            _priceOption(loc, 'Lifetime', '\$49.99', () {
              premium.purchasePremium();
              Navigator.pop(context);
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel')),
          ),
        ],
      ),
    );
  }
  
  Widget _priceOption(AppLocalizations loc, String period, String price, VoidCallback onTap) {
    return ListTile(
      title: Text(period),
      trailing: Text(price, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }
  
  void _showClearCacheDialog(BuildContext context, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('settings.clear_cache')),
        content: Text(loc.t('settings.clear_cache_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.t('settings.cache_cleared'))),
              );
            },
            child: Text(loc.t('common.confirm')),
          ),
        ],
      ),
    );
  }
  
  void _showClearHistoryDialog(BuildContext context, AppLocalizations loc, HistoryProvider history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('settings.clear_history')),
        content: Text(loc.t('settings.clear_history_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              history.clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.t('settings.history_cleared'))),
              );
            },
            child: Text(loc.t('common.confirm')),
          ),
        ],
      ),
    );
  }
  
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
