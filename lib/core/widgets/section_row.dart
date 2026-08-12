import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/core/utils/responsive.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/home/presentation/see_all_screen.dart';
import 'poster_card.dart';

/// Generic — pass any AsyncValue<List<Anime>> provider result in.
/// One widget serves every horizontal row on the screen (Editor's
/// Picks today, Trending/Continue Watching later) instead of copy-
/// pasting near-identical ListView code per section.
class SectionRow extends StatelessWidget {
  final String title;
  final AsyncValue<List<Anime>> items;

  const SectionRow({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: AppTextStyles.sectionTitle),
            GestureDetector(
              onTap: () {
                final currentItems = items.value;
                if (currentItems != null && currentItems.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SeeAllScreen(title: title, animes: currentItems),
                    ),
                  );
                }
              },
              child: Text('See All', style: AppTextStyles.caption.copyWith(color: AppColors.accentStart)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 6),
        SizedBox(
          height: r.posterCardWidth * 1.4,
          child: items.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentStart)),
            error: (err, _) => Center(child: Text('Failed to load', style: AppTextStyles.body)),
            data: (list) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => PosterCard(
                anime: list[i],
                width: r.posterCardWidth,
                height: r.posterCardWidth * 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
