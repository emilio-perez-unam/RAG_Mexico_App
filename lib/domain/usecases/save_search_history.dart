import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/search_result.dart';
import '../repositories/legal_search_repository.dart';

/// Use case for saving search history
class SaveSearchHistory {
  final LegalSearchRepository _repository;

  SaveSearchHistory({required LegalSearchRepository repository})
      : _repository = repository;

  /// Execute saving search to history
  Future<Either<Failure, void>> call({
    required String query,
    required List<SearchResult> results,
  }) async {
    return await _repository.saveSearchToHistory(
      query: query,
      results: results,
    );
  }
}