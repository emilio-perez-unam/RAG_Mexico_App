import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/local/settings_local_datasource.dart';

/// Implementation of SettingsRepository
class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDatasource _settingsLocalDatasource;

  SettingsRepositoryImpl({
    required SettingsLocalDatasource settingsLocalDatasource,
  }) : _settingsLocalDatasource = settingsLocalDatasource;

  @override
  Future<Either<Failure, Map<String, dynamic>>> getSettings() async {
    try {
      final settings = await _settingsLocalDatasource.getSettings();
      return Right(settings);
    } catch (e) {
      return Left(CacheFailure('Failed to get settings: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveSettings(Map<String, dynamic> settings) async {
    try {
      await _settingsLocalDatasource.saveSettings(settings);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to save settings: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveSetting(String key, dynamic value) async {
    try {
      await _settingsLocalDatasource.saveSetting(key, value);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to save setting: $e'));
    }
  }

  @override
  Future<Either<Failure, dynamic>> getSetting(String key) async {
    try {
      final value = await _settingsLocalDatasource.getSetting(key);
      return Right(value);
    } catch (e) {
      return Left(CacheFailure('Failed to get setting: $e'));
    }
  }

  Future<Either<Failure, void>> clearSettings() async {
    try {
      await _settingsLocalDatasource.clearSettings();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to clear settings: $e'));
    }
  }

  Future<Either<Failure, void>> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _settingsLocalDatasource.saveSettings(settings);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to update settings: $e'));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> getAllSettings() async {
    try {
      final settings = await _settingsLocalDatasource.getSettings();
      return Right(settings);
    } catch (e) {
      return Left(CacheFailure('Failed to get all settings: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> resetSettings() async {
    try {
      await _settingsLocalDatasource.clearSettings();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to reset settings: $e'));
    }
  }

  Future<Either<Failure, bool>> hasSetting(String key) async {
    try {
      final settings = await _settingsLocalDatasource.getSettings();
      return Right(settings.containsKey(key));
    } catch (e) {
      return Left(CacheFailure('Failed to check setting existence: $e'));
    }
  }

  Future<Either<Failure, void>> removeSetting(String key) async {
    try {
      await _settingsLocalDatasource.saveSetting(key, null);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to remove setting: $e'));
    }
  }

  Future<Either<Failure, List<String>>> getSettingKeys() async {
    try {
      final settings = await _settingsLocalDatasource.getSettings();
      return Right(settings.keys.toList());
    } catch (e) {
      return Left(CacheFailure('Failed to get setting keys: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> getThemePreference() async {
    try {
      final theme = await _settingsLocalDatasource.getSetting('theme');
      return Right(theme as String? ?? 'light');
    } catch (e) {
      return Left(CacheFailure('Failed to get theme preference: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveThemePreference(String theme) async {
    try {
      await _settingsLocalDatasource.saveSetting('theme', theme);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to save theme preference: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> getLanguagePreference() async {
    try {
      final language = await _settingsLocalDatasource.getSetting('language');
      return Right(language as String? ?? 'en');
    } catch (e) {
      return Left(CacheFailure('Failed to get language preference: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveLanguagePreference(String language) async {
    try {
      await _settingsLocalDatasource.saveSetting('language', language);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to save language preference: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, bool>>> getNotificationSettings() async {
    try {
      final notifications = await _settingsLocalDatasource.getSetting('notifications');
      if (notifications == null) {
        // Return default notification settings
        return const Right({
          'enabled': true,
          'pushNotifications': true,
          'emailNotifications': false,
          'smsNotifications': false,
        });
      }
      return Right(Map<String, bool>.from(notifications as Map));
    } catch (e) {
      return Left(CacheFailure('Failed to get notification settings: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveNotificationSettings(Map<String, bool> settings) async {
    try {
      await _settingsLocalDatasource.saveSetting('notifications', settings);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to save notification settings: $e'));
    }
  }
}