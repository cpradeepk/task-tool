import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    Key? key,
    required this.mobile,
    this.tablet,
    this.desktop,
  }) : super(key: key);

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= 1200) {
      return desktop ?? tablet ?? mobile;
    } else if (screenWidth >= 768) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints) builder;

  const ResponsiveBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: builder);
  }
}

class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T? desktop;

  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  T getValue(BuildContext context) {
    if (ResponsiveLayout.isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    } else if (ResponsiveLayout.isTablet(context)) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }
}

// Responsive padding helper
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets mobile;
  final EdgeInsets? tablet;
  final EdgeInsets? desktop;

  const ResponsivePadding({
    Key? key,
    required this.child,
    required this.mobile,
    this.tablet,
    this.desktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    EdgeInsets padding;
    
    if (ResponsiveLayout.isDesktop(context)) {
      padding = desktop ?? tablet ?? mobile;
    } else if (ResponsiveLayout.isTablet(context)) {
      padding = tablet ?? mobile;
    } else {
      padding = mobile;
    }

    return Padding(
      padding: padding,
      child: child,
    );
  }
}

// Responsive grid helper
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final double spacing;
  final double runSpacing;
  final double? childAspectRatio;

  const ResponsiveGrid({
    Key? key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns,
    this.desktopColumns,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.childAspectRatio,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int columns;
    
    if (ResponsiveLayout.isDesktop(context)) {
      columns = desktopColumns ?? tabletColumns ?? mobileColumns;
    } else if (ResponsiveLayout.isTablet(context)) {
      columns = tabletColumns ?? mobileColumns;
    } else {
      columns = mobileColumns;
    }

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: runSpacing,
      childAspectRatio: childAspectRatio ?? 1.0,
      children: children,
    );
  }
}

// Responsive wrap helper
class ResponsiveWrap extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;
  final WrapCrossAlignment crossAxisAlignment;

  const ResponsiveWrap({
    Key? key,
    required this.children,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.alignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }
}

// Responsive container with max width
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const ResponsiveContainer({
    Key? key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
      ),
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}

// Responsive sidebar layout
class ResponsiveSidebarLayout extends StatelessWidget {
  final Widget sidebar;
  final Widget body;
  final double sidebarWidth;
  final bool showSidebarOnMobile;

  const ResponsiveSidebarLayout({
    Key? key,
    required this.sidebar,
    required this.body,
    this.sidebarWidth = 300,
    this.showSidebarOnMobile = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isMobile(context) && !showSidebarOnMobile) {
      return body;
    }

    return Row(
      children: [
        SizedBox(
          width: sidebarWidth,
          child: sidebar,
        ),
        Expanded(child: body),
      ],
    );
  }
}
