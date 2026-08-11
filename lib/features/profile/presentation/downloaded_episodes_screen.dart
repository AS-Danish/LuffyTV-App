import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/widgets/bouncing_button.dart';
import 'package:luffytv/features/downloads/providers/download_providers.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';
import 'package:luffytv/features/player/presentation/video_player_screen.dart';

class DownloadedEpisodesScreen extends ConsumerWidget {
  final String animeSlug;
  final String animeTitle;
  final String? posterUrl;

  const DownloadedEpisodesScreen({
    super.key, 
    required this.animeSlug,
    required this.animeTitle,
    this.posterUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadItemsProvider)
        .where((d) => d.animeSlug == animeSlug && d.state == DownloadState.completed)
        .toList();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(animeTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: downloads.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_done_rounded, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                    const SizedBox(height: 16),
                    Text('No downloaded episodes', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: downloads.length,
                itemBuilder: (context, index) {
                  final item = downloads[index];
                  final episode = item.episode;
                  
                  return BouncingButton(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(
                          animeTitle: animeTitle,
                          animeSlug: animeSlug,
                          episodeNumber: episode.episodeNumber,
                          isLocal: true,
                        ),
                      ));
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thumbnail
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 140,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: posterUrl != null 
                                    ? DecorationImage(image: NetworkImage(posterUrl!), fit: BoxFit.cover)
                                    : null,
                                  color: Colors.grey[900],
                                ),
                              ),
                              const Icon(Icons.play_circle_outline, color: Colors.white, size: 36),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(episode.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${episode.durationMinutes}m', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                const SizedBox(height: 8),
                                Text(
                                  episode.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white54),
                            onPressed: () {
                              ref.read(downloadItemsProvider.notifier).removeDownload(item.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${episode.title} removed from downloads'),
                                  backgroundColor: AppColors.surface,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
