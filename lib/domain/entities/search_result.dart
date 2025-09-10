import 'package:equatable/equatable.dart';
import 'legal_document.dart';

class SearchResult extends Equatable {
  final LegalDocument document;
  final double relevanceScore;
  final String snippet;

  const SearchResult({
    required this.document,
    required this.relevanceScore,
    required this.snippet,
  });

  Map<String, dynamic> toJson() {
    return {
      'document': document.toJson(),
      'relevanceScore': relevanceScore,
      'snippet': snippet,
    };
  }

  @override
  List<Object?> get props => [document, relevanceScore, snippet];
}
