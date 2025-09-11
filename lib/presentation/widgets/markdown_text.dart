import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class MarkdownText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final bool selectable;
  final Color? linkColor;

  const MarkdownText({
    super.key,
    required this.data,
    this.style,
    this.selectable = true,
    this.linkColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodyLarge ?? const TextStyle();
    final linkStyle = baseStyle.copyWith(
      color: linkColor ?? theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    final spans = _parseMarkdown(data, baseStyle, linkStyle);
    
    if (selectable) {
      return SelectableText.rich(
        TextSpan(children: spans),
        style: baseStyle,
      );
    } else {
      return RichText(
        text: TextSpan(
          children: spans,
          style: baseStyle,
        ),
      );
    }
  }

  List<InlineSpan> _parseMarkdown(String text, TextStyle baseStyle, TextStyle linkStyle) {
    final spans = <InlineSpan>[];
    final lines = text.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Handle headings
      if (line.startsWith('### ')) {
        spans.add(TextSpan(
          text: line.substring(4),
          style: baseStyle.copyWith(
            fontSize: (baseStyle.fontSize ?? 14) + 2,
            fontWeight: FontWeight.w600,
          ),
        ));
      } else if (line.startsWith('## ')) {
        spans.add(TextSpan(
          text: line.substring(3),
          style: baseStyle.copyWith(
            fontSize: (baseStyle.fontSize ?? 14) + 4,
            fontWeight: FontWeight.w700,
          ),
        ));
      } else if (line.startsWith('# ')) {
        spans.add(TextSpan(
          text: line.substring(2),
          style: baseStyle.copyWith(
            fontSize: (baseStyle.fontSize ?? 14) + 6,
            fontWeight: FontWeight.w800,
          ),
        ));
      }
      // Handle bullet points
      else if (line.startsWith('• ') || line.startsWith('- ') || line.startsWith('* ')) {
        final bullet = line.startsWith('•') ? '•' : '•';
        final content = line.substring(2);
        spans.add(TextSpan(
          children: [
            TextSpan(text: '$bullet  ', style: baseStyle),
            ..._parseInlineMarkdown(content, baseStyle, linkStyle),
          ],
        ));
      }
      // Handle numbered lists
      else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        final match = RegExp(r'^(\d+)\.\s(.*)').firstMatch(line);
        if (match != null) {
          final number = match.group(1)!;
          final content = match.group(2)!;
          spans.add(TextSpan(
            children: [
              TextSpan(
                text: '$number.  ',
                style: baseStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              ..._parseInlineMarkdown(content, baseStyle, linkStyle),
            ],
          ));
        }
      }
      // Handle code blocks
      else if (line.startsWith('```')) {
        // Skip code block markers
        continue;
      }
      else if (i > 0 && lines[i - 1].startsWith('```') && i < lines.length - 1 && !lines[i + 1].startsWith('```')) {
        // Code block content
        spans.add(TextSpan(
          text: line,
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
            fontSize: (baseStyle.fontSize ?? 14) - 1,
          ),
        ));
      }
      // Handle blockquotes
      else if (line.startsWith('> ')) {
        spans.add(TextSpan(
          text: line.substring(2),
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
            color: baseStyle.color?.withValues(alpha: 0.7),
          ),
        ));
      }
      // Regular text
      else {
        spans.addAll(_parseInlineMarkdown(line, baseStyle, linkStyle));
      }
      
      // Add newline if not last line
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    
    return spans;
  }

  List<InlineSpan> _parseInlineMarkdown(String text, TextStyle baseStyle, TextStyle linkStyle) {
    final spans = <InlineSpan>[];
    
    // Pattern for inline markdown
    final pattern = RegExp(
      r'(\*\*\*([^*]+)\*\*\*)|(\*\*([^*]+)\*\*)|(\*([^*]+)\*)|(_([^_]+)_)|(`([^`]+)`)|(\[([^\]]+)\]\(([^)]+)\))',
    );
    
    int lastEnd = 0;
    
    for (final match in pattern.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      
      // Bold and italic (***text***)
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ));
      }
      // Bold (**text**)
      else if (match.group(3) != null) {
        spans.add(TextSpan(
          text: match.group(4),
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      }
      // Italic (*text* or _text_)
      else if (match.group(5) != null || match.group(7) != null) {
        final italicText = match.group(6) ?? match.group(8);
        spans.add(TextSpan(
          text: italicText,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      }
      // Code (`text`)
      else if (match.group(9) != null) {
        spans.add(TextSpan(
          text: match.group(10),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.grey.withValues(alpha: 0.15),
            fontSize: (baseStyle.fontSize ?? 14) - 1,
          ),
        ));
      }
      // Links [text](url)
      else if (match.group(11) != null) {
        final linkText = match.group(12)!;
        final url = match.group(13)!;
        spans.add(TextSpan(
          text: linkText,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              // Handle URL tap
            },
        ));
      }
      
      lastEnd = match.end;
    }
    
    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }
    
    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
  }
}

// Widget for displaying formatted lists
class FormattedList extends StatelessWidget {
  final List<String> items;
  final bool ordered;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  const FormattedList({
    super.key,
    required this.items,
    this.ordered = false,
    this.style,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = style ?? theme.textTheme.bodyLarge ?? const TextStyle();

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    ordered ? '${index + 1}.' : '•',
                    style: textStyle.copyWith(
                      fontWeight: ordered ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                Expanded(
                  child: MarkdownText(
                    data: item,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Widget for code blocks with syntax highlighting
class CodeBlock extends StatelessWidget {
  final String code;
  final String? language;
  final TextStyle? style;

  const CodeBlock({
    super.key,
    required this.code,
    this.language,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Stack(
        children: [
          SelectableText(
            code,
            style: (style ?? const TextStyle()).copyWith(
              fontFamily: 'monospace',
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (language != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  language!,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}