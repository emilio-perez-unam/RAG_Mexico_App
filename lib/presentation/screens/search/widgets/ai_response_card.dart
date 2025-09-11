import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../domain/entities/ai_response.dart';
import 'citation_card.dart';
import '../../../widgets/common/confidence_badge.dart';

class AIResponseCard extends StatefulWidget {
  const AIResponseCard({
    super.key,
    required this.response,
  });

  final AIResponse response;

  @override
  State<AIResponseCard> createState() => _AIResponseCardState();
}

class _AIResponseCardState extends State<AIResponseCard> {
  bool? _isHelpful;

  Widget _buildTextWithCitations(ResponseParagraph paragraph) {
    List<InlineSpan> spans = [];
    String text = paragraph.text;
    int lastIndex = 0;

    // Sort citations by start index
    final sortedCitations = List.from(paragraph.citations)
      ..sort((a, b) => a.startIndex.compareTo(b.startIndex));

    for (final citation in sortedCitations) {
      // Add text before citation
      if (citation.startIndex > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, citation.startIndex),
          style: AppTextStyles.body,
        ));
      }

      // Add citation
      spans.add(TextSpan(
        text: ' [${citation.reference}]',
        style: AppTextStyles.citation,
      ));

      lastIndex = citation.endIndex;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: AppTextStyles.body,
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }

  Widget _buildSection(ResponseSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title, style: AppTextStyles.heading2),
        const SizedBox(height: 24),
        ...section.paragraphs.map((paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildTextWithCitations(paragraph),
            )),
        if (section.title == "Respuesta Legal" &&
            section.paragraphs.any((p) => p.text.contains("requisitos"))) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBulletPoint("Existencia de un hecho u omisión ilícito"),
                _buildBulletPoint("Daño causado (patrimonial o moral)"),
                _buildBulletPoint(
                    "Relación de causalidad entre el hecho y el daño"),
                _buildBulletPoint(
                    "Culpa o negligencia del responsable (en casos de responsabilidad subjetiva)"),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: AppTextStyles.body),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }

  void _handleCopyResponse() {
    // Build plain text version of response
    StringBuffer buffer = StringBuffer();
    for (final section in widget.response.sections) {
      buffer.writeln(section.title);
      buffer.writeln();
      for (final paragraph in section.paragraphs) {
        buffer.write(paragraph.text);
        for (final citation in paragraph.citations) {
          buffer.write(' [${citation.reference}]');
        }
        buffer.writeln();
        buffer.writeln();
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Respuesta copiada al portapapeles')),
    );
  }

  void _handleShareResponse() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('Búsqueda Legal México RAG\n');
    for (final section in widget.response.sections) {
      buffer.writeln(section.title);
      for (final paragraph in section.paragraphs) {
        buffer.write(paragraph.text);
        for (final citation in paragraph.citations) {
          buffer.write(' [${citation.reference}]');
        }
        buffer.writeln();
      }
      buffer.writeln();
    }

    Share.share(buffer.toString());
  }

  Widget _buildFeedbackButton({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        size: 14,
      ),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            isSelected ? AppColors.primaryGreen : AppColors.textPrimary,
        side: BorderSide(
          color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
        ),
        backgroundColor:
            isSelected ? AppColors.primaryGreen.withValues(alpha: 0.1) : null,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Búsqueda Legal México RAG',
                  style: AppTextStyles.heading1,
                ),
                ConfidenceBadge(confidence: widget.response.confidence),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 0, 25, 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Response sections
                ...widget.response.sections.map(_buildSection),

                // Sources
                const SizedBox(height: 32),
                ...widget.response.sources.map((source) => CitationCard(
                      source: source,
                      onCopy: () {
                        String citation = source.title;
                        if (source.article != null) {
                          citation += ', Art. ${source.article}';
                        }
                        if (source.page != null) {
                          citation += ', p. ${source.page}';
                        }
                        Clipboard.setData(ClipboardData(text: citation));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cita copiada')),
                        );
                      },
                      onViewDocument: () {
                        // Navigate to document viewer
                        // Navigator.pushNamed(context, '/document', arguments: source);
                      },
                    )),

                // Feedback section
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '¿Fue útil esta respuesta?',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontFamily: AppTextStyles.fontFamily,
                            ),
                          ),
                          const SizedBox(width: 16),
                          _buildFeedbackButton(
                            label: 'Sí',
                            isSelected: _isHelpful == true,
                            onPressed: () => setState(() => _isHelpful = true),
                          ),
                          const SizedBox(width: 12),
                          _buildFeedbackButton(
                            label: 'No',
                            isSelected: _isHelpful == false,
                            onPressed: () => setState(() => _isHelpful = false),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              // Handle report error
                            },
                            icon: const Icon(Icons.flag_outlined, size: 14),
                            label: const Text('Reportar error en cita'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Generado: ${_formatDate(widget.response.generatedAt)}',
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.info_outline,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Esta respuesta fue generada por inteligencia artificial y puede contener imprecisiones. '
                              'La información proporcionada no constituye asesoría legal y no debe utilizarse como '
                              'sustituto del consejo de un profesional del derecho calificado.',
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action buttons
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _handleCopyResponse,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: const BorderSide(color: AppColors.primaryBlue),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _handleShareResponse,
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Compartir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
