import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/downloads/providers/download_providers.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/player/presentation/video_player_screen.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadItemsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'Downloads',
          style: AppTextStyles.heroTitle.copyWith(fontSize: 23),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: downloads.isEmpty
            ? Center(
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
                        Icons.download_for_offline_outlined,
                        size: 32,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('No downloads yet', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 8),
                    Text(
                      'Movies and episodes you download will appear here.',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 40, top: 10),
                itemCount: downloads.length,
                itemBuilder: (context, index) {
                  final item = downloads[index];

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            // Thumbnail
                            Container(
                              width: 112,
                              height: 68,
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                image: item.posterUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(item.posterUrl!),
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.high,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.animeTitle,
                                    style: AppTextStyles.cardTitle.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.episode.title} • Ep ${item.episode.episodeNumber}',
                                    style: AppTextStyles.caption,
                                  ),
                                  const SizedBox(height: 8),
                                  if (item.state ==
                                      DownloadState.downloading) ...[
                                    LinearProgressIndicator(
                                      value: item.progress,
                                      backgroundColor: AppColors.border,
                                      color: AppColors.accentStart,
                                      minHeight: 3,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(item.progress * 100).toInt()}%',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 10,
                                      ),
                                    ),
                                  ] else if (item.state ==
                                      DownloadState.completed) ...[
                                    Text(
                                      'Downloaded',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.greenAccent,
                                      ),
                                    ),
                                  ] else if (item.state ==
                                      DownloadState.failed) ...[
                                    Text(
                                      'Failed',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Action button
                            IconButton(
                              tooltip: item.state == DownloadState.completed
                                  ? 'Play download'
                                  : 'Cancel download',
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.surfaceSoft,
                              ),
                              icon: item.state == DownloadState.completed
                                  ? const Icon(
                                      Icons.play_circle_fill,
                                      size: 36,
                                      color: AppColors.textPrimary,
                                    )
                                  : const Icon(
                                      Icons.close,
                                      color: AppColors.textSecondary,
                                    ),
                              onPressed: () {
                                if (item.state == DownloadState.completed) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => VideoPlayerScreen(
                                        animeTitle: item.animeTitle,
                                        animeSlug: item.animeSlug,
                                        episodeNumber:
                                            item.episode.episodeNumber,
                                        isLocal: true,
                                        anime: Anime(
                                          id: item.animeSlug,
                                          title: item.animeTitle,
                                          genre: '',
                                          year: 0,
                                          posterUrl: item.posterUrl,
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  ref
                                      .read(downloadItemsProvider.notifier)
                                      .removeDownload(item.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
