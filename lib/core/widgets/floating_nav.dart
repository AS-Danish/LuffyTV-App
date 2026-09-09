import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';

class FloatingNav extends ConsumerWidget {
  const FloatingNav({super.key});
  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.search_rounded, label: 'Search'),
    (icon: Icons.bookmark_outline_rounded, label: 'My List'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedNavIndexProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: AppColors.bg,
        child: SafeArea(
          top: false,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 640),
            height: 66,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border, width: .5),
              ),
            ),
            child: Row(
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final active = index == selected;
                return Expanded(
                  child: Semantics(
                    selected: active,
                    button: true,
                    label: item.label,
                    child: InkWell(
                      onTap: () => ref
                          .read(selectedNavIndexProvider.notifier)
                          .setIndex(index),
                      child: AnimatedContainer(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: active ? 1.06 : 1,
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              child: Icon(
                                item.icon,
                                size: 24,
                                color: active
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: active
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
