import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:netguard_pro/services/ads_service.dart';
import 'package:netguard_pro/l10n/app_localizations.dart';
import 'package:netguard_pro/utils/theme.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (AdsService.adsRemoved) return;
    
    _bannerAd = AdsService.createBannerAd()
      ..load()
      ..then((_) {
        setState(() {
          _isLoaded = true;
        });
      });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdsService.adsRemoved) {
      return const SizedBox.shrink();
    }

    final loc = AppLocalizations.of(context)!;
    
    if (!_isLoaded || _bannerAd == null) {
      // Placeholder أثناء التحميل
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.2),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Text(
                loc.t('ads.sponsored'),
                style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                'Ad Space',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
