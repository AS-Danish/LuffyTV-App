import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';

class FloatingNav extends ConsumerWidget {
  const FloatingNav({super.key});

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.search_rounded, label: 'Discover'),
    (icon: Icons.bookmark_outline_rounded, label: 'My List'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(selectedNavIndexProvider);

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? 10 : 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.11),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .38),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  children: List.generate(_items.length, (i) {
                    final item = _items[i];
                    final isSelected = i == navIndex;
                    return Expanded(
                      child: Semantics(
                        selected: isSelected,
                        button: true,
                        label: item.label,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(17),
                          onTap: () => ref
                              .read(selectedNavIndexProvider.notifier)
                              .setIndex(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accentStart.withValues(alpha: .14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accentStart.withValues(
                                        alpha: .26,
                                      )
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item.icon,
                                  color: isSelected
                                      ? AppColors.accentEnd
                                      : AppColors.textMuted,
                                  size: 23,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted,
                                    fontSize: 9.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
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
        ),
      ),
    );
  }
}
