import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';

import 'package:luffytv/core/widgets/bouncing_button.dart';

class FloatingNav extends ConsumerWidget {
  const FloatingNav({super.key});

  static const _icons = [
    Icons.home_rounded,
    Icons.search_rounded,
    Icons.favorite_outline_rounded,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(selectedNavIndexProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_icons.length, (i) {
                final icon = _icons[i];
                final isSelected = i == navIndex;
                return BouncingButton(
                  onTap: () => ref.read(selectedNavIndexProvider.notifier).setIndex(i),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(icon, color: isSelected ? AppColors.accentStart : Colors.white70, size: 26),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
