enum SourceType {
  codigo,
  jurisprudencia,
  libro,
  ley,
}

class LegalSource {
  final String id;
  final String title;
  final SourceType type;
  final String? article;
  final String? page;
  final String excerpt;
  final String fullDocumentUrl;

  LegalSource({
    required this.id,
    required this.title,
    required this.type,
    this.article,
    this.page,
    required this.excerpt,
    required this.fullDocumentUrl,
  });
}
