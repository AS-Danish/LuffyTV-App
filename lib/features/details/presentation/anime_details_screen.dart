import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/details/providers/details_providers.dart';
import 'package:luffytv/features/downloads/providers/download_providers.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';
import 'package:luffytv/features/player/presentation/video_player_screen.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:luffytv/core/widgets/poster_card.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:luffytv/core/utils/api_constants.dart';
import 'package:http/http.dart' as http;
import 'package:luffytv/features/home/data/models/episode.dart';

class AnimeDetailsScreen extends ConsumerStatefulWidget {
  final Anime anime;

  const AnimeDetailsScreen({super.key, required this.anime});

  @override
  ConsumerState<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends ConsumerState<AnimeDetailsScreen> {
  int _selectedChunkIndex = 0;
  bool _isDescriptionExpanded = false;
  late bool _isInMyList;

  @override
  void initState() {
    super.initState();
    _isInMyList = LocalDbService.isInMyList(widget.anime.id);
    
    final progress = LocalDbService.getProgress(widget.anime.id);
    if (progress != null && progress.lastWatchedEpisode > 0) {
      _selectedChunkIndex = (progress.lastWatchedEpisode - 1) ~/ 100;
    }
  }

  void _toggleMyList() {
    setState(() {
      _isInMyList = !_isInMyList;
    });
    if (_isInMyList) {
      LocalDbService.addToMyList(widget.anime);
    } else {
      LocalDbService.removeFromMyList(widget.anime.id);
    }
  }

  void _showDownloadQualityDialog(BuildContext context, Anime anime, Episode ep, WidgetRef ref) async {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.accentStart))
    );
    
    try {
      final repo = ref.read(animeRepositoryProvider);
      final watchData = await repo.fetchWatchData(anime.id, ep.episodeNumber);
      
      final bestSource = watchData.sources.firstWhere(
        (s) => s.type == 'sub' && s.m3u8 != null, 
        orElse: () => watchData.sources.first
      );
      
      String m3u8Url = bestSource.proxyUrl ?? bestSource.m3u8 ?? bestSource.url;
      if (m3u8Url.startsWith('/api')) m3u8Url = '${ApiConstants.baseUrl}$m3u8Url';
      if (m3u8Url.startsWith('/')) m3u8Url = '${ApiConstants.baseUrl}$m3u8Url';
      
      final response = await http.get(Uri.parse(m3u8Url));
      final lines = response.body.split('\n');
      
      List<Map<String, String>> qualities = [];
      
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('#EXT-X-STREAM-INF')) {
          final resMatch = RegExp(r'RESOLUTION=(\d+x\d+)').firstMatch(lines[i]);
          final resolution = resMatch != null ? resMatch.group(1) : 'Unknown';
          
          String formattedRes = resolution ?? 'Unknown';
          if (formattedRes != 'Unknown' && formattedRes.contains('x')) {
            formattedRes = '${formattedRes.split('x').last}p';
          }
          
          if (i + 1 < lines.length) {
            String variantUrl = lines[i+1].trim();
            if (!variantUrl.startsWith('http')) {
               final uri = Uri.parse(m3u8Url);
               variantUrl = uri.resolve(variantUrl).toString();
            }
            qualities.add({'resolution': formattedRes, 'url': variantUrl});
          }
        }
      }
      
      if (context.mounted) Navigator.pop(context); // pop loading
      
      if (qualities.isEmpty) {
        ref.read(downloadItemsProvider.notifier).startDownload(anime, ep, m3u8Url);
        return;
      }
      
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1A1A1A),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Select Download Quality', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  ...qualities.map((q) => ListTile(
                    title: Text(q['resolution']!, style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.download, color: AppColors.accentStart),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(downloadItemsProvider.notifier).startDownload(anime, ep, q['url']!);
                    }
                  )),
                ],
              ),
            );
          }
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load qualities', style: TextStyle(color: Colors.white))));
      }
    }
  }

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
            centerTitle: true,
            backgroundColor: AppColors.bg,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                widget.anime.title,
                style: AppTextStyles.heroTitle.copyWith(fontSize: 18),
                textAlign: TextAlign.center,
                maxLines: 3,
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
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => VideoPlayerScreen(
                                    animeTitle: widget.anime.title,
                                    animeSlug: widget.anime.id,
                                    episodeNumber: 1, // Default to episode 1 for main play button
                                    anime: widget.anime,
                                  ),
                                ));
                              },
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _toggleMyList,
                              icon: Icon(
                                _isInMyList ? Icons.check : Icons.add,
                                color: AppColors.textPrimary,
                              ),
                              label: Text('My List', style: AppTextStyles.button),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
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
                      if (detail.seasons.isNotEmpty) ...[
                        Text('Related Seasons', style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200, // accommodate poster + title
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: detail.seasons.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final season = detail.seasons[index];
                              // Convert RelatedSeason to Anime so we can reuse PosterCard
                              final relatedAnime = Anime(
                                id: season.slug ?? season.id,
                                title: season.title,
                                genre: season.relation ?? 'Related', // use genre field for relation badge
                                year: 0,
                                posterUrl: season.posterUrl,
                              );
                              return PosterCard(
                                anime: relatedAnime,
                                width: 120,
                                height: 180,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Episode ${ep.episodeNumber}', style: AppTextStyles.caption),
                              ValueListenableBuilder(
                                valueListenable: Hive.box('watch_progress').listenable(keys: [widget.anime.id]),
                                builder: (context, _, __) {
                                  final prog = LocalDbService.getProgress(widget.anime.id);
                                  double percentage = 0.0;
                                  if (prog != null) {
                                    final epProgress = prog.episodes[ep.episodeNumber.toString()];
                                    if (epProgress != null && epProgress.durationSeconds > 0) {
                                      percentage = (epProgress.positionSeconds / epProgress.durationSeconds).clamp(0.0, 1.0);
                                    }
                                  }
                                  if (percentage > 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0, right: 16.0),
                                      child: LinearProgressIndicator(
                                        value: percentage,
                                        backgroundColor: AppColors.border,
                                        color: AppColors.accentStart,
                                        minHeight: 4,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }
                              ),
                            ],
                          ),
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
                                  _showDownloadQualityDialog(context, widget.anime, ep, ref);
                                },
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => VideoPlayerScreen(
                                animeTitle: widget.anime.title,
                                animeSlug: widget.anime.id,
                                episodeNumber: ep.episodeNumber,
                                anime: widget.anime,
                              ),
                            ));
                          },
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
