import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/ads_service.dart';
import '../widgets/ad_banner_widget.dart';
import '../utils/theme.dart';
import 'dashboard_screen.dart';
import 'port_scanner_screen.dart';
import 'wps_calculator_screen.dart';
import 'password_analyzer_screen.dart';
import 'cve_database_screen.dart';
import 'router_detector_screen.dart';
import 'signal_analyzer_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import 'advanced/network_map_screen.dart';
import 'advanced/dns_lookup_screen.dart';
import 'advanced/ping_screen.dart';
import 'advanced/ssl_scanner_screen.dart';
import 'advanced/speed_test_screen.dart';
import 'security/leak_detection_screen.dart';
import 'security/ids_monitor_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String _currentTitle = '';

  final List<_NavItem> _screens = [
    _NavItem('dashboard', const DashboardScreen(), Icons.dashboard),
    _NavItem('wps', const WPSCalculatorScreen(), Icons.calculate),
    _NavItem('ports', const PortScannerScreen(), Icons.lock),
    _NavItem('password', const PasswordAnalyzerScreen(), Icons.key),
    _NavItem('cve', const CVEDatabaseScreen(), Icons.bug_report),
    _NavItem('router', const RouterDetectorScreen(), Icons.router),
    _NavItem('network_map', const NetworkMapScreen(), Icons.hub),
    _NavItem('speed_test', const SpeedTestScreen(), Icons.speed),
    _NavItem('dns', const DnsLookupScreen(), Icons.dns),
    _NavItem('ping', const PingScreen(), Icons.network_ping),
    _NavItem('ssl', const SslScannerScreen(), Icons.https),
    _NavItem('signal', const SignalAnalyzerScreen(), Icons.wifi),
    _NavItem('report', const ReportScreen(), Icons.assessment),
    _NavItem('leaks', const LeakDetectionScreen(), Icons.shield),
    _NavItem('ids', const IdsMonitorScreen(), Icons.security),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProvider = Provider.of<LocaleProvider>(context);
    
    // تحديث الـ title بناءً على الشاشة الحالية
    final currentScreen = _screens[_currentIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.t('app_name'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    loc.t('app_tagline'),
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => localeProvider.toggleLocale(),
            tooltip: loc.t('common.language'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.pushNamed(context, '/settings');
              } else if (value == 'history') {
                Navigator.pushNamed(context, '/history');
              } else if (value == 'remove_ads') {
                _showRemoveAdsDialog(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 18),
                    const SizedBox(width: 8),
                    Text(loc.t('settings.scan_history')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings, size: 18),
                    const SizedBox(width: 8),
                    Text(loc.t('settings.appearance')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'remove_ads',
                child: Row(
                  children: [
                    const Icon(Icons.block, size: 18),
                    const SizedBox(width: 8),
                    Text(loc.t('ads.remove_ads')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Banner Ad
          const AdBannerWidget(),
          // Legal Warning
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: AppTheme.warning, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    loc.t('legal.warning'),
                    style: const TextStyle(fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: currentScreen.screen,
          ),
          // Bottom Banner Ad
          const AdBannerWidget(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex > 4 ? 0 : _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          AdsService.showInterstitial(onComplete: () {});
          setState(() => _currentIndex = index);
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.dashboard), label: loc.t('nav.dashboard')),
          BottomNavigationBarItem(icon: const Icon(Icons.calculate), label: loc.t('nav.wps')),
          BottomNavigationBarItem(icon: const Icon(Icons.lock), label: loc.t('nav.ports')),
          BottomNavigationBarItem(icon: const Icon(Icons.key), label: loc.t('nav.password')),
          BottomNavigationBarItem(icon: const Icon(Icons.bug_report), label: loc.t('nav.cve')),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield, size: 48, color: Colors.black),
                  const SizedBox(height: 8),
                  Text(
                    loc.t('app_name'),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'v3.0.0 - Advanced',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // كل الشاشات
            ...(_screens.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildDrawerItem(loc, item.icon, _getScreenTitle(loc, item.id), index);
            }).toList()),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(loc.t('settings.scan_history')),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/history');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(loc.t('settings.appearance')),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(AppLocalizations loc, IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(
        icon,
        color: _currentIndex == index ? AppTheme.primary : AppTheme.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: _currentIndex == index ? AppTheme.primary : AppTheme.textPrimary,
          fontWeight: _currentIndex == index ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      selected: _currentIndex == index,
      selectedTileColor: AppTheme.primary.withOpacity(0.1),
      onTap: () {
        Navigator.pop(context);
        AdsService.showInterstitial(onComplete: () {});
        setState(() => _currentIndex = index);
      },
    );
  }

  String _getScreenTitle(AppLocalizations loc, String id) {
    switch (id) {
      case 'dashboard': return loc.t('nav.dashboard');
      case 'wps': return loc.t('nav.wps');
      case 'ports': return loc.t('nav.ports');
      case 'password': return loc.t('nav.password');
      case 'cve': return loc.t('nav.cve');
      case 'router': return loc.t('nav.router');
      case 'network_map': return loc.t('nav.devices');
      case 'speed_test': return 'Speed Test';
      case 'dns': return 'DNS Lookup';
      case 'ping': return 'Ping & Traceroute';
      case 'ssl': return 'SSL Scanner';
      case 'signal': return loc.t('nav.signal');
      case 'report': return loc.t('nav.report');
      case 'leaks': return 'Leak Detection';
      case 'ids': return 'IDS Monitor';
      default: return id;
    }
  }

  void _showRemoveAdsDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('ads.remove_ads')),
        content: Text(
          'Watch a rewarded ad to remove all ads for 24 hours, '
          'or upgrade to Premium for permanent ad removal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              AdsService.showRewardedAd(
                onReward: () async {
                  await AdsService.removeAds();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ads removed successfully!')),
                  );
                },
                onComplete: () {},
              );
            },
            child: const Text('Watch Ad'),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String id;
  final Widget screen;
  final IconData icon;
  
  _NavItem(this.id, this.screen, this.icon);
}
