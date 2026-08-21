import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/core/utils/responsive.dart';
import 'package:luffytv/core/widgets/poster_card.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = Responsive.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: ValueListenableBuilder(
            valueListenable: Hive.box('my_list').listenable(),
            builder: (context, box, _) {
              final favorites = LocalDbService.getMyList();
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      responsive.screenPadding,
                      28,
                      responsive.screenPadding,
                      20,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR LIBRARY',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.accentEnd,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text('My List', style: AppTextStyles.display),
                          const SizedBox(height: 8),
                          Text(
                            favorites.isEmpty
                                ? 'Save a title and it will be waiting here.'
                                : '${favorites.length} saved ${favorites.length == 1 ? 'title' : 'titles'} · available on this device',
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (favorites.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(30, 0, 30, 120),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceRaised,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                Icons.bookmark_add_outlined,
                                color: AppColors.textMuted,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Build a watchlist you love',
                              style: AppTextStyles.sectionTitle,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Browse the catalog and tap + on any title.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body,
                            ),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              onPressed: () => ref
                                  .read(selectedNavIndexProvider.notifier)
                                  .setIndex(1),
                              icon: const Icon(Icons.explore_outlined),
                              label: const Text('Discover anime'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        responsive.screenPadding,
                        0,
                        responsive.screenPadding,
                        130,
                      ),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: responsive.gridColumns,
                          childAspectRatio: .57,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 18,
                        ),
                        itemCount: favorites.length,
                        itemBuilder: (context, index) {
                          final anime = favorites[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: PosterCard(
                                  anime: anime,
                                  width: double.infinity,
                                  height: double.infinity,
                                  radius: AppRadius.md,
                                  showTitleOverlay: false,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                anime.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.cardTitle,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  if (anime.year > 0) '${anime.year}',
                                  if (anime.genre.isNotEmpty) anime.genre,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
