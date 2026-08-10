import 'package:flutter/material.dart';

/// All color tokens live here — nowhere else in the app should
/// hardcode a Color(0x...) value. Change the palette once, here.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0B0B0D);
  static const surface = Color(0xFF1C1C1F);
  static const border = Color(0xFF2E2E32);
  static const glass = Color(0xCC1C1C1F);

  static const accentStart = Color(0xFFFF6B1A);
  static const accentEnd = Color(0xFFFF8C42);

  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFFA0A0AC);
  static const textMuted = Color(0xFF6E6E76);

  static const accentGradient = LinearGradient(
    colors: [accentStart, accentEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const backgroundGradient = LinearGradient(
    colors: [Color(0xFF1A1420), Color(0xFF120E14), Color(0xFF0A0A0C)],
    stops: [0.0, 0.4, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// A handful of card-background gradients used as poster placeholders
  /// until real thumbnail images are wired in.
  static const cardGradients = [
    [Color(0xFF14324A), Color(0xFF081420)],
    [Color(0xFF3D1F1F), Color(0xFF190A0A)],
    [Color(0xFF1F2E1A), Color(0xFF0B120A)],
    [Color(0xFF2A1B45), Color(0xFF10081C)],
    [Color(0xFF123D3D), Color(0xFF041515)],
  ];
}
