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

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      document: LegalDocument.fromJson(json['document'] as Map<String, dynamic>),
      relevanceScore: (json['relevanceScore'] as num).toDouble(),
      snippet: json['snippet'] as String,
    );
  }

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
