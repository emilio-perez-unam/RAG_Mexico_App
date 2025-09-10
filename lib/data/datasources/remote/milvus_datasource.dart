import 'package:dio/dio.dart';

/// Remote datasource for interacting with Milvus vector database
class MilvusDatasource {
  static const String _defaultCollection = 'legal_documents';
  static const String _defaultHost = 'localhost';
  static const int _defaultPort = 19530;

  final String host;
  final int port;
  final String collection;
  final String? username;
  final String? password;
  final Dio dio;

  MilvusDatasource({
    required this.host,
    required this.port,
    required this.collection,
    this.username,
    this.password,
    required this.dio,
  });

  /// Connect to Milvus
  Future<bool> connect() async {
    try {
      final response = await dio.get(
        'http://$host:$port/api/v1/health',
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Insert vectors into Milvus
  Future<void> insertVectors(List<Map<String, dynamic>> vectors) async {
    try {
      await dio.post(
        'http://$host:$port/api/v1/vector/insert',
        data: {
          'collection_name': collection,
          'vectors': vectors,
        },
      );
    } catch (e) {
      throw Exception('Failed to insert vectors: $e');
    }
  }

  /// Search for similar vectors in Milvus
  Future<List<Map<String, dynamic>>> searchVectors({
    required List<double> queryVector,
    int limit = 10,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final response = await dio.post(
        'http://$host:$port/api/v1/vector/search',
        data: {
          'collection_name': collection,
          'vector': queryVector,
          'limit': limit,
          'filters': filters,
        },
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['results']);
      } else {
        throw Exception('Search failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search vectors: $e');
    }
  }

  /// Get vector by ID
  Future<Map<String, dynamic>?> getVectorById(String id) async {
    try {
      final response = await dio.get(
        'http://$host:$port/api/v1/vector/$id',
        queryParameters: {
          'collection_name': collection,
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Get vector failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get vector: $e');
    }
  }

  /// Delete vectors by IDs
  Future<void> deleteVectors(List<String> ids) async {
    try {
      await dio.post(
        'http://$host:$port/api/v1/vector/delete',
        data: {
          'collection_name': collection,
          'ids': ids,
        },
      );
    } catch (e) {
      throw Exception('Failed to delete vectors: $e');
    }
  }

  /// Create collection
  Future<void> createCollection({
    String? schema,
    Map<String, dynamic>? properties,
  }) async {
    try {
      await dio.post(
        'http://$host:$port/api/v1/collection/create',
        data: {
          'collection_name': collection,
          'schema': schema,
          'properties': properties,
        },
      );
    } catch (e) {
      throw Exception('Failed to create collection: $e');
    }
  }

  /// Drop collection
  Future<void> dropCollection() async {
    try {
      await dio.post(
        'http://$host:$port/api/v1/collection/drop',
        data: {
          'collection_name': collection,
        },
      );
    } catch (e) {
      throw Exception('Failed to drop collection: $e');
    }
  }

  /// Get collection info
  Future<Map<String, dynamic>> getCollectionInfo() async {
    try {
      final response = await dio.get(
        'http://$host:$port/api/v1/collection/info',
        queryParameters: {
          'collection_name': collection,
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Get collection info failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get collection info: $e');
    }
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await dio.get(
        'http://$host:$port/api/v1/health',
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}