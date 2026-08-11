import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/details/providers/details_providers.dart';
import 'package:luffytv/features/downloads/providers/download_providers.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';

class AnimeDetailsScreen extends ConsumerStatefulWidget {
  final Anime anime;

  const AnimeDetailsScreen({super.key, required this.anime});

  @override
  ConsumerState<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends ConsumerState<AnimeDetailsScreen> {
  int _selectedChunkIndex = 0;
  bool _isDescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(animeDetailProvider(widget.anime.id));
    final episodesAsync = ref.watch(animeEpisodesProvider(widget.anime.id));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350.0,
            pinned: true,
            backgroundColor: AppColors.bg,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.anime.title,
                style: AppTextStyles.heroTitle.copyWith(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.anime.posterUrl ?? '',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Container(color: AppColors.cardGradients[0][0]),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, AppColors.bg],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: detailAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator(color: AppColors.accentStart)),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(child: Text('Error loading details: $err', style: AppTextStyles.body)),
              ),
              data: (detail) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (detail.year.isNotEmpty) ...[
                            Text(detail.year, style: AppTextStyles.body),
                            const SizedBox(width: 12),
                          ],
                          if (detail.rating.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(detail.rating, style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (detail.episodeCount > 0) ...[
                            Text('${detail.episodeCount} Episodes', style: AppTextStyles.body),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.play_arrow, color: Colors.white),
                              label: Text('Play', style: AppTextStyles.button),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ).copyWith(
                                backgroundColor: WidgetStateProperty.resolveWith((states) => AppColors.accentStart),
                              ),
                            ),
                          ),
                          if (detail.episodeCount == 1) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.download, color: AppColors.textPrimary),
                                label: Text('Download', style: AppTextStyles.button),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.border),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.description,
                            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, height: 1.5),
                            maxLines: _isDescriptionExpanded ? null : 3,
                            overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                            child: Text(
                              _isDescriptionExpanded ? 'Read less' : 'Read more',
                              style: AppTextStyles.caption.copyWith(color: AppColors.accentStart, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (detail.genres.isNotEmpty) ...[
                        Text('Genres: ${detail.genres.join(', ')}', style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                      ],
                      if (detail.studios.isNotEmpty) ...[
                        Text('Studios: ${detail.studios.join(', ')}', style: AppTextStyles.caption),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
          ),
          episodesAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator(color: AppColors.accentStart)),
              ),
            ),
            error: (err, stack) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(child: Text('Error loading episodes', style: AppTextStyles.body)),
              ),
            ),
            data: (episodes) {
              if (episodes.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(child: Text('No episodes found.', style: AppTextStyles.body)),
                  ),
                );
              }

              final int chunkSize = 100;
              final int totalChunks = (episodes.length / chunkSize).ceil();
              
              // Determine current chunk episodes
              final startIndex = _selectedChunkIndex * chunkSize;
              final endIndex = (startIndex + chunkSize > episodes.length) ? episodes.length : startIndex + chunkSize;
              final chunkEpisodes = episodes.sublist(startIndex, endIndex);

              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Episodes', style: AppTextStyles.sectionTitle),
                          if (totalChunks > 1)
                            DropdownButton<int>(
                              value: _selectedChunkIndex,
                              dropdownColor: AppColors.bg,
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
                              items: List.generate(totalChunks, (index) {
                                final start = index * chunkSize + 1;
                                final end = (index * chunkSize + chunkSize > episodes.length) ? episodes.length : index * chunkSize + chunkSize;
                                return DropdownMenuItem(
                                  value: index,
                                  child: Text('$start - $end', style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
                                );
                              }),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedChunkIndex = value;
                                  });
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final ep = chunkEpisodes[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            width: 120,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(8),
                              image: widget.anime.posterUrl != null ? DecorationImage(
                                image: NetworkImage(widget.anime.posterUrl!),
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.4), BlendMode.darken),
                              ) : null,
                            ),
                            child: const Icon(Icons.play_circle_outline, color: AppColors.textPrimary, size: 32),
                          ),
                          title: Text(ep.title, style: AppTextStyles.cardTitle.copyWith(color: AppColors.textPrimary)),
                          subtitle: Text('Episode ${ep.episodeNumber}', style: AppTextStyles.caption),
                          trailing: Consumer(
                            builder: (context, ref, child) {
                              final downloads = ref.watch(downloadItemsProvider);
                              final downloadId = '${widget.anime.id}_${ep.episodeNumber}';
                              final currentDownload = downloads.where((d) => d.id == downloadId).firstOrNull;

                              if (currentDownload != null) {
                                if (currentDownload.state == DownloadState.downloading) {
                                  return SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      value: currentDownload.progress,
                                      strokeWidth: 2.5,
                                      backgroundColor: AppColors.border,
                                      color: AppColors.accentStart,
                                    ),
                                  );
                                } else if (currentDownload.state == DownloadState.completed) {
                                  return const Icon(Icons.check_circle, color: AppColors.accentStart);
                                }
                              }

                              return IconButton(
                                icon: const Icon(Icons.download, color: AppColors.textSecondary),
                                onPressed: () {
                                  ref.read(downloadItemsProvider.notifier).startDownload(widget.anime, ep);
                                },
                              );
                            },
                          ),
                          onTap: () {},
                        );
                      },
                      childCount: chunkEpisodes.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
