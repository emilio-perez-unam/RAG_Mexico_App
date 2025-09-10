import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote datasource for document operations
abstract class DocumentDatasource {
  Future<Map<String, dynamic>> getDocument(String documentId);
  Future<List<Map<String, dynamic>>> getDocuments({
    int? limit,
    int? offset,
    Map<String, dynamic>? filters,
  });
  Future<Map<String, dynamic>> createDocument(Map<String, dynamic> document);
  Future<Map<String, dynamic>> updateDocument(String documentId, Map<String, dynamic> updates);
  Future<void> deleteDocument(String documentId);
  Future<String> uploadDocumentFile(String filePath);
  Future<String> downloadDocument(String documentId);
  Future<List<String>> getDocumentCitations(String documentId);
  Future<List<Map<String, dynamic>>> searchDocuments(String query);
}

/// Implementation of DocumentDatasource using Supabase
class DocumentDatasourceImpl implements DocumentDatasource {
  final SupabaseClient _supabaseClient;
  static const String _tableName = 'documents';
  static const String _bucketName = 'documents';

  DocumentDatasourceImpl(this._supabaseClient);

  @override
  Future<Map<String, dynamic>> getDocument(String documentId) async {
    final response = await _supabaseClient
        .from(_tableName)
        .select()
        .eq('id', documentId)
        .single();
    
    return response;
  }

  @override
  Future<List<Map<String, dynamic>>> getDocuments({
    int? limit,
    int? offset,
    Map<String, dynamic>? filters,
  }) async {
    dynamic query = _supabaseClient.from(_tableName).select();
    
    if (filters != null) {
      filters.forEach((key, value) {
        if (value != null) {
          query = query.eq(key, value);
        }
      });
    }
    
    if (limit != null) {
      query = query.limit(limit);
    }
    
    if (offset != null) {
      query = query.range(offset, offset + (limit ?? 10) - 1);
    }
    
    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<Map<String, dynamic>> createDocument(Map<String, dynamic> document) async {
    final response = await _supabaseClient
        .from(_tableName)
        .insert(document)
        .select()
        .single();
    
    return response;
  }

  @override
  Future<Map<String, dynamic>> updateDocument(String documentId, Map<String, dynamic> updates) async {
    final response = await _supabaseClient
        .from(_tableName)
        .update(updates)
        .eq('id', documentId)
        .select()
        .single();
    
    return response;
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    await _supabaseClient
        .from(_tableName)
        .delete()
        .eq('id', documentId);
  }

  @override
  Future<String> uploadDocumentFile(String filePath) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${filePath.split('/').last}';
    final file = File(filePath);
    
    await _supabaseClient.storage
        .from(_bucketName)
        .upload(fileName, file);
    
    final url = _supabaseClient.storage
        .from(_bucketName)
        .getPublicUrl(fileName);
    
    return url;
  }

  @override
  Future<String> downloadDocument(String documentId) async {
    // Get document metadata from database
    final document = await _supabaseClient
        .from(_tableName)
        .select('file_url')
        .eq('id', documentId)
        .single();
    
    if (document['file_url'] == null) {
      throw Exception('Document has no associated file');
    }
    
    // In a real implementation, you would download the file to a local path
    // For now, we return the public URL
    return document['file_url'] as String;
  }

  @override
  Future<List<String>> getDocumentCitations(String documentId) async {
    // Get document from database
    final document = await _supabaseClient
        .from(_tableName)
        .select('citations')
        .eq('id', documentId)
        .single();
    
    // Return citations if they exist, otherwise empty list
    if (document['citations'] != null && document['citations'] is List) {
      return List<String>.from(document['citations']);
    }
    
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> searchDocuments(String query) async {
    final response = await _supabaseClient
        .from(_tableName)
        .select()
        .textSearch('content', query)
        .limit(20);
    
    return List<Map<String, dynamic>>.from(response);
  }
}