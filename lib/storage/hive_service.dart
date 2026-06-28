import 'package:netguard_pro/providers/history_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HiveService {
  static const String _historyBox = 'scan_history';
  static const String _historyKey = 'history_items';
  static const String _favoritesBox = 'favorites';
  static const String _settingsBox = 'settings';
  
  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(_historyBox);
    await Hive.openBox(_favoritesBox);
    await Hive.openBox(_settingsBox);
  }
  
  // ===== Scan History =====
  Future<List<Map<String, dynamic>>> getRawScanHistory() async {
    final box = Hive.box(_historyBox);
    final data = box.get(_historyKey) as String?;
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = json.decode(data);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
  
  Future<List<ScanHistoryItem>> getScanHistory() async {
    final rawItems = await getRawScanHistory();
    return rawItems.map((json) => ScanHistoryItem.fromJson(json)).toList();
  }
  
  Future<void> saveScanHistory(List<ScanHistoryItem> items) async {
    final box = Hive.box(_historyBox);
    final jsonList = items.map((item) => item.toJson()).toList();
    await box.put(_historyKey, json.encode(jsonList));
  }
  
  Future<void> clearScanHistory() async {
    final box = Hive.box(_historyBox);
    await box.delete(_historyKey);
  }
  
  // ===== Favorites =====
  Future<List<String>> getFavorites() async {
    final box = Hive.box(_favoritesBox);
    final data = box.get('favorite_macs') as String?;
    if (data == null) return [];
    try {
      return List<String>.from(json.decode(data));
    } catch (e) {
      return [];
    }
  }
  
  Future<void> toggleFavorite(String mac) async {
    final favorites = await getFavorites();
    if (favorites.contains(mac)) {
      favorites.remove(mac);
    } else {
      favorites.add(mac);
    }
    final box = Hive.box(_favoritesBox);
    await box.put('favorite_macs', json.encode(favorites));
  }
  
  // ===== Settings =====
  Future<String?> getSetting(String key) async {
    final box = Hive.box(_settingsBox);
    return box.get(key) as String?;
  }
  
  Future<void> setSetting(String key, String value) async {
    final box = Hive.box(_settingsBox);
    await box.put(key, value);
  }
  
  // ===== Cache =====
  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    final box = Hive.box(_settingsBox);
    final cacheEntry = {
      'data': json.encode(data),
      'timestamp': DateTime.now().toIso8601String(),
    };
    await box.put('cache_$key', json.encode(cacheEntry));
  }
  
  Future<Map<String, dynamic>?> getCachedData(String key, {Duration? maxAge}) async {
    final box = Hive.box(_settingsBox);
    final raw = box.get('cache_$key') as String?;
    if (raw == null) return null;
    
    try {
      final cacheEntry = json.decode(raw) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheEntry['timestamp']);
      
      // تحقق من عمر الكاش
      if (maxAge != null && DateTime.now().difference(timestamp) > maxAge) {
        return null;
      }
      
      return json.decode(cacheEntry['data']) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
  
  Future<void> clearCache() async {
    final box = Hive.box(_settingsBox);
    final keys = box.keys.where((key) => key.toString().startsWith('cache_'));
    for (final key in keys) {
      await box.delete(key);
    }
  }
  
  // ===== Statistics =====
  Future<Map<String, int>> getStats() async {
    final history = await getScanHistory();
    final stats = <String, int>{};
    for (final item in history) {
      stats[item.type] = (stats[item.type] ?? 0) + 1;
    }
    return stats;
  }
}

// import مبكر لـ ScanHistoryItem
