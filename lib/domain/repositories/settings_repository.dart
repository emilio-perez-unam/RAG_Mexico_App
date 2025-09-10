import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';

/// Repository interface for application settings
abstract class SettingsRepository {
  /// Get all settings
  Future<Either<Failure, Map<String, dynamic>>> getSettings();

  /// Save all settings
  Future<Either<Failure, void>> saveSettings(Map<String, dynamic> settings);

  /// Get a specific setting
  Future<Either<Failure, dynamic>> getSetting(String key);

  /// Save a specific setting
  Future<Either<Failure, void>> saveSetting(String key, dynamic value);

  /// Reset settings to defaults
  Future<Either<Failure, void>> resetSettings();

  /// Get theme preference
  Future<Either<Failure, String>> getThemePreference();

  /// Save theme preference
  Future<Either<Failure, void>> saveThemePreference(String theme);

  /// Get language preference
  Future<Either<Failure, String>> getLanguagePreference();

  /// Save language preference
  Future<Either<Failure, void>> saveLanguagePreference(String language);

  /// Get notification settings
  Future<Either<Failure, Map<String, bool>>> getNotificationSettings();

  /// Save notification settings
  Future<Either<Failure, void>> saveNotificationSettings(Map<String, bool> settings);
}