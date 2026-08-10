import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppRadius {
  AppRadius._();
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 32.0;
  static const full = 999.0;
}

class AppTextStyles {
  AppTextStyles._();

  static const _base = TextStyle(color: AppColors.textPrimary);

  static final heroTitle = _base.copyWith(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5);
  static final sectionTitle = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w700);
  static final cardTitle = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w700);
  static final body = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
  static final caption = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted);
  static final button = const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white);
}

/// Centralized ThemeData — wire this into MaterialApp(theme: AppTheme.dark).
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentStart,
        secondary: AppColors.accentEnd,
        surface: AppColors.surface,
      ),
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
