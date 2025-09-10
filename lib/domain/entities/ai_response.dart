import 'citation.dart';
import 'legal_source.dart';

class AIResponse {
  final String id;
  final String query;
  final double confidence;
  final List<ResponseSection> sections;
  final List<LegalSource> sources;
  final DateTime generatedAt;

  AIResponse({
    required this.id,
    required this.query,
    required this.confidence,
    required this.sections,
    required this.sources,
    required this.generatedAt,
  });
}

class ResponseSection {
  final String title;
  final List<ResponseParagraph> paragraphs;

  ResponseSection({
    required this.title,
    required this.paragraphs,
  });
}

class ResponseParagraph {
  final String text;
  final List<Citation> citations;

  ResponseParagraph({
    required this.text,
    required this.citations,
  });
}
