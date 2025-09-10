import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/legal_document.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/legal_search_repository.dart';
import '../datasources/remote/deepseek_datasource.dart';
import '../datasources/remote/milvus_datasource.dart';
import '../datasources/local/search_history_local_datasource.dart';

/// Implementation of LegalSearchRepository
class LegalSearchRepositoryImpl implements LegalSearchRepository {
  final DeepSeekDatasource _deepSeekDatasource;
  final MilvusDatasource _milvusDatasource;
  final SearchHistoryLocalDatasource _searchHistoryDatasource;

  LegalSearchRepositoryImpl({
    required DeepSeekDatasource deepSeekDatasource,
    required MilvusDatasource milvusDatasource,
    required SearchHistoryLocalDatasource searchHistoryDatasource,
  })  : _deepSeekDatasource = deepSeekDatasource,
        _milvusDatasource = milvusDatasource,
        _searchHistoryDatasource = searchHistoryDatasource;

  @override
  Future<Either<Failure, List<SearchResult>>> searchDocuments({
    required String query,
    Map<String, dynamic>? filters,
    int? limit,
  }) async {
    try {
      // First, try to search in Milvus vector database
      final vectorResults = await _milvusDatasource.searchVectors(
        queryVector: _generateQueryVector(query),
        limit: limit ?? 20,
        filters: filters,
      );

      // Convert vector results to search results
      final results = vectorResults.map((result) {
        final document = LegalDocument(
          id: result['id'] as String,
          title: result['title'] as String,
          summary: result['summary'] as String? ?? '',
          content: result['content'] as String? ?? '',
          publicationDate: result['publicationDate'] != null 
              ? DateTime.parse(result['publicationDate'] as String)
              : DateTime.now(),
          documentType: result['documentType'] as String? ?? 'unknown',
          keywords: result['keywords'] != null 
              ? List<String>.from(result['keywords'] as List)
              : [],
        );
        
        return SearchResult(
          document: document,
          snippet: result['snippet'] as String? ?? '',
          relevanceScore: result['score'] as double? ?? 0.0,
        );
      }).toList();

      // If no results from vector search, fall back to DeepSeek
      if (results.isEmpty) {
        final response = await _deepSeekDatasource.sendMessage(
          query,
          model: 'deepseek-reasoner',
          enforceThinking: true,
        );

        // Parse response into search results
        final content = response.content;
        final parsedResults = _parseSearchResults(content);
        results.addAll(parsedResults);
      }

      // Save search to history
      await _saveSearchToHistory(query, results);

      return Right(results);
    } catch (e) {
      return Left(ServerFailure('Failed to search documents: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getSearchSuggestions(String partialQuery) async {
    try {
      // Get recent search history
      final history = await _searchHistoryDatasource.getSearchHistory();
      
      // Filter and rank suggestions based on partial query
      final suggestions = history
          .where((item) => 
              item['query'] is String && 
              (item['query'] as String).toLowerCase().contains(partialQuery.toLowerCase()))
          .map((item) => item['query'] as String)
          .toSet() // Remove duplicates
          .toList()
          .take(10) // Limit to 10 suggestions
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

  @override
  Future<Either<Failure, List<LegalDocument>>> getRelatedDocuments(String documentId) async {
    try {
      // Get the document to find related ones
      final document = await _milvusDatasource.getVectorById(documentId);
      if (document == null) {
        return const Left(ServerFailure('Document not found'));
      }

      // Search for similar documents
      final related = await _milvusDatasource.searchVectors(
        queryVector: _generateQueryVector(document['content'] as String),
        limit: 10,
      );

      // Convert to LegalDocument entities
      final documents = related.map((doc) {
        return LegalDocument(
          id: doc['id'] as String,
          title: doc['title'] as String,
          summary: doc['summary'] as String? ?? '',
          content: doc['content'] as String,
          publicationDate: doc['publicationDate'] != null 
              ? DateTime.parse(doc['publicationDate'] as String)
              : DateTime.now(),
          documentType: doc['documentType'] as String? ?? 'unknown',
          keywords: doc['keywords'] != null 
              ? List<String>.from(doc['keywords'] as List)
              : [],
        );
      }).toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get related documents: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getTrendingSearches() async {
    try {
      // Get search history and count occurrences
      final history = await _searchHistoryDatasource.getSearchHistory();
      
      // Count query frequencies
      final queryCounts = <String, int>{};
      for (final item in history) {
        final query = item['query'] as String?;
        if (query != null) {
          queryCounts[query] = (queryCounts[query] ?? 0) + 1;
        }
      }
      
      // Sort by frequency and take top 10
      final sortedQueries = queryCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final trending = sortedQueries
          .take(10)
          .map((entry) => entry.key)
          .toList();

      return Right(trending);
    } catch (e) {
      return Left(ServerFailure('Failed to get trending searches: $e'));
    }
  }

  /// Generate a query vector for similarity search
  List<double> _generateQueryVector(String query) {
    // In a real implementation, this would use an embedding model
    // For now, we'll return a mock vector
    return List<double>.filled(128, 0.5); // Mock 128-dimensional vector
  }

  /// Parse search results from DeepSeek response
  List<SearchResult> _parseSearchResults(String content) {
    // In a real implementation, this would parse structured output
    // For now, we'll return a mock result
    final document = LegalDocument(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Mock Result',
      summary: content.substring(0, min(content.length, 200)),
      content: content,
      publicationDate: DateTime.now(),
      documentType: 'ai-generated',
      keywords: const [],
    );
    
    return [
      SearchResult(
        document: document,
        snippet: content.substring(0, min(content.length, 200)),
        relevanceScore: 0.8,
      ),
    ];
  }

  /// Save search to local history
  Future<void> _saveSearchToHistory(String query, List<SearchResult> results) async {
    final searchData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'query': query,
      'timestamp': DateTime.now().toIso8601String(),
      'resultsCount': results.length,
      'results': results.map((r) => r.toJson()).toList(),
    };

    await _searchHistoryDatasource.saveSearchHistory(searchData);
  }

  /// Helper function for min
  int min(int a, int b) => a < b ? a : b;
}