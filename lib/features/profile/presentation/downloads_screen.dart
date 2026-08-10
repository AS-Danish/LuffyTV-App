import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';

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
                    Icon(Icons.download_done_rounded, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                    const SizedBox(height: 16),
                    Text('No downloaded anime yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
                  ],
                )
              );
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const Icon(Icons.settings, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    const Text('Smart Downloads', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const Icon(Icons.edit, color: Colors.white70, size: 20),
                  ],
                ),
                const SizedBox(height: 24),
                ...animes.map((anime) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 130,
                          height: 75,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: anime.posterUrl == null ? LinearGradient(
                              colors: AppColors.cardGradients[anime.gradientIndex % AppColors.cardGradients.length],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ) : null,
                            image: anime.posterUrl != null ? DecorationImage(image: NetworkImage(anime.posterUrl!), fit: BoxFit.cover) : null,
                          ),
                          child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 32)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(anime.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('12 Episodes • 2.4 GB', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
