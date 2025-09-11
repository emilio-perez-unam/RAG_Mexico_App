import 'package:flutter/material.dart';

enum ButtonVariant { primary, secondary, tertiary, ghost, danger }
enum ButtonSize { small, medium, large }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;
  final bool isOutlined;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get colors based on variant
    Color backgroundColor;
    Color foregroundColor;
    Color? borderColor;

    switch (variant) {
      case ButtonVariant.primary:
        backgroundColor = isOutlined ? Colors.transparent : colorScheme.primary;
        foregroundColor = isOutlined ? colorScheme.primary : colorScheme.onPrimary;
        borderColor = isOutlined ? colorScheme.primary : null;
        break;
      case ButtonVariant.secondary:
        backgroundColor = isOutlined ? Colors.transparent : colorScheme.secondary;
        foregroundColor = isOutlined ? colorScheme.secondary : colorScheme.onSecondary;
        borderColor = isOutlined ? colorScheme.secondary : null;
        break;
      case ButtonVariant.tertiary:
        backgroundColor = isOutlined ? Colors.transparent : colorScheme.tertiary;
        foregroundColor = isOutlined ? colorScheme.tertiary : colorScheme.onTertiary;
        borderColor = isOutlined ? colorScheme.tertiary : null;
        break;
      case ButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = colorScheme.primary;
        borderColor = null;
        break;
      case ButtonVariant.danger:
        backgroundColor = isOutlined ? Colors.transparent : colorScheme.error;
        foregroundColor = isOutlined ? colorScheme.error : colorScheme.onError;
        borderColor = isOutlined ? colorScheme.error : null;
        break;
    }

    // Get padding based on size
    EdgeInsets padding;
    double fontSize;
    double iconSize;
    double height;

    switch (size) {
      case ButtonSize.small:
        padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
        fontSize = 14;
        iconSize = 18;
        height = 36;
        break;
      case ButtonSize.medium:
        padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
        fontSize = 16;
        iconSize = 20;
        height = 44;
        break;
      case ButtonSize.large:
        padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
        fontSize = 18;
        iconSize = 24;
        height = 52;
        break;
    }

    Widget child = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null && !isLoading) ...[
          Icon(leadingIcon, size: iconSize),
          const SizedBox(width: 8),
        ],
        if (isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: foregroundColor,
          ),
        ),
        if (trailingIcon != null && !isLoading) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: iconSize),
        ],
      ],
    );

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(height / 2),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(height / 2),
          splashColor: foregroundColor.withValues(alpha: 0.1),
          highlightColor: foregroundColor.withValues(alpha: 0.05),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              border: borderColor != null
                  ? Border.all(color: borderColor, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}