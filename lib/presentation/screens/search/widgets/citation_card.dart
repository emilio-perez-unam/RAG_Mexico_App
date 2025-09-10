import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../domain/entities/legal_source.dart';

class CitationCard extends StatefulWidget {
  final LegalSource source;
  final VoidCallback onCopy;
  final VoidCallback onViewDocument;

  const CitationCard({
    Key? key,
    required this.source,
    required this.onCopy,
    required this.onViewDocument,
  }) : super(key: key);

  @override
  State<CitationCard> createState() => _CitationCardState();
}

class _CitationCardState extends State<CitationCard> {
  bool _isExpanded = false;

  IconData _getSourceIcon() {
    switch (widget.source.type) {
      case SourceType.codigo:
        return Icons.book;
      case SourceType.jurisprudencia:
        return Icons.gavel;
      case SourceType.libro:
        return Icons.menu_book;
      case SourceType.ley:
        return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGray,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(8),
                      topRight: const Radius.circular(8),
                      bottomLeft: Radius.circular(_isExpanded ? 0 : 8),
                      bottomRight: Radius.circular(_isExpanded ? 0 : 8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getSourceIcon(),
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.source.title,
                          style: AppTextStyles.bodyBold,
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                if (_isExpanded) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.source.article != null) ...[
                          Text(
                            'Artículo ${widget.source.article}',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.source.excerpt,
                            style: AppTextStyles.body,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.onCopy,
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copiar cita'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryBlue,
                                  side: const BorderSide(
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: widget.onViewDocument,
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Ver documento'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: AppColors.white,
                                ),
                              ),
                            ),
                          ],
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
}
