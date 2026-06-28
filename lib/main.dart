import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'utils/theme.dart';
import 'storage/hive_service.dart';
import 'services/ads_service.dart';
import 'providers/theme_provider.dart';
import 'providers/premium_provider.dart';
import 'providers/history_provider.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive database
  await HiveService.initialize();
  
  // Initialize Ads
  await AdsService.initialize();
  AdsService.loadInterstitial();
  AdsService.loadRewardedAd();
  
  // Check first launch
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('first_launch') ?? true;
  
  runApp(NetGuardProApp(isFirstLaunch: isFirstLaunch));
}

class NetGuardProApp extends StatelessWidget {
  final bool isFirstLaunch;

  const NetGuardProApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => PremiumProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) {
          return MaterialApp(
            title: 'NetGuard Pro',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            
            // Localization
            locale: localeProvider.locale,
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            
            // RTL/LTR
            builder: (context, child) {
              return Directionality(
                textDirection: localeProvider.isRTL 
                    ? TextDirection.rtl 
                    : TextDirection.ltr,
                child: child!,
              );
            },
            
            // Routes
            initialRoute: isFirstLaunch ? '/onboarding' : '/',
            routes: {
              '/': (context) => const MainScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/history': (context) => const HistoryScreen(),
            },
          );
        },
      ),
    );
  }
}
