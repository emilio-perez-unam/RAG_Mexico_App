import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/usecases/search_legal_documents.dart';
import '../../domain/usecases/save_search_history.dart';

/// Search state enum
enum SearchStatus {
  initial,
  loading,
  success,
  error,
}

/// Search provider for managing search state
class SearchProvider extends ChangeNotifier {
  final SearchLegalDocuments _searchLegalDocuments;
  final SaveSearchHistory _saveSearchHistory;

  SearchStatus _status = SearchStatus.initial;
  List<SearchResult> _results = [];
  String? _errorMessage;
  bool _isLoadingMore = false;

  SearchProvider({
    required SearchLegalDocuments searchLegalDocuments,
    required SaveSearchHistory saveSearchHistory,
  })  : _searchLegalDocuments = searchLegalDocuments,
        _saveSearchHistory = saveSearchHistory;

  // Getters
  SearchStatus get status => _status;
  List<SearchResult> get results => List.unmodifiable(_results);
  String? get errorMessage => _errorMessage;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasResults => _results.isNotEmpty;

  /// Search for legal documents
  Future<void> searchDocuments({
    required String query,
    Map<String, dynamic>? filters,
    int? limit,
  }) async {
    try {
      _status = SearchStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _searchLegalDocuments(
        query: query,
        filters: filters,
        limit: limit,
      );

      result.fold(
        (failure) {
          _status = SearchStatus.error;
          _errorMessage = _mapFailureToMessage(failure);
        },
        (searchResults) {
          _results = searchResults;
          _status = SearchStatus.success;
          
          // Save to history
          _saveSearchToHistory(query, searchResults);
        },
      );

      notifyListeners();
    } catch (e) {
      _status = SearchStatus.error;
      _errorMessage = 'Unexpected error: $e';
      notifyListeners();
    }
  }

  /// Load more search results
  Future<void> loadMoreResults({
    required String query,
    Map<String, dynamic>? filters,
    int? limit,
  }) async {
    if (_isLoadingMore || _status != SearchStatus.success) return;

    try {
      _isLoadingMore = true;
      notifyListeners();

      final result = await _searchLegalDocuments(
        query: query,
        filters: filters,
        limit: limit,
      );

      result.fold(
        (failure) {
          _errorMessage = _mapFailureToMessage(failure);
        },
        (searchResults) {
          _results = List.of(_results)..addAll(searchResults);
        },
      );

      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      _errorMessage = 'Unexpected error: $e';
      notifyListeners();
    }
  }

  /// Clear search results
  void clearResults() {
    _results = [];
    _status = SearchStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }

  /// Save search to history
  Future<void> _saveSearchToHistory(String query, List<SearchResult> results) async {
    try {
      await _saveSearchHistory(query: query, results: results);
    } catch (e) {
      debugPrint('Failed to save search to history: $e');
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

  /// Get search result by ID
  SearchResult? getResultById(String id) {
    try {
      return _results.firstWhere((result) => result.document.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get top search results
  List<SearchResult> getTopResults(int count) {
    return _results.take(count).toList();
  }

  /// Get results by relevance score threshold
  List<SearchResult> getResultsAboveThreshold(double threshold) {
    return _results.where((result) => result.relevanceScore >= threshold).toList();
  }

  /// Sort results by relevance
  void sortResultsByRelevance() {
    _results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    notifyListeners();
  }

  /// Sort results by title
  void sortResultsByTitle() {
    _results.sort((a, b) => a.document.title.compareTo(b.document.title));
    notifyListeners();
  }

  /// Filter results by keyword
  List<SearchResult> filterResultsByKeyword(String keyword) {
    return _results
        .where((result) =>
            result.document.title.toLowerCase().contains(keyword.toLowerCase()) ||
            result.snippet.toLowerCase().contains(keyword.toLowerCase()))
        .toList();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}