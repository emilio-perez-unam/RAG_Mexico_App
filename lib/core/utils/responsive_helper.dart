import 'package:flutter/material.dart';

enum DeviceType { mobile, tablet, desktop }

class ResponsiveHelper {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  // Get device type
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < mobileBreakpoint) {
      return DeviceType.mobile;
    } else if (width < tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  // Check device type
  static bool isMobile(BuildContext context) {
    return getDeviceType(context) == DeviceType.mobile;
  }

  static bool isTablet(BuildContext context) {
    return getDeviceType(context) == DeviceType.tablet;
  }

  static bool isDesktop(BuildContext context) {
    return getDeviceType(context) == DeviceType.desktop;
  }

  // Get responsive value based on device type
  static T getValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  // Get responsive padding
  static EdgeInsets getScreenPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: getValue(
        context,
        mobile: 16,
        tablet: 24,
        desktop: 32,
      ),
      vertical: getValue(
        context,
        mobile: 16,
        tablet: 20,
        desktop: 24,
      ),
    );
  }

  // Get responsive spacing
  static double getSpacing(BuildContext context, {SpacingSize size = SpacingSize.medium}) {
    switch (size) {
      case SpacingSize.tiny:
        return getValue(context, mobile: 4, tablet: 6, desktop: 8);
      case SpacingSize.small:
        return getValue(context, mobile: 8, tablet: 10, desktop: 12);
      case SpacingSize.medium:
        return getValue(context, mobile: 16, tablet: 20, desktop: 24);
      case SpacingSize.large:
        return getValue(context, mobile: 24, tablet: 32, desktop: 40);
      case SpacingSize.extraLarge:
        return getValue(context, mobile: 32, tablet: 48, desktop: 64);
    }
  }

  // Get responsive font size
  static double getFontSize(BuildContext context, {FontSize size = FontSize.body}) {
    switch (size) {
      case FontSize.caption:
        return getValue(context, mobile: 12, tablet: 12, desktop: 13);
      case FontSize.body:
        return getValue(context, mobile: 14, tablet: 15, desktop: 16);
      case FontSize.subtitle:
        return getValue(context, mobile: 16, tablet: 17, desktop: 18);
      case FontSize.title:
        return getValue(context, mobile: 20, tablet: 22, desktop: 24);
      case FontSize.headline:
        return getValue(context, mobile: 24, tablet: 28, desktop: 32);
      case FontSize.display:
        return getValue(context, mobile: 32, tablet: 40, desktop: 48);
    }
  }

  // Get number of grid columns
  static int getGridColumns(BuildContext context, {int maxColumns = 4}) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1200) return 3;
    return maxColumns;
  }

  // Get responsive constraints
  static BoxConstraints getContentConstraints(BuildContext context) {
    return BoxConstraints(
      maxWidth: getValue(
        context,
        mobile: double.infinity,
        tablet: 720,
        desktop: 1200,
      ),
    );
  }
}

enum SpacingSize { tiny, small, medium, large, extraLarge }
enum FontSize { caption, body, subtitle, title, headline, display }

// Responsive layout widget
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveHelper.tabletBreakpoint) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= ResponsiveHelper.mobileBreakpoint) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}

// Responsive grid widget
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int maxColumns;
  final double spacing;
  final double runSpacing;
  final double childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.maxColumns = 4,
    this.spacing = 16,
    this.runSpacing = 16,
    this.childAspectRatio = 1,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveHelper.getGridColumns(context, maxColumns: maxColumns);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

// Responsive container with max width
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: padding ?? ResponsiveHelper.getScreenPadding(context),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? ResponsiveHelper.getContentConstraints(context).maxWidth,
        ),
        child: child,
      ),
    );
  }
}