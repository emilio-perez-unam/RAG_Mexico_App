import 'package:flutter/foundation.dart';

/// Filter provider for managing search filters
class FilterProvider extends ChangeNotifier {
  // Date range filters
  DateTime? _startDate;
  DateTime? _endDate;

  // Document type filters
  final Set<String> _documentTypes = {};

  // Jurisdiction filters
  final Set<String> _jurisdictions = {};

  // Relevance score threshold
  double _minRelevanceScore = 0.0;

  // Sorting options
  String _sortBy = 'relevance';
  bool _sortAscending = false;

  // Text search filters
  String _searchText = '';

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 20;

  // Getters
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  Set<String> get documentTypes => Set.unmodifiable(_documentTypes);
  Set<String> get jurisdictions => Set.unmodifiable(_jurisdictions);
  double get minRelevanceScore => _minRelevanceScore;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  String get searchText => _searchText;
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;

  /// Set date range filters
  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  /// Add document type filter
  void addDocumentType(String type) {
    _documentTypes.add(type);
    notifyListeners();
  }

  /// Remove document type filter
  void removeDocumentType(String type) {
    _documentTypes.remove(type);
    notifyListeners();
  }

  /// Clear all document type filters
  void clearDocumentTypes() {
    _documentTypes.clear();
    notifyListeners();
  }

  /// Add jurisdiction filter
  void addJurisdiction(String jurisdiction) {
    _jurisdictions.add(jurisdiction);
    notifyListeners();
  }

  /// Remove jurisdiction filter
  void removeJurisdiction(String jurisdiction) {
    _jurisdictions.remove(jurisdiction);
    notifyListeners();
  }

  /// Clear all jurisdiction filters
  void clearJurisdictions() {
    _jurisdictions.clear();
    notifyListeners();
  }

  /// Set minimum relevance score
  void setMinRelevanceScore(double score) {
    _minRelevanceScore = score.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Set sorting options
  void setSorting(String field, [bool ascending = false]) {
    _sortBy = field;
    _sortAscending = ascending;
    notifyListeners();
  }

  /// Set search text
  void setSearchText(String text) {
    _searchText = text;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _startDate = null;
    _endDate = null;
    _documentTypes.clear();
    _jurisdictions.clear();
    _minRelevanceScore = 0.0;
    _sortBy = 'relevance';
    _sortAscending = false;
    _searchText = '';
    _currentPage = 1;
    notifyListeners();
  }

  /// Apply filters to a query
  Map<String, dynamic> applyFilters() {
    final filters = <String, dynamic>{};

    if (_startDate != null) {
      filters['startDate'] = _startDate!.toIso8601String();
    }

    if (_endDate != null) {
      filters['endDate'] = _endDate!.toIso8601String();
    }

    if (_documentTypes.isNotEmpty) {
      filters['documentTypes'] = _documentTypes.toList();
    }

    if (_jurisdictions.isNotEmpty) {
      filters['jurisdictions'] = _jurisdictions.toList();
    }

    if (_minRelevanceScore > 0.0) {
      filters['minRelevanceScore'] = _minRelevanceScore;
    }

    if (_searchText.isNotEmpty) {
      filters['searchText'] = _searchText;
    }

    return filters;
  }

  /// Check if any filters are active
  bool get hasActiveFilters {
    return _startDate != null ||
        _endDate != null ||
        _documentTypes.isNotEmpty ||
        _jurisdictions.isNotEmpty ||
        _minRelevanceScore > 0.0 ||
        _searchText.isNotEmpty;
  }

  /// Get active filter count
  int get activeFilterCount {
    int count = 0;
    if (_startDate != null) count++;
    if (_endDate != null) count++;
    if (_documentTypes.isNotEmpty) count++;
    if (_jurisdictions.isNotEmpty) count++;
    if (_minRelevanceScore > 0.0) count++;
    if (_searchText.isNotEmpty) count++;
    return count;
  }

  /// Reset pagination
  void resetPagination() {
    _currentPage = 1;
    notifyListeners();
  }

  /// Go to next page
  void nextPage() {
    _currentPage++;
    notifyListeners();
  }

  /// Go to previous page
  void previousPage() {
    if (_currentPage > 1) {
      _currentPage--;
      notifyListeners();
    }
  }

  /// Go to specific page
  void goToPage(int page) {
    if (page > 0) {
      _currentPage = page;
      notifyListeners();
    }
  }

  /// Set items per page
  void setItemsPerPage(int items) {
    if (items > 0) {
      _itemsPerPage = items;
      notifyListeners();
    }
  }

  /// Get pagination parameters
  Map<String, int> getPaginationParams() {
    return {
      'limit': _itemsPerPage,
      'offset': (_currentPage - 1) * _itemsPerPage,
    };
  }

  /// Check if there are more pages
  bool get hasNextPage => true; // This would depend on total results count

  /// Check if there are previous pages
  bool get hasPreviousPage => _currentPage > 1;

  /// Get current page info
  String get pageInfo {
    final start = (_currentPage - 1) * _itemsPerPage + 1;
    final end = _currentPage * _itemsPerPage;
    return 'Page $_currentPage ($start-$end)';
  }
}