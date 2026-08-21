import 'package:flutter/widgets.dart';

/// Simple breakpoint helper. Senior-dev rule of thumb: don't scatter
/// `MediaQuery.of(context).size.width > 600` checks across widgets —
/// centralize the breakpoints once and read semantic booleans instead.
class Responsive {
  final double width;
  const Responsive(this.width);

  factory Responsive.of(BuildContext context) =>
      Responsive(MediaQuery.sizeOf(context).width);

  bool get isMobile => width < 600;
  bool get isTablet => width >= 600 && width < 1024;
  bool get isDesktop => width >= 1024;

  /// Horizontal screen padding scales with available width instead of
  /// being a fixed magic number everywhere.
  double get screenPadding => isMobile ? 18 : (isTablet ? 32 : 56);

  double get contentMaxWidth => 1440;

  int get gridColumns {
    if (width < 390) return 2;
    if (width < 700) return 3;
    if (width < 1050) return 4;
    return 6;
  }

  /// Poster card width scales too, so grids/rows don't look sparse or
  /// cramped just because the app happens to run on a tablet or web.
  double get posterCardWidth =>
      width < 390 ? 116 : (isMobile ? 132 : (isTablet ? 154 : 176));

  double get heroCardWidth => isMobile ? width - 36 : (isTablet ? 560 : 720);
  double get heroCardHeight => isMobile ? 470 : (isTablet ? 500 : 540);
}
