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
                      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 120),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: animes.length,
                      itemBuilder: (context, index) {
                        final anime = animes[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: PosterCard(
                                anime: anime,
                                width: double.infinity,
                                height: double.infinity,
                                radius: 8.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              anime.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
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
