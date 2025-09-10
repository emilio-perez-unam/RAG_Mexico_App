import 'package:hive_flutter/hive_flutter.dart';

/// Local datasource for managing search history
abstract class SearchHistoryLocalDatasource {
  Future<List<Map<String, dynamic>>> getSearchHistory();
  Future<void> saveSearchHistory(Map<String, dynamic> searchData);
  Future<void> clearSearchHistory();
  Future<void> deleteSearchHistoryItem(String id);
}

/// Implementation of SearchHistoryLocalDatasource using Hive
class SearchHistoryLocalDatasourceImpl implements SearchHistoryLocalDatasource {
  static const String _boxName = 'search_history';
  
  @override
  Future<List<Map<String, dynamic>>> getSearchHistory() async {
    final box = await Hive.openBox<Map>(_boxName);
    return box.values
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<void> saveSearchHistory(Map<String, dynamic> searchData) async {
    final box = await Hive.openBox<Map>(_boxName);
    await box.add(searchData);
    
    // Keep only last 100 searches
    if (box.length > 100) {
      await box.deleteAt(0);
    }
  }

  @override
  Future<void> clearSearchHistory() async {
    final box = await Hive.openBox<Map>(_boxName);
    await box.clear();
  }

  @override
  Future<void> deleteSearchHistoryItem(String id) async {
    final box = await Hive.openBox<Map>(_boxName);
    final keys = box.keys.toList();
    for (var key in keys) {
      final item = box.get(key);
      if (item?['id'] == id) {
        await box.delete(key);
        break;
      }
    }
  }
}