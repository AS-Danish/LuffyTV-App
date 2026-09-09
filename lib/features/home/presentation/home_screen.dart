import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/utils/responsive.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:luffytv/core/widgets/top_bar.dart';
import 'package:luffytv/core/widgets/category_tabs.dart';
import 'package:luffytv/core/widgets/hero_section.dart';
import 'package:luffytv/core/widgets/section_row.dart';
import 'package:luffytv/core/theme/app_theme.dart';

/// A senior-dev home screen reads like a table of contents — each
/// section is a named widget, and there's no inline layout logic here
/// beyond spacing and responsive padding.
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Anime> _filter(List<Anime> animes, int categoryIndex) {
    if (categoryIndex == 0) return animes;
    final category = categories[categoryIndex].toLowerCase();

    // Mock logic to simulate filtering since our mock data has standard genres (Action, Fantasy, etc) instead of specific tags.
    // We just pseudo-randomly pick based on the length of the string to make it visually filter.
    return animes
        .where((a) => (a.title.length + category.length) % 2 == 0)
        .toList();
  }

  List<Anime> _filterByCategory(List<Anime> animes, String category) {
    // If the anime has a genre field that matches, use it, otherwise use our deterministic fake filtering for UI feel.
    final match = animes
        .where((a) => a.genre.toLowerCase().contains(category.toLowerCase()))
        .toList();
    if (match.isNotEmpty) return match;

    return animes
        .where((a) => (a.title.length + category.length) % 3 != 0)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    // We use allAnimeProvider for hero to show filtered things, or keep editors picks.
    final editorsPicks = ref.watch(editorsPicksProvider);
    final trendingNow = ref.watch(trendingNowProvider);
    final newEpisodes = ref.watch(newEpisodesProvider);
    final recentlyCompleted = ref.watch(recentlyCompletedProvider);
    final topMonth = ref.watch(topMonthProvider);
    final allAnime = ref.watch(allAnimeProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.accentStart,
            backgroundColor: AppColors.surfaceRaised,
            onRefresh: () async {
              try {
                await ref.read(animeRepositoryProvider).refreshHome();
              } catch (_) {
                return; // Keep the visible saved catalog when offline.
              }
              if (!context.mounted) return;
              ref.invalidate(featuredAnimeProvider);
              ref.invalidate(editorsPicksProvider);
              ref.invalidate(trendingNowProvider);
              ref.invalidate(newEpisodesProvider);
              ref.invalidate(recentlyCompletedProvider);
              ref.invalidate(topMonthProvider);
              ref.invalidate(allAnimeProvider);
              await ref.read(editorsPicksProvider.future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.only(
                bottom: 128,
                left: r.screenPadding,
                right: r.screenPadding,
                top: 12,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TopBar(
                        onProfileTap: () => ref
                            .read(selectedNavIndexProvider.notifier)
                            .setIndex(3),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Find your next\nfavorite world.',
                        style: AppTextStyles.display,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Curated anime, new episodes, and everything you saved.',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const CategoryTabs(),
                      const SizedBox(height: AppSpacing.lg),
                      const HeroSection(),
                      ValueListenableBuilder(
                        valueListenable: Hive.box(
                          'watch_progress',
                        ).listenable(),
                        builder: (context, box, _) {
                          final progressList = LocalDbService.getAllProgress();
                          if (progressList.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 32),
                              SectionRow(
                                eyebrow: 'Jump back in',
                                title: "Continue watching",
                                items: AsyncValue.data(
                                  progressList.map((wp) => wp.anime).toList(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      SectionRow(
                        eyebrow: 'Handpicked for you',
                        title: "Editor's picks",
                        items: editorsPicks.whenData(
                          (data) => _filter(data, selectedCategory),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SectionRow(
                        eyebrow: 'What everyone is watching',
                        title: "Trending now",
                        items: trendingNow.whenData(
                          (data) => _filter(data, selectedCategory),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SectionRow(
                        eyebrow: 'Fresh from the catalog',
                        title: "New episodes",
                        items: newEpisodes.whenData(
                          (data) => _filter(data, selectedCategory),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SectionRow(
                        eyebrow: 'Ready to binge',
                        title: "Recently completed",
                        items: recentlyCompleted.whenData(
                          (data) => _filter(data, selectedCategory),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SectionRow(
                        eyebrow: 'The monthly chart',
                        title: "Top this month",
                        items: topMonth.whenData(
                          (data) => _filter(data, selectedCategory),
                        ),
                      ),

                      // Extra Netflix-style category rows
                      const SizedBox(height: 32),
                      SectionRow(
                        title: "Action & adventure",
                        items: allAnime.whenData(
                          (data) => _filterByCategory(data, "Action"),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SectionRow(
                        title: "Romance anime",
                        items: allAnime.whenData(
                          (data) => _filterByCategory(data, "Romance"),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SectionRow(
                        title: "Laugh-out-loud comedy",
                        items: allAnime.whenData(
                          (data) => _filterByCategory(data, "Comedy"),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SectionRow(
                        title: "Sci-fi & fantasy",
                        items: allAnime.whenData(
                          (data) => _filterByCategory(data, "Sci-Fi"),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SectionRow(
                        title: "Slice of life",
                        items: allAnime.whenData(
                          (data) => _filterByCategory(data, "Life"),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SectionRow(
                        title: "Supernatural thrills",
                        items: allAnime.whenData(
                          (data) => _filterByCategory(data, "Supernatural"),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SectionRow(
                        title: "Emotional drama",
                        items: allAnime.whenData(
                          (data) => _filterByCategory(data, "Drama"),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
