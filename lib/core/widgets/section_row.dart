import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/core/utils/responsive.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/home/presentation/see_all_screen.dart';
import 'poster_card.dart';

/// Generic — pass any `AsyncValue<List<Anime>>` provider result in.
/// One widget serves every horizontal row on the screen (Editor's
/// Picks today, Trending/Continue Watching later) instead of copy-
/// pasting near-identical ListView code per section.
class SectionRow extends StatelessWidget {
  final String title;
  final AsyncValue<List<Anime>> items;
  final String? eyebrow;

  const SectionRow({
    super.key,
    required this.title,
    required this.items,
    this.eyebrow,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null) ...[
                    Text(eyebrow!.toUpperCase(), style: AppTextStyles.label),
                    const SizedBox(height: 4),
                  ],
                  Text(title, style: AppTextStyles.sectionTitle),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                final currentItems = items.value;
                if (currentItems != null && currentItems.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          SeeAllScreen(title: title, animes: currentItems),
                    ),
                  );
                }
              },
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('See all'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: AppTextStyles.caption,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 6),
        SizedBox(
          height: r.posterCardWidth * 1.5 + 50,
          child: items.when(
            loading: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => Container(
                width: r.posterCardWidth,
                height: r.posterCardWidth * 1.5,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ),
            error: (err, _) => Container(
              width: double.infinity,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'This collection is temporarily unavailable',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
            data: (list) => ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final anime = list[i];
                return SizedBox(
                  width: r.posterCardWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PosterCard(
                        anime: anime,
                        width: r.posterCardWidth,
                        height: r.posterCardWidth * 1.5,
                        showTitleOverlay: false,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        anime.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (anime.year > 0) '${anime.year}',
                          if (anime.genre.isNotEmpty) anime.genre,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
