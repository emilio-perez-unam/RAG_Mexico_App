import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/legal_document.dart';

/// Repository interface for document operations
abstract class DocumentRepository {
  /// Get a specific document by ID
  Future<Either<Failure, LegalDocument>> getDocument(String documentId);

  /// Get multiple documents with optional filters
  Future<Either<Failure, List<LegalDocument>>> getDocuments({
    int? limit,
    int? offset,
    Map<String, dynamic>? filters,
  });

  /// Save a document
  Future<Either<Failure, LegalDocument>> saveDocument(LegalDocument document);

  /// Update a document
  Future<Either<Failure, LegalDocument>> updateDocument(String documentId, Map<String, dynamic> updates);

  /// Delete a document
  Future<Either<Failure, void>> deleteDocument(String documentId);

  /// Upload a document file
  Future<Either<Failure, String>> uploadDocumentFile(String filePath);

  /// Download a document
  Future<Either<Failure, String>> downloadDocument(String documentId);

  /// Get document citations
  Future<Either<Failure, List<String>>> getDocumentCitations(String documentId);
}