import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:luffytv/core/widgets/poster_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reusing editorsPicks as mock favorites for now
    final favorites = ref.watch(editorsPicksProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 16, 12, 12),
                child: Text('My List', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: favorites.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentStart)),
                  error: (err, _) => Center(child: Text('Error loading favorites', style: AppTextStyles.body)),
                  data: (animes) {
                    if (animes.isEmpty) {
                      return Center(child: Text('No favorites yet', style: AppTextStyles.body));
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 120),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: animes.length,
                      itemBuilder: (context, index) {
                        return PosterCard(
                          anime: animes[index],
                          width: double.infinity,
                          height: double.infinity,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
