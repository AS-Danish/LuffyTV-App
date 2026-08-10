import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:luffytv/core/widgets/poster_card.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reusing newEpisodes as mock downloaded data
    final downloads = ref.watch(newEpisodesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Downloads', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: downloads.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentStart)),
          error: (err, _) => Center(child: Text('Error loading downloads', style: AppTextStyles.body)),
          data: (animes) {
            if (animes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_done_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
                    const SizedBox(height: 16),
                    Text('No downloaded anime yet', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16)),
                  ],
                )
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: animes.length,
              itemBuilder: (context, index) {
                final anime = animes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 85,
                        height: 120,
                        child: PosterCard(anime: anime, width: 85, height: 120, radius: 16),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(anime.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('12 Episodes • 2.4 GB', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.accentStart, size: 16),
                                const SizedBox(width: 4),
                                const Text('Downloaded', style: TextStyle(color: AppColors.accentStart, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            )
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
