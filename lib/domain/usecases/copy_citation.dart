import 'package:flutter/services.dart';
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';

/// Use case for copying citation to clipboard
class CopyCitation {
  /// Execute copying citation to clipboard
  Future<Either<Failure, void>> call({
    required String citation,
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: citation));
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to copy citation: $e'));
    }
  }
}