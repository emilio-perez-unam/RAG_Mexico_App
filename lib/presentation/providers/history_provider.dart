import 'package:flutter/foundation.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/legal_search_repository.dart';

/// History state enum
enum HistoryStatus {
  initial,
  loading,
  success,
  error,
}

/// History provider for managing search history
class HistoryProvider extends ChangeNotifier {
  final LegalSearchRepository _legalSearchRepository;

  HistoryStatus _status = HistoryStatus.initial;
  List<Map<String, dynamic>> _history = [];
  String? _errorMessage;

  HistoryProvider({
    required LegalSearchRepository legalSearchRepository,
  }) : _legalSearchRepository = legalSearchRepository;

  // Getters
  HistoryStatus get status => _status;
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);
  String? get errorMessage => _errorMessage;
  bool get hasHistory => _history.isNotEmpty;

  /// Load search history
  Future<void> loadHistory() async {
    try {
      _status = HistoryStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _legalSearchRepository.getSearchHistory();
      
      result.fold(
        (failure) {
          _status = HistoryStatus.error;
          _errorMessage = _mapFailureToMessage(failure);
        },
        (history) {
          _history = history;
          _status = HistoryStatus.success;
        },
      );

      notifyListeners();
    } catch (e) {
      _status = HistoryStatus.error;
      _errorMessage = 'Unexpected error: $e';
      notifyListeners();
    }
  }

  /// Clear search history
  Future<void> clearHistory() async {
    try {
      _status = HistoryStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _legalSearchRepository.clearSearchHistory();
      
      result.fold(
        (failure) {
          _status = HistoryStatus.error;
          _errorMessage = _mapFailureToMessage(failure);
        },
        (_) {
          _history = [];
          _status = HistoryStatus.success;
        },
      );

      notifyListeners();
    } catch (e) {
      _status = HistoryStatus.error;
      _errorMessage = 'Unexpected error: $e';
      notifyListeners();
    }
  }

  /// Delete a specific history item
  Future<void> deleteHistoryItem(String id) async {
    try {
      _status = HistoryStatus.loading;
      _errorMessage = null;
      notifyListeners();

      // Find and remove the item from local history first
      final itemIndex = _history.indexWhere((item) => item['id'] == id);
      if (itemIndex != -1) {
        final newHistory = List<Map<String, dynamic>>.from(_history);
        newHistory.removeAt(itemIndex);
        _history = newHistory;
        notifyListeners();
      }

      // Then delete from repository
      final result = await _legalSearchRepository.deleteSearchHistoryItem(id);
      
      result.fold(
        (failure) {
          _status = HistoryStatus.error;
          _errorMessage = _mapFailureToMessage(failure);
        },
        (_) {
          _status = HistoryStatus.success;
        },
      );

      notifyListeners();
    } catch (e) {
      _status = HistoryStatus.error;
      _errorMessage = 'Unexpected error: $e';
      notifyListeners();
    }
  }

  /// Get recent searches
  List<Map<String, dynamic>> getRecentSearches({int limit = 10}) {
    return _history.take(limit).toList();
  }

  /// Get search by ID
  Map<String, dynamic>? getSearchById(String id) {
    try {
      return _history.firstWhere((item) => item['id'] == id);
    } catch (e) {
      return null;
    }
  }

  /// Get searches by query
  List<Map<String, dynamic>> getSearchesByQuery(String query) {
    return _history
        .where((item) =>
            item['query'] is String &&
            (item['query'] as String).toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Get trending searches
  Future<List<String>> getTrendingSearches() async {
    final result = await _legalSearchRepository.getTrendingSearches();
    
    return result.fold(
      (failure) {
        debugPrint('Failed to get trending searches: ${_mapFailureToMessage(failure)}');
        return [];
      },
      (trending) => trending,
    );
  }

  /// Map failure to user-friendly message
  String _mapFailureToMessage(Failure failure) {
    switch (failure) {
      case ServerFailure _:
        return 'Server error. Please try again later.';
      case CacheFailure _:
        return 'Cache error. Please try again.';
      case NetworkFailure _:
        return 'Network error. Please check your connection.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refresh history
  Future<void> refresh() async {
    await loadHistory();
  }

  /// Get history count
  int get historyCount => _history.length;

  /// Check if history is empty
  bool get isEmpty => _history.isEmpty;

  /// Get history items sorted by timestamp
  List<Map<String, dynamic>> getSortedHistory() {
    final sorted = List<Map<String, dynamic>>.from(_history);
    sorted.sort((a, b) {
      final aTimestamp = DateTime.parse(a['timestamp'] as String);
      final bTimestamp = DateTime.parse(b['timestamp'] as String);
      return bTimestamp.compareTo(aTimestamp);
    });
    return sorted;
  }
}