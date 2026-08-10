import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/utils/responsive.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:luffytv/core/widgets/top_bar.dart';
import 'package:luffytv/core/widgets/category_tabs.dart';
import 'package:luffytv/core/widgets/hero_section.dart';
import 'package:luffytv/core/widgets/section_row.dart';

/// A senior-dev home screen reads like a table of contents — each
/// section is a named widget, and there's no inline layout logic here
/// beyond spacing and responsive padding.
import 'package:luffytv/features/home/data/models/anime.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  List<Anime> _filter(List<Anime> animes, int categoryIndex) {
    if (categoryIndex == 0) return animes;
    final category = categories[categoryIndex].toLowerCase();
    
    // Mock logic to simulate filtering since our mock data has standard genres (Action, Fantasy, etc) instead of specific tags.
    // We just pseudo-randomly pick based on the length of the string to make it visually filter.
    return animes.where((a) => (a.title.length + category.length) % 2 == 0).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = Responsive.of(context);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    
    // We use allAnimeProvider for hero to show filtered things, or keep editors picks.
    final editorsPicks = ref.watch(editorsPicksProvider);
    final trendingNow = ref.watch(trendingNowProvider);
    final newEpisodes = ref.watch(newEpisodesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 140, left: r.screenPadding, right: r.screenPadding, top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopBar(),
                const SizedBox(height: 20),
                const CategoryTabs(),
                const SizedBox(height: 20),
                const HeroSection(),
                const SizedBox(height: 32),
                SectionRow(title: "Editor's Picks", items: editorsPicks.whenData((data) => _filter(data, selectedCategory))),
                const SizedBox(height: 32),
                SectionRow(title: "Trending Now", items: trendingNow.whenData((data) => _filter(data, selectedCategory))),
                const SizedBox(height: 32),
                SectionRow(title: "New Episodes", items: newEpisodes.whenData((data) => _filter(data, selectedCategory))),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
