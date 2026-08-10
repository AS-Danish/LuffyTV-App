import 'package:flutter/widgets.dart';

/// Simple breakpoint helper. Senior-dev rule of thumb: don't scatter
/// `MediaQuery.of(context).size.width > 600` checks across widgets —
/// centralize the breakpoints once and read semantic booleans instead.
class Responsive {
  final double width;
  const Responsive(this.width);

  factory Responsive.of(BuildContext context) => Responsive(MediaQuery.sizeOf(context).width);

  bool get isMobile => width < 600;
  bool get isTablet => width >= 600 && width < 1024;
  bool get isDesktop => width >= 1024;

  /// Horizontal screen padding scales with available width instead of
  /// being a fixed magic number everywhere.
  double get screenPadding => isMobile ? 20 : (isTablet ? 40 : 80);

  /// Poster card width scales too, so grids/rows don't look sparse or
  /// cramped just because the app happens to run on a tablet or web.
  double get posterCardWidth => isMobile ? 120 : (isTablet ? 150 : 170);

  double get heroCardWidth => isMobile ? 220 : (isTablet ? 300 : 360);
  double get heroCardHeight => isMobile ? 380 : (isTablet ? 480 : 540);
}
