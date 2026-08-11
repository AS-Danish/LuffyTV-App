import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/downloads/providers/download_providers.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';
import 'package:luffytv/features/profile/presentation/downloaded_episodes_screen.dart';
import 'package:luffytv/core/widgets/bouncing_button.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadItemsProvider);
    
    // Group downloads by anime
    final Map<String, List<DownloadItem>> groupedDownloads = {};
    for (var item in downloads) {
      if (item.state == DownloadState.completed) {
        groupedDownloads.putIfAbsent(item.animeSlug, () => []).add(item);
      }
    }

    final animeSlugs = groupedDownloads.keys.toList();

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
        child: animeSlugs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_done_rounded, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                    const SizedBox(height: 16),
                    Text('No downloaded anime yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
                  ],
                )
              )
            : ListView(
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
                  ...animeSlugs.map((slug) {
                    final items = groupedDownloads[slug]!;
                    final title = items.first.animeTitle;
                    final poster = items.first.posterUrl;
                    
                    return BouncingButton(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DownloadedEpisodesScreen(
                            animeSlug: slug,
                            animeTitle: title,
                            posterUrl: poster,
                          ),
                        ));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 130,
                              height: 75,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                image: poster != null ? DecorationImage(image: NetworkImage(poster), fit: BoxFit.cover) : null,
                                color: AppColors.border,
                              ),
                              child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 32)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('${items.length} Episodes', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
