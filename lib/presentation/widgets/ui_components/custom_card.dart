import 'package:flutter/material.dart';

enum CardVariant { elevated, outlined, filled, ghost }

class CustomCard extends StatelessWidget {
  final Widget child;
  final CardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double borderRadius;
  final bool isHoverable;
  final bool isSelectable;
  final bool isSelected;
  final double? width;
  final double? height;
  final List<BoxShadow>? customShadow;

  const CustomCard({
    super.key,
    required this.child,
    this.variant = CardVariant.elevated,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderRadius = 16,
    this.isHoverable = false,
    this.isSelectable = false,
    this.isSelected = false,
    this.width,
    this.height,
    this.customShadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine card properties based on variant
    Color cardColor;
    BoxBorder? border;
    List<BoxShadow>? shadow;

    switch (variant) {
      case CardVariant.elevated:
        cardColor = backgroundColor ?? colorScheme.surface;
        shadow = customShadow ??
            [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ];
        border = null;
        break;
      case CardVariant.outlined:
        cardColor = backgroundColor ?? colorScheme.surface;
        shadow = null;
        border = Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1,
        );
        break;
      case CardVariant.filled:
        cardColor = backgroundColor ?? colorScheme.surfaceContainerHighest;
        shadow = null;
        border = null;
        break;
      case CardVariant.ghost:
        cardColor = backgroundColor ?? Colors.transparent;
        shadow = null;
        border = null;
        break;
    }

    // Handle selection state
    if (isSelected && isSelectable) {
      cardColor = colorScheme.primaryContainer.withValues(alpha: 0.1);
      border = Border.all(
        color: colorScheme.primary,
        width: 2,
      );
    }

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            splashColor: colorScheme.primary.withValues(alpha: 0.08),
            highlightColor: colorScheme.primary.withValues(alpha: 0.04),
            hoverColor: isHoverable ? colorScheme.primary.withValues(alpha: 0.02) : null,
            child: Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );

    if (isHoverable && !isSelectable) {
      return MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

// Extension card with header and content sections
class SectionCard extends StatelessWidget {
  final Widget? header;
  final Widget content;
  final Widget? footer;
  final CardVariant variant;
  final EdgeInsetsGeometry? headerPadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? footerPadding;
  final bool showDividers;
  final VoidCallback? onTap;

  const SectionCard({
    super.key,
    this.header,
    required this.content,
    this.footer,
    this.variant = CardVariant.elevated,
    this.headerPadding,
    this.contentPadding,
    this.footerPadding,
    this.showDividers = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomCard(
      variant: variant,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[
            Padding(
              padding: headerPadding ?? const EdgeInsets.all(16),
              child: header!,
            ),
            if (showDividers)
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
          ],
          Padding(
            padding: contentPadding ?? const EdgeInsets.all(16),
            child: content,
          ),
          if (footer != null) ...[
            if (showDividers)
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            Padding(
              padding: footerPadding ?? const EdgeInsets.all(16),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}