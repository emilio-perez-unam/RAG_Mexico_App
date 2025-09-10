import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/search_result.dart';
import '../repositories/legal_search_repository.dart';

/// Use case for searching legal documents
class SearchLegalDocuments {
  final LegalSearchRepository _repository;

  SearchLegalDocuments({required LegalSearchRepository repository})
      : _repository = repository;

  /// Execute the search for legal documents
  Future<Either<Failure, List<SearchResult>>> call({
    required String query,
    Map<String, dynamic>? filters,
    int? limit,
  }) async {
    return await _repository.searchDocuments(
      query: query,
      filters: filters,
      limit: limit,
    );
  }
}