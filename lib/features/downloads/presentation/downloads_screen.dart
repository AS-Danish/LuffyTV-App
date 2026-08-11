import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/downloads/providers/download_providers.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadItemsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Downloads', style: AppTextStyles.heroTitle.copyWith(fontSize: 24)),
      ),
      body: downloads.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.download_for_offline, size: 80, color: AppColors.border),
                  const SizedBox(height: 16),
                  Text('No downloads yet', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 8),
                  Text('Movies and episodes you download will appear here.', 
                    style: AppTextStyles.body, textAlign: TextAlign.center),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 120, top: 16),
              itemCount: downloads.length,
              itemBuilder: (context, index) {
                final item = downloads[index];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Thumbnail
                      Container(
                        width: 130,
                        height: 74,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(8),
                          image: item.posterUrl != null ? DecorationImage(
                            image: NetworkImage(item.posterUrl!),
                            fit: BoxFit.cover,
                          ) : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.animeTitle, style: AppTextStyles.cardTitle.copyWith(color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('${item.episode.title} • Ep ${item.episode.episodeNumber}', style: AppTextStyles.caption),
                            const SizedBox(height: 8),
                            if (item.state == DownloadState.downloading) ...[
                              LinearProgressIndicator(
                                value: item.progress,
                                backgroundColor: AppColors.border,
                                color: AppColors.accentStart,
                                minHeight: 4,
                              ),
                              const SizedBox(height: 4),
                              Text('${(item.progress * 100).toInt()}%', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                            ] else if (item.state == DownloadState.completed) ...[
                              Text('Downloaded', style: AppTextStyles.caption.copyWith(color: Colors.greenAccent)),
                            ] else if (item.state == DownloadState.failed) ...[
                              Text('Failed', style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
                            ]
                          ],
                        ),
                      ),
                      // Action button
                      IconButton(
                        icon: item.state == DownloadState.completed 
                            ? const Icon(Icons.play_circle_fill, size: 36, color: AppColors.textPrimary)
                            : const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () {
                          if (item.state == DownloadState.completed) {
                            // Play video
                          } else {
                            // Cancel or delete download
                            ref.read(downloadItemsProvider.notifier).removeDownload(item.id);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
