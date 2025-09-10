import 'package:shared_preferences/shared_preferences.dart';

/// Local datasource for managing application settings
abstract class SettingsLocalDatasource {
  Future<Map<String, dynamic>> getSettings();
  Future<void> saveSettings(Map<String, dynamic> settings);
  Future<void> saveSetting(String key, dynamic value);
  Future<dynamic> getSetting(String key);
  Future<void> clearSettings();
}

/// Implementation of SettingsLocalDatasource using SharedPreferences
class SettingsLocalDatasourceImpl implements SettingsLocalDatasource {
  final SharedPreferences _prefs;

  SettingsLocalDatasourceImpl(this._prefs);

  @override
  Future<Map<String, dynamic>> getSettings() async {
    final settings = <String, dynamic>{};
    final keys = _prefs.getKeys();
    
    for (final key in keys) {
      settings[key] = _prefs.get(key);
    }
    
    return settings;
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    for (final entry in settings.entries) {
      await saveSetting(entry.key, entry.value);
    }
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(key, value);
    }
  }

  @override
  Future<dynamic> getSetting(String key) async {
    return _prefs.get(key);
  }

  @override
  Future<void> clearSettings() async {
    await _prefs.clear();
  }
}