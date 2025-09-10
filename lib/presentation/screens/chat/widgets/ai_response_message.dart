import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/text_styles.dart';

// Data classes - define them here to avoid import issues
class AIResponseData {
  final double confidence;
  final List<ResponseSection> sections;
  final List<LegalSource> sources;

  AIResponseData({
    required this.confidence,
    required this.sections,
    required this.sources,
  });
}

class ResponseSection {
  final String title;
  final List<String> paragraphs;
  final List<String>? bulletPoints;

  ResponseSection({
    required this.title,
    required this.paragraphs,
    this.bulletPoints,
  });
}

class LegalSource {
  final String title;
  final IconData icon;
  final String type;

  LegalSource({
    required this.title,
    required this.icon,
    required this.type,
  });
}

class AIResponseMessage extends StatefulWidget {
  final AIResponseData response;
  final DateTime timestamp;

  const AIResponseMessage({
    super.key,
    required this.response,
    required this.timestamp,
  });

  @override
  State<AIResponseMessage> createState() => _AIResponseMessageState();
}

class _AIResponseMessageState extends State<AIResponseMessage> {
  bool? _isHelpful;
  final List<bool> _expandedSources = [false, false, false];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          width: 1,
          color: const Color(0xFFE0E0E0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 6,
            offset: Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with confidence badge
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.gavel,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Asistente Legal',
                      style: TextStyle(
                        color: Color(0xFF003366),
                        fontSize: 16,
                        fontFamily: 'Open Sans',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(widget.response.confidence),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(widget.response.confidence * 100).toInt()}% conf.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Open Sans',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content sections
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Response sections
                ...widget.response.sections
                    .map((section) => _buildSection(section)),

                const SizedBox(height: 24),

                // Source citations
                if (widget.response.sources.isNotEmpty) ...[
                  const Text(
                    'Fuentes consultadas:',
                    style: TextStyle(
                      color: Color(0xFF006847),
                      fontSize: 16,
                      fontFamily: 'Open Sans',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...widget.response.sources.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildSourceCard(entry.value, entry.key),
                        ),
                      ),
                ],

                const SizedBox(height: 16),

                // Feedback section
                _buildFeedbackSection(),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _copyResponse,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF003366),
                        side: const BorderSide(color: Color(0xFF003366)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _shareResponse,
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Compartir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006847),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
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

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.85) return const Color(0xFF10B981);
    if (confidence >= 0.70) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _buildSection(ResponseSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              color: Color(0xFF006847),
              fontSize: 18,
              fontFamily: 'Open Sans',
              fontWeight: FontWeight.w600,
              height: 1.56,
            ),
          ),
          const SizedBox(height: 16),
          ...section.paragraphs.map(
            (paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildParagraphWithCitations(paragraph),
            ),
          ),
          if (section.bulletPoints != null &&
              section.bulletPoints!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...section.bulletPoints!.map(
              (point) => Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(
                        color: Color(0xFF2C2C2C),
                        fontSize: 16,
                        fontFamily: 'Open Sans',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: const TextStyle(
                          color: Color(0xFF2C2C2C),
                          fontSize: 16,
                          fontFamily: 'Open Sans',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParagraphWithCitations(String text) {
    // Parse citations in text [CITATION]
    final RegExp citationRegex = RegExp(r'\[([^\]]+)\]');
    final List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (final match in citationRegex.allMatches(text)) {
      // Add text before citation
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            color: Color(0xFF2C2C2C),
            fontSize: 16,
            fontFamily: 'Open Sans',
            fontWeight: FontWeight.w400,
            height: 1.50,
          ),
        ));
      }

      // Add citation
      spans.add(TextSpan(
        text: '[${match.group(1)}]',
        style: const TextStyle(
          color: Color(0xFF003366),
          fontSize: 16,
          fontFamily: 'Open Sans',
          fontWeight: FontWeight.w400,
          height: 1.50,
        ),
      ));

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          color: Color(0xFF2C2C2C),
          fontSize: 16,
          fontFamily: 'Open Sans',
          fontWeight: FontWeight.w400,
          height: 1.50,
        ),
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }

  Widget _buildSourceCard(LegalSource source, int index) {
    final isExpanded =
        index < _expandedSources.length ? _expandedSources[index] : false;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (index < _expandedSources.length) {
              setState(() {
                _expandedSources[index] = !_expandedSources[index];
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(source.icon, size: 18, color: const Color(0xFF2C2C2C)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        source.title,
                        style: const TextStyle(
                          color: Color(0xFF2C2C2C),
                          fontSize: 16,
                          fontFamily: 'Open Sans',
                          fontWeight: FontWeight.w600,
                          height: 1.50,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF666666),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Fuente legal verificada',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            // Open source document
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Ver fuente'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF003366),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
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
                  color: Color(0xFF2C2C2C),
                  fontSize: 14,
                  fontFamily: 'Open Sans',
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 16),
              _buildFeedbackButton('Sí', _isHelpful == true),
              const SizedBox(width: 12),
              _buildFeedbackButton('No', _isHelpful == false),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  // Report error functionality
                },
                icon: const Icon(Icons.flag_outlined, size: 14),
                label: const Text('Reportar error'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF003366),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Generado: ${_formatDate(widget.timestamp)}',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontFamily: 'Open Sans',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Esta respuesta fue generada por IA y puede contener imprecisiones. '
            'No constituye asesoría legal profesional.',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontFamily: 'Open Sans',
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackButton(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _isHelpful = label == 'Sí';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color:
                isSelected ? const Color(0xFF10B981) : const Color(0xFFE0E0E0),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: isSelected
                  ? const Color(0xFF10B981)
                  : const Color(0xFF666666),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF10B981)
                    : const Color(0xFF2C2C2C),
                fontSize: 13,
                fontFamily: 'Open Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyResponse() {
    // Build response text
    StringBuffer buffer = StringBuffer();
    for (final section in widget.response.sections) {
      buffer.writeln(section.title);
      buffer.writeln();
      for (final paragraph in section.paragraphs) {
        buffer.writeln(paragraph);
        buffer.writeln();
      }
      if (section.bulletPoints != null) {
        for (final point in section.bulletPoints!) {
          buffer.writeln('• $point');
        }
        buffer.writeln();
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Respuesta copiada al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareResponse() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('Consulta Legal - ${_formatDate(widget.timestamp)}');
    buffer.writeln();

    for (final section in widget.response.sections) {
      buffer.writeln(section.title);
      buffer.writeln();
      for (final paragraph in section.paragraphs) {
        buffer.writeln(paragraph);
        buffer.writeln();
      }
      if (section.bulletPoints != null) {
        for (final point in section.bulletPoints!) {
          buffer.writeln('• $point');
        }
        buffer.writeln();
      }
    }

    buffer.writeln('---');
    buffer.writeln('Generado por Búsqueda Legal México RAG');

    Share.share(buffer.toString());
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
