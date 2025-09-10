import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/legal_document.dart';
import '../repositories/document_repository.dart';

/// Use case for getting document details
class GetDocumentDetails {
  final DocumentRepository _repository;

  GetDocumentDetails({required DocumentRepository repository})
      : _repository = repository;

  /// Execute getting document details
  Future<Either<Failure, LegalDocument>> call({
    required String documentId,
  }) async {
    return await _repository.getDocument(documentId);
  }
}