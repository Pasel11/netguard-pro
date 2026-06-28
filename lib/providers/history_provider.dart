import 'package:flutter/foundation.dart';
import 'package:netguard_pro/storage/hive_service.dart';

class ScanHistoryItem {
  final String id;
  final String type; // 'port', 'wps', 'password', 'cve', 'router', 'signal'
  final String title;
  final String target;
  final int score;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  ScanHistoryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.target,
    required this.score,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'target': target,
    'score': score,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      target: json['target'] ?? '',
      score: json['score'] ?? 0,
      data: json['data'] ?? {},
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

class HistoryProvider extends ChangeNotifier {
  final HiveService _hiveService = HiveService();
  List<ScanHistoryItem> _items = [];
  
  List<ScanHistoryItem> get items => _items.reversed.toList();
  List<ScanHistoryItem> get byType => _items;
  
  HistoryProvider() {
    _loadHistory();
  }
  
  Future<void> _loadHistory() async {
    _items = await _hiveService.getScanHistory();
    notifyListeners();
  }
  
  Future<void> addScan(ScanHistoryItem item) async {
    _items.add(item);
    // نحتفظ بآخر 100 فحص فقط
    if (_items.length > 100) {
      _items.removeAt(0);
    }
    await _hiveService.saveScanHistory(_items);
    notifyListeners();
  }
  
  Future<void> clearHistory() async {
    _items.clear();
    await _hiveService.clearScanHistory();
    notifyListeners();
  }
  
  Future<void> deleteItem(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _hiveService.saveScanHistory(_items);
    notifyListeners();
  }
  
  List<ScanHistoryItem> getByType(String type) {
    return _items.where((item) => item.type == type).toList();
  }
  
  int get totalScans => _items.length;
  int get averageScore {
    if (_items.isEmpty) return 0;
    return _items.fold(0, (sum, item) => sum + item.score) ~/ _items.length;
  }
}
