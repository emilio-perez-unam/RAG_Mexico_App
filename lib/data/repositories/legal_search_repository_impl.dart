import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/legal_document.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/legal_search_repository.dart';
import '../datasources/local/search_history_local_datasource.dart';

/// Secure implementation of the LegalSearchRepository.
/// This repository communicates with a Supabase Edge Function to perform RAG searches,
/// ensuring no sensitive credentials or logic are exposed on the client-side.
class LegalSearchRepositoryImpl implements LegalSearchRepository {
  final SupabaseClient _supabaseClient;
  final SearchHistoryLocalDatasource _searchHistoryDatasource;

  LegalSearchRepositoryImpl({
    required SupabaseClient supabaseClient,
    required SearchHistoryLocalDatasource searchHistoryDatasource,
  })  : _supabaseClient = supabaseClient,
        _searchHistoryDatasource = searchHistoryDatasource;

  @override
  Future<Either<Failure, List<SearchResult>>> searchDocuments({
    required String query,
    Map<String, dynamic>? filters,
    int? limit,
  }) async {
    try {
      // Securely call the backend Edge Function to perform the RAG search.
      // The function handles embedding, vector search (Milvus), and response generation.
      final response = await _supabaseClient.functions.invoke(
        'rag-search', // This is the name of your Edge Function on Supabase
        body: {
          'query': query,
          'filters': filters,
          'limit': limit,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to execute search: ${response.data}');
      }

      final List<dynamic> data = response.data['results'];
      final results = data
          .map((item) => SearchResult.fromJson(item as Map<String, dynamic>))
          .toList();

      // Save the successful search to local history
      await _saveSearchToHistory(query, results);

      return Right(results);
    } catch (e) {
      return Left(ServerFailure('Failed to search documents: $e'));
    }
  }

  // --- Local Search History Methods remain the same ---

  @override
  Future<Either<Failure, List<String>>> getSearchSuggestions(
      String partialQuery) async {
    try {
      final history = await _searchHistoryDatasource.getSearchHistory();
      final suggestions = history
          .where((item) =>
              item['query'] is String &&
              (item['query'] as String)
                  .toLowerCase()
                  .contains(partialQuery.toLowerCase()))
          .map((item) => item['query'] as String)
          .toSet()
          .take(10)
          .toList();
      return Right(suggestions);
    } catch (e) {
      return Left(ServerFailure('Failed to get search suggestions: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveSearchToHistory({
    required String query,
    required List<SearchResult> results,
  }) async {
    try {
      await _saveSearchToHistory(query, results);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to save search to history: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getSearchHistory() async {
    try {
      final history = await _searchHistoryDatasource.getSearchHistory();
      return Right(history);
    } catch (e) {
      return Left(ServerFailure('Failed to get search history: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearSearchHistory() async {
    try {
      await _searchHistoryDatasource.clearSearchHistory();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to clear search history: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSearchHistoryItem(String id) async {
    try {
      await _searchHistoryDatasource.deleteSearchHistoryItem(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to delete search history item: $e'));
    }
  }

  // This logic must now live in the backend. The client requests it via the Edge Function.
  @override
  Future<Either<Failure, List<LegalDocument>>> getRelatedDocuments(
      String documentId) async {
    try {
      final response = await _supabaseClient.functions.invoke(
        'get-related-documents',
        body: {'documentId': documentId},
      );

      if (response.status != 200) {
        throw Exception('Failed to get related documents: ${response.data}');
      }

      final List<dynamic> data = response.data['documents'];
      final documents = data
          .map((item) => LegalDocument.fromJson(item as Map<String, dynamic>))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get related documents: $e'));
    }
  }

  // This can still be derived from local history.
  @override
  Future<Either<Failure, List<String>>> getTrendingSearches() async {
    try {
      final history = await _searchHistoryDatasource.getSearchHistory();
      final queryCounts = <String, int>{};
      for (final item in history) {
        final query = item['query'] as String?;
        if (query != null) {
          queryCounts[query] = (queryCounts[query] ?? 0) + 1;
        }
      }
      final sortedQueries = queryCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final trending =
          sortedQueries.take(10).map((entry) => entry.key).toList();
      return Right(trending);
    } catch (e) {
      return Left(ServerFailure('Failed to get trending searches: $e'));
    }
  }

  /// Save search to local history
  Future<void> _saveSearchToHistory(
      String query, List<SearchResult> results) async {
    final searchData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'query': query,
      'timestamp': DateTime.now().toIso8601String(),
      'resultsCount': results.length,
      'results': results.map((r) => r.toJson()).toList(),
    };
    await _searchHistoryDatasource.saveSearchHistory(searchData);
  }
}
