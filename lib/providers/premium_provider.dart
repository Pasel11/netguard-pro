import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumProvider extends ChangeNotifier {
  static const String _prefsKey = 'is_premium';
  static const String _trialKey = 'trial_expiry';
  static const String _removeAdsKey = 'remove_ads_until';
  
  bool _isPremium = false;
  DateTime? _trialExpiry;
  DateTime? _removeAdsUntil;
  
  bool get isPremium => _isPremium;
  bool get isTrialActive => _trialExpiry != null && _trialExpiry!.isAfter(DateTime.now());
  bool get hasAdsRemoved => _isPremium || 
      (_removeAdsUntil != null && _removeAdsUntil!.isAfter(DateTime.now()));
  
  PremiumProvider() {
    _loadState();
  }
  
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_prefsKey) ?? false;
    
    final trialStr = prefs.getString(_trialKey);
    if (trialStr != null) {
      _trialExpiry = DateTime.tryParse(trialStr);
    }
    
    final adsStr = prefs.getString(_removeAdsKey);
    if (adsStr != null) {
      _removeAdsUntil = DateTime.tryParse(adsStr);
    }
    
    notifyListeners();
  }
  
  Future<void> purchasePremium() async {
    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    notifyListeners();
  }
  
  Future<void> startTrial() async {
    _trialExpiry = DateTime.now().add(const Duration(days: 7));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trialKey, _trialExpiry!.toIso8601String());
    notifyListeners();
  }
  
  Future<void> removeAdsFor24Hours() async {
    _removeAdsUntil = DateTime.now().add(const Duration(hours: 24));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_removeAdsKey, _removeAdsUntil!.toIso8601String());
    notifyListeners();
  }
  
  // فحوصات متقدمة للمستخدمين Premium
  bool canUseAdvancedScan() => _isPremium || isTrialActive;
  bool canUseUnlimitedScans() => _isPremium;
  bool canGenerateDetailedPDF() => _isPremium || isTrialActive;
  
  int get trialDaysLeft {
    if (_trialExpiry == null) return 0;
    final diff = _trialExpiry!.difference(DateTime.now());
    return diff.inDays > 0 ? diff.inDays : 0;
  }
}
