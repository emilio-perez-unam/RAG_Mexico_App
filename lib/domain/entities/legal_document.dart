import 'package:equatable/equatable.dart';

class LegalDocument extends Equatable {
  final String id;
  final String title;
  final String summary;
  final String content;
  final DateTime publicationDate;
  final String documentType;
  final List<String> keywords;

  const LegalDocument({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.publicationDate,
    required this.documentType,
    required this.keywords,
  });

// Add this inside your LegalDocument class

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      content: json['content'] as String? ?? '',
      publicationDate: json['publicationDate'] != null
          ? DateTime.parse(json['publicationDate'] as String)
          : DateTime.now(),
      documentType: json['documentType'] as String? ?? 'unknown',
      keywords: json['keywords'] != null
          ? List<String>.from(json['keywords'] as List)
          : [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content': content,
      'publicationDate': publicationDate.toIso8601String(),
      'documentType': documentType,
      'keywords': keywords,
    };
  }

  @override
  List<Object?> get props =>
      [id, title, summary, content, publicationDate, documentType, keywords];
}
