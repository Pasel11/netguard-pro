import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  // ===== Google AdMob IDs =====
  // استبدل هذه بمعرّفاتك من https://apps.admob.com
  static const String _admobAppId = 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX';
  static const String _admobBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _admobInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _admobRewardedId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  
  // ===== Unity Ads IDs =====
  // استبدل هذه من https://dashboard.unity3d.com
  static const String _unityGameId = 'XXXXXXXXXX';
  static const String _unityBannerPlacement = 'Banner_Ad';
  static const String _unityInterstitialPlacement = 'Interstitial_Ad';
  static const String _unityRewardedPlacement = 'Rewarded_Ad';
  
  static bool _initialized = false;
  static bool _adsRemoved = false;
  
  // ===== Initialization =====
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Initialize Google Mobile Ads
      await MobileAds.instance.initialize();
      
      // Unity Ads removed - not available on pub.dev
      
      _initialized = true;
    } catch (e) {
      debugPrint('Ads initialization failed: $e');
    }
  }
  
  // ===== Remove Ads (Premium Feature) =====
  static Future<void> removeAds() async {
    _adsRemoved = true;
    // هنا تقدر تربطها بـ in-app purchase
  }
  
  static bool get adsRemoved => _adsRemoved;
  
  // ===== Banner Ad =====
  static BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: _admobBannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => debugPrint('Banner ad loaded'),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner ad failed: $error');
        },
      ),
    );
  }
  
  // ===== Interstitial Ad =====
  static InterstitialAd? _interstitialAd;
  static int _interstitialLoadCount = 0;
  
  static void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _admobInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }
  
  static void showInterstitial({required Function onComplete}) {
    if (_adsRemoved) {
      onComplete();
      return;
    }
    
    _interstitialLoadCount++;
    // Show interstitial every 5 actions
    if (_interstitialLoadCount % 5 != 0) {
      onComplete();
      return;
    }
    
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadInterstitial();
          onComplete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          onComplete();
        },
      );
      _interstitialAd!.show();
    } else {
      // Try Unity Ads interstitial
      // Unity Ads removed
        placementId: _unityInterstitialPlacement,
        onComplete: (placementId) => onComplete(),
        onSkipped: (placementId) => onComplete(),
        onFailed: (placementId, error, message) => onComplete(),
      );
    }
  }
  
  // ===== Rewarded Ad =====
  static RewardedAd? _rewardedAd;
  
  static void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _admobRewardedId,
      request: const AdRequest(),
      adLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) => _rewardedAd = null,
      ),
    );
  }
  
  static void showRewardedAd({
    required Function onReward,
    required Function onComplete,
  }) {
    if (_adsRemoved) {
      onReward();
      onComplete();
      return;
    }
    
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadRewardedAd();
          onComplete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          onComplete();
        },
      );
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        onReward();
      });
    } else {
      // Try Unity Ads rewarded
      // Unity Ads removed
        placementId: _unityRewardedPlacement,
        onComplete: (placementId) {
          onReward();
          onComplete();
        },
        onSkipped: (placementId) => onComplete(),
        onFailed: (placementId, error, message) => onComplete(),
      );
    }
  }
}
