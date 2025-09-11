import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/legal_document.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/remote/document_datasource.dart';

/// Implementation of DocumentRepository
class DocumentRepositoryImpl implements DocumentRepository {
  final DocumentDatasource _documentDatasource;

  DocumentRepositoryImpl({
    required DocumentDatasource documentDatasource,
  }) : _documentDatasource = documentDatasource;

  @override
  Future<Either<Failure, LegalDocument>> getDocument(String documentId) async {
    try {
      final documentData = await _documentDatasource.getDocument(documentId);
      
      return Right(LegalDocument.fromJson(documentData));
    } catch (e) {
      return Left(ServerFailure('Failed to get document: $e'));
    }
  }

  @override
  Future<Either<Failure, List<LegalDocument>>> getDocuments({
    int? limit,
    int? offset,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final documentsData = await _documentDatasource.getDocuments(
        limit: limit,
        offset: offset,
        filters: filters,
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get documents: $e'));
    }
  }

  @override
  Future<Either<Failure, LegalDocument>> saveDocument(LegalDocument document) async {
    try {
      final documentData = await _documentDatasource.createDocument(document.toJson());
      
      return Right(LegalDocument.fromJson(documentData));
    } catch (e) {
      return Left(ServerFailure('Failed to save document: $e'));
    }
  }

  @override
  Future<Either<Failure, LegalDocument>> updateDocument(
    String documentId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final documentData = await _documentDatasource.updateDocument(
        documentId,
        updates,
      );
      
      return Right(LegalDocument.fromJson(documentData));
    } catch (e) {
      return Left(ServerFailure('Failed to update document: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteDocument(String documentId) async {
    try {
      await _documentDatasource.deleteDocument(documentId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to delete document: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> uploadDocumentFile(String filePath) async {
    try {
      final url = await _documentDatasource.uploadDocumentFile(filePath);
      return Right(url);
    } catch (e) {
      return Left(ServerFailure('Failed to upload document file: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> downloadDocument(String documentId) async {
    try {
      final filePath = await _documentDatasource.downloadDocument(documentId);
      return Right(filePath);
    } catch (e) {
      return Left(ServerFailure('Failed to download document: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getDocumentCitations(String documentId) async {
    try {
      final citations = await _documentDatasource.getDocumentCitations(documentId);
      return Right(citations);
    } catch (e) {
      return Left(ServerFailure('Failed to get document citations: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> searchDocuments(String query) async {
    try {
      final documentsData = await _documentDatasource.searchDocuments(query);

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to search documents: $e'));
    }
  }

  Future<Either<Failure, LegalDocument>> getDocumentByTitle(String title) async {
    try {
      final documents = await _documentDatasource.getDocuments(
        filters: {'title': title},
        limit: 1,
      );

      if (documents.isEmpty) {
        return const Left(ServerFailure('Document not found'));
      }

      return Right(LegalDocument.fromJson(documents.first));
    } catch (e) {
      return Left(ServerFailure('Failed to get document by title: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getDocumentsByType(String type) async {
    try {
      final documentsData = await _documentDatasource.getDocuments(
        filters: {'type': type},
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get documents by type: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getDocumentsByJurisdiction(
    String jurisdiction,
  ) async {
    try {
      final documentsData = await _documentDatasource.getDocuments(
        filters: {'jurisdiction': jurisdiction},
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get documents by jurisdiction: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getDocumentsByDateRange({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final filters = <String, dynamic>{};

      if (startDate != null) {
        filters['startDate'] = startDate.toIso8601String();
      }

      if (endDate != null) {
        filters['endDate'] = endDate.toIso8601String();
      }

      final documentsData = await _documentDatasource.getDocuments(
        filters: filters,
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get documents by date range: $e'));
    }
  }

  Future<Either<Failure, LegalDocument>> getLatestDocument() async {
    try {
      final documents = await _documentDatasource.getDocuments(
        limit: 1,
        filters: {'orderBy': 'created_at', 'orderDirection': 'desc'},
      );

      if (documents.isEmpty) {
        return const Left(ServerFailure('No documents found'));
      }

      return Right(LegalDocument.fromJson(documents.first));
    } catch (e) {
      return Left(ServerFailure('Failed to get latest document: $e'));
    }
  }

  Future<Either<Failure, int>> getTotalDocumentCount() async {
    try {
      final documents = await _documentDatasource.getDocuments();
      return Right(documents.length);
    } catch (e) {
      return Left(ServerFailure('Failed to get document count: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getFavoriteDocuments() async {
    try {
      final documentsData = await _documentDatasource.getDocuments(
        filters: {'favorite': true},
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get favorite documents: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getRecentlyViewedDocuments({
    int limit = 10,
  }) async {
    try {
      final documentsData = await _documentDatasource.getDocuments(
        limit: limit,
        filters: {'orderBy': 'last_viewed', 'orderDirection': 'desc'},
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get recently viewed documents: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getDocumentsByTag(String tag) async {
    try {
      final documentsData = await _documentDatasource.getDocuments(
        filters: {'tags': [tag]},
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get documents by tag: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getDocumentsWithPagination({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final offset = (page - 1) * pageSize;
      final documentsData = await _documentDatasource.getDocuments(
        limit: pageSize,
        offset: offset,
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get documents with pagination: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getDocumentsByAuthor(String author) async {
    try {
      final documentsData = await _documentDatasource.getDocuments(
        filters: {'author': author},
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get documents by author: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getDocumentsByVersion(String version) async {
    try {
      final documentsData = await _documentDatasource.getDocuments(
        filters: {'version': version},
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get documents by version: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getDocumentsByCategory(String category) async {
    try {
      final documentsData = await _documentDatasource.getDocuments(
        filters: {'category': category},
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get documents by category: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getDocumentsByStatus(String status) async {
    try {
      final documentsData = await _documentDatasource.getDocuments(
        filters: {'status': status},
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get documents by status: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getDocumentsByLanguage(String language) async {
    try {
      final documentsData = await _documentDatasource.getDocuments(
        filters: {'language': language},
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get documents by language: $e'));
    }
  }

  Future<Either<Failure, List<LegalDocument>>> getDocumentsByPublisher(String publisher) async {
    try {
      final documentsData = await _documentDatasource.getDocuments(
        filters: {'publisher': publisher},
      );

      final documents = documentsData
          .map((data) => LegalDocument.fromJson(data))
          .toList();

      return Right(documents);
    } catch (e) {
      return Left(ServerFailure('Failed to get documents by publisher: $e'));
    }
  }
}