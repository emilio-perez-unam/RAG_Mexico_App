import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../repositories/settings_repository.dart';

/// Use case for updating settings
class UpdateSettings {
  final SettingsRepository _repository;

  UpdateSettings({required SettingsRepository repository})
      : _repository = repository;

  /// Execute updating settings
  Future<Either<Failure, void>> call({
    required Map<String, dynamic> settings,
  }) async {
    return await _repository.saveSettings(settings);
  }
}