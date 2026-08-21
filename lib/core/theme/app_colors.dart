import 'package:flutter/material.dart';

/// All color tokens live here — nowhere else in the app should
/// hardcode a Color(0x...) value. Change the palette once, here.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF08090B);
  static const surface = Color(0xFF111216);
  static const surfaceRaised = Color(0xFF191A20);
  static const surfaceSoft = Color(0xFF202128);
  static const border = Color(0xFF2A2B33);
  static const glass = Color(0xD914151A);

  static const accentStart = Color(0xFFFF6315);
  static const accentEnd = Color(0xFFFF9A55);
  static const success = Color(0xFF70D68E);
  static const warning = Color(0xFFFFC46B);
  static const error = Color(0xFFFF6B78);

  static const textPrimary = Color(0xFFF7F7F8);
  static const textSecondary = Color(0xFFA7A8B0);
  static const textMuted = Color(0xFF73757F);

  static const accentGradient = LinearGradient(
    colors: [accentStart, accentEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const backgroundGradient = LinearGradient(
    colors: [Color(0xFF17120F), Color(0xFF0D0E12), bg],
    stops: [0.0, 0.32, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// A handful of card-background gradients used as poster placeholders
  /// until real thumbnail images are wired in.
  static const cardGradients = [
    [Color(0xFF17344B), Color(0xFF0A111A)],
    [Color(0xFF45241F), Color(0xFF170B09)],
    [Color(0xFF24371E), Color(0xFF0B1409)],
    [Color(0xFF31204A), Color(0xFF11091A)],
    [Color(0xFF174142), Color(0xFF061616)],
  ];
}
