import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/usecases/update_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Settings state enum
enum SettingsStatus {
  initial,
  loading,
  success,
  error,
}

/// Settings provider for managing application settings
class SettingsProvider extends ChangeNotifier {
  final UpdateSettings _updateSettings;
  final SettingsRepository _settingsRepository;

  SettingsStatus _status = SettingsStatus.initial;
  Map<String, dynamic> _settings = {};
  String? _errorMessage;

  SettingsProvider({
    required UpdateSettings updateSettings,
    required SettingsRepository settingsRepository,
  })  : _updateSettings = updateSettings,
        _settingsRepository = settingsRepository;

  // Getters
  SettingsStatus get status => _status;
  Map<String, dynamic> get settings => Map.unmodifiable(_settings);
  String? get errorMessage => _errorMessage;

  /// Load settings from repository
  Future<void> loadSettings() async {
    try {
      _status = SettingsStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _settingsRepository.getSettings();
      
      result.fold(
        (failure) {
          _status = SettingsStatus.error;
          _errorMessage = _mapFailureToMessage(failure);
        },
        (settings) {
          _settings = settings;
          _status = SettingsStatus.success;
        },
      );

      notifyListeners();
    } catch (e) {
      _status = SettingsStatus.error;
      _errorMessage = 'Unexpected error: $e';
      notifyListeners();
    }
  }

  /// Update settings
  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    try {
      _status = SettingsStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _updateSettings(settings: newSettings);
      
      result.fold(
        (failure) {
          _status = SettingsStatus.error;
          _errorMessage = _mapFailureToMessage(failure);
        },
        (_) {
          // Merge new settings with existing ones
          _settings = Map<String, dynamic>.from(_settings)..addAll(newSettings);
          _status = SettingsStatus.success;
        },
      );

      notifyListeners();
    } catch (e) {
      _status = SettingsStatus.error;
      _errorMessage = 'Unexpected error: $e';
      notifyListeners();
    }
  }

  /// Update a single setting
  Future<void> updateSetting(String key, dynamic value) async {
    final newSettings = Map<String, dynamic>.from(_settings);
    newSettings[key] = value;
    await updateSettings(newSettings);
  }

  /// Get a setting value with a default
  T getSetting<T>(String key, T defaultValue) {
    try {
      final value = _settings[key];
      if (value is T) {
        return value;
      }
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Reset all settings to defaults
  Future<void> resetSettings() async {
    try {
      _status = SettingsStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _settingsRepository.resetSettings();
      
      result.fold(
        (failure) {
          _status = SettingsStatus.error;
          _errorMessage = _mapFailureToMessage(failure);
        },
        (_) {
          _settings = {};
          _status = SettingsStatus.success;
        },
      );

      notifyListeners();
    } catch (e) {
      _status = SettingsStatus.error;
      _errorMessage = 'Unexpected error: $e';
      notifyListeners();
    }
  }

  /// Map failure to user-friendly message
  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return 'Server error. Please try again later.';
      case CacheFailure:
        return 'Cache error. Please try again.';
      case NetworkFailure:
        return 'Network error. Please check your connection.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Check if a setting exists
  bool hasSetting(String key) {
    return _settings.containsKey(key);
  }

  /// Remove a setting
  Future<void> removeSetting(String key) async {
    if (_settings.containsKey(key)) {
      final newSettings = Map<String, dynamic>.from(_settings);
      newSettings.remove(key);
      await updateSettings(newSettings);
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Get all settings as JSON
  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(_settings);
  }

  /// Load settings from JSON
  Future<void> fromJson(Map<String, dynamic> json) async {
    await updateSettings(json);
  }
}