import 'package:flutter/material.dart';

/// Layout breakpoints for Rafeeq public / auth screens.
abstract final class RafeeqBreakpoints {
  static const double mobile = 600;
  static const double tablet = 800;
  static const double desktopWide = 1200;
}

enum RafeeqScreenTier { compact, medium, expanded }

/// Read from [MediaQuery.sizeOf] — use inside build / LayoutBuilder.
class RafeeqResponsive {
  RafeeqResponsive._(this.width);

  final double width;

  factory RafeeqResponsive.of(BuildContext context) =>
      RafeeqResponsive._(MediaQuery.sizeOf(context).width);

  RafeeqScreenTier get tier {
    if (width < RafeeqBreakpoints.mobile) return RafeeqScreenTier.compact;
    if (width < RafeeqBreakpoints.tablet) return RafeeqScreenTier.medium;
    return RafeeqScreenTier.expanded;
  }

  bool get isCompact => width < RafeeqBreakpoints.mobile;
  bool get isMedium => width >= RafeeqBreakpoints.mobile && width < RafeeqBreakpoints.tablet;
  bool get isExpanded => width >= RafeeqBreakpoints.tablet;

  /// Side-by-side login / wide auth layouts.
  bool get useSplitAuthLayout => width >= RafeeqBreakpoints.tablet;

  /// Facility cards: single-column list below this width.
  bool get useFacilityListLayout => width < RafeeqBreakpoints.tablet;

  int get facilityGridCrossAxisCount {
    if (width < RafeeqBreakpoints.tablet) return 1;
    if (width < 1000) return 2;
    if (width < RafeeqBreakpoints.desktopWide) return 3;
    return 4;
  }

  double get horizontalPadding {
    if (isCompact) return 16;
    if (isMedium) return 20;
    return 24;
  }

  double get screenGutter => isCompact ? 12 : (isMedium ? 16 : 20);

  /// Max width for centered auth forms on wide monitors.
  double get authFormMaxWidth {
    if (isCompact) return width - horizontalPadding * 2;
    if (isMedium) return 480;
    return 500;
  }

  double get pageMaxWidth => isExpanded ? 1200 : width;

  double get backButtonTopInset => isCompact ? 4 : 8;
  double get backButtonStartInset => isCompact ? 8 : (isExpanded ? 20 : 12);

  T value<T>({required T compact, T? medium, required T expanded}) {
    switch (tier) {
      case RafeeqScreenTier.compact:
        return compact;
      case RafeeqScreenTier.medium:
        return medium ?? compact;
      case RafeeqScreenTier.expanded:
        return expanded;
    }
  }

  double scaleFont(double base) {
    if (isCompact) return base * 0.92;
    if (isExpanded && width > RafeeqBreakpoints.desktopWide) return base * 1.05;
    return base;
  }

  /// Dialog / sheet content width — never wider than the viewport.
  double dialogContentWidth({double desktopMax = 440}) {
    final available = width - horizontalPadding * 2;
    return available.clamp(280.0, desktopMax);
  }

  /// Standard [Dialog.insetPadding] for phones vs tablets.
  EdgeInsets get dialogInsetPadding {
    if (isCompact) return const EdgeInsets.symmetric(horizontal: 16, vertical: 24);
    return const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
  }

  /// Dashboard sidebar vs drawer + bottom nav.
  bool get useDashboardSidebar => width >= RafeeqBreakpoints.tablet + 100;
}

/// Picks [mobile] / [tablet] / [desktop] child by width (tablet falls back to mobile).
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    final r = RafeeqResponsive.of(context);
    if (r.isExpanded) return desktop;
    if (r.isMedium) return tablet ?? mobile;
    return mobile;
  }
}

/// Centers content with a max width on large screens.
class RafeeqContentWidth extends StatelessWidget {
  const RafeeqContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final r = RafeeqResponsive.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: r.horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}
