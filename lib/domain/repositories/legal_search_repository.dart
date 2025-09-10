import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/legal_document.dart';
import '../entities/search_result.dart';

/// Repository interface for legal document search operations
abstract class LegalSearchRepository {
  /// Search for legal documents using RAG
  Future<Either<Failure, List<SearchResult>>> searchDocuments({
    required String query,
    Map<String, dynamic>? filters,
    int? limit,
  });

  /// Get search suggestions based on partial query
  Future<Either<Failure, List<String>>> getSearchSuggestions(String partialQuery);

  /// Save a search query to history
  Future<Either<Failure, void>> saveSearchToHistory({
    required String query,
    required List<SearchResult> results,
  });

  /// Get search history
  Future<Either<Failure, List<Map<String, dynamic>>>> getSearchHistory();

  /// Clear search history
  Future<Either<Failure, void>> clearSearchHistory();

  /// Delete a specific search history item
  Future<Either<Failure, void>> deleteSearchHistoryItem(String id);

  /// Get related documents
  Future<Either<Failure, List<LegalDocument>>> getRelatedDocuments(String documentId);

  /// Get trending searches
  Future<Either<Failure, List<String>>> getTrendingSearches();
}