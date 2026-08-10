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
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = Responsive.of(context);
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
                SectionRow(title: "Editor's Picks", items: editorsPicks),
                const SizedBox(height: 32),
                SectionRow(title: "Trending Now", items: trendingNow),
                const SizedBox(height: 32),
                SectionRow(title: "New Episodes", items: newEpisodes),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
