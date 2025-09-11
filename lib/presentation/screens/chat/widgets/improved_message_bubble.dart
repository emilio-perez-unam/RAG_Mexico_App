import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../widgets/ui_components/custom_card.dart';

class ImprovedMessageBubble extends StatefulWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;
  final bool showTimestamp;
  final bool isStreaming;

  const ImprovedMessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.onCopy,
    this.onRetry,
    this.showTimestamp = true,
    this.isStreaming = false,
  });

  @override
  State<ImprovedMessageBubble> createState() => _ImprovedMessageBubbleState();
}

class _ImprovedMessageBubbleState extends State<ImprovedMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isUser ? 1 : -1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.75;

    Color backgroundColor;
    Color textColor;
    BorderRadius borderRadius;
    List<BoxShadow> shadows;

    if (widget.isUser) {
      backgroundColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(4),
      );
      shadows = [
        BoxShadow(
          color: colorScheme.primary.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    } else {
      backgroundColor = widget.isError
          ? colorScheme.errorContainer.withValues(alpha: 0.2)
          : colorScheme.surfaceContainerHighest;
      textColor = widget.isError
          ? colorScheme.error
          : colorScheme.onSurface;
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(20),
      );
      shadows = [
        BoxShadow(
          color: colorScheme.shadow.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
    }

    Widget messageContent = Column(
      crossAxisAlignment:
          widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            boxShadow: shadows,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onCopy,
              onHover: (value) {
                setState(() {
                  _isHovered = value;
                });
              },
              borderRadius: borderRadius,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          widget.message,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                        if (widget.isStreaming) ...[
                          const SizedBox(height: 8),
                          _StreamingIndicator(color: textColor),
                        ],
                      ],
                    ),
                  ),
                  // Action buttons on hover
                  if (_isHovered)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ActionButton(
                            icon: Icons.copy,
                            tooltip: 'Copiar',
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: widget.message),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Mensaje copiado'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            },
                            color: textColor.withValues(alpha: 0.7),
                          ),
                          if (widget.isError && widget.onRetry != null)
                            _ActionButton(
                              icon: Icons.refresh,
                              tooltip: 'Reintentar',
                              onPressed: widget.onRetry!,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (widget.showTimestamp) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _formatTime(widget.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ],
    );

    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: widget.isUser ? 48 : 8,
            right: widget.isUser ? 8 : 48,
            top: 4,
            bottom: 4,
          ),
          child: Align(
            alignment:
                widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: messageContent,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamingIndicator extends StatefulWidget {
  final Color color;

  const _StreamingIndicator({required this.color});

  @override
  State<_StreamingIndicator> createState() => _StreamingIndicatorState();
}

class _StreamingIndicatorState extends State<_StreamingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: widget.color.withValues(
                  alpha: 0.3 + (0.7 * _controller.value),
                ),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// AI Response Card with structured content
class AIResponseCard extends StatelessWidget {
  final String title;
  final List<String> sections;
  final List<String>? sources;
  final double? confidence;
  final bool isStreaming;

  const AIResponseCard({
    super.key,
    required this.title,
    required this.sections,
    this.sources,
    this.confidence,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SectionCard(
      variant: CardVariant.outlined,
      header: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.smart_toy,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (confidence != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _getConfidenceColor(confidence!).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(confidence! * 100).toInt()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _getConfidenceColor(confidence!),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...sections.map((section) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  section,
                  style: theme.textTheme.bodyMedium,
                ),
              )),
          if (isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _StreamingIndicator(color: colorScheme.primary),
            ),
        ],
      ),
      footer: sources != null && sources!.isNotEmpty
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sources!.map((source) {
                return Chip(
                  label: Text(
                    source,
                    style: theme.textTheme.labelSmall,
                  ),
                  avatar: Icon(
                    Icons.source,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                );
              }).toList(),
            )
          : null,
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}