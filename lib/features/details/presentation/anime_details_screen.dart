import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'package:luffytv/core/widgets/cached_artwork_image.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:http/http.dart' as http;
import 'package:luffytv/features/home/data/models/episode.dart';
import 'package:luffytv/features/home/data/models/watch_data.dart';
import 'package:luffytv/core/utils/api_constants.dart';
import 'package:luffytv/core/services/hls_downloader_service.dart';
import 'package:luffytv/core/services/download_source_recovery.dart';
import 'package:luffytv/core/utils/playback_diagnostics.dart';

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

  void _showDownloadQualityDialog(
    BuildContext context,
    Anime anime,
    Episode ep,
    WidgetRef ref,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.accentStart),
      ),
    );

    try {
      final repo = ref.read(animeRepositoryProvider);
      WatchData? watchData;
      Object? lastError;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final candidate = await repo.fetchWatchData(
            anime.id,
            ep.episodeNumber,
            forceRefresh: attempt > 0,
          );
          if (candidate.sources.any((source) => source.isPlayable)) {
            watchData = candidate;
            break;
          }
          lastError = Exception('No downloadable source was returned.');
        } catch (error) {
          lastError = error;
        }
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: attempt == 0 ? 350 : 900),
          );
        }
      }
      if (watchData == null) throw lastError ?? Exception('No source found.');

      final sources =
          watchData.sources.where((source) => source.isPlayable).toList()
            ..sort((a, b) {
              int score(VideoSource source) =>
                  (source.type.toLowerCase() == 'sub' ? 4 : 0) +
                  (source.proxyUrl?.trim().isNotEmpty == true ? 2 : 0) +
                  (source.m3u8?.trim().isNotEmpty == true ? 1 : 0);
              return score(b).compareTo(score(a));
            });

      if (context.mounted) Navigator.pop(context); // pop loading
      if (!context.mounted) return;

      final selectedSource = await showModalBottomSheet<VideoSource>(
        context: context,
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Choose audio version',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  'Available dub languages depend on what the streaming provider exposes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: sources
                      .map(
                        (source) => ListTile(
                          leading: Icon(
                            source.type.toLowerCase() == 'dub'
                                ? Icons.record_voice_over_rounded
                                : Icons.subtitles_rounded,
                            color: AppColors.accentStart,
                          ),
                          title: Text(
                            _audioLabel(source),
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            source.server,
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.white54,
                          ),
                          onTap: () => Navigator.pop(ctx, source),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      );
      if (selectedSource == null || !context.mounted) return;

      await _configureDownload(
        context,
        anime,
        ep,
        watchData,
        selectedSource,
        ref,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Download quality resolution failed: $e');
      if (context.mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not prepare this download. Please retry or choose another episode.\n${e.toString().replaceFirst('Exception: ', '')}',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _configureDownload(
    BuildContext context,
    Anime anime,
    Episode episode,
    WatchData watchData,
    VideoSource source,
    WidgetRef ref,
  ) async {
    final diagnosticId = PlaybackDiagnostics.newRequestId('download');
    final repo = ref.read(animeRepositoryProvider);
    late PreparedDownloadSource prepared;
    try {
      prepared = await prepareDownloadSource(
        selected: source,
        initial: watchData,
        refresh: () => repo.fetchWatchData(
          anime.id,
          episode.episodeNumber,
          forceRefresh: true,
          diagnosticId: diagnosticId,
        ),
        loadPlaylist: (candidate) async {
          final url = _absoluteDownloadUrl(candidate.playableUrl!);
          if (candidate.m3u8?.isNotEmpty != true &&
              !url.toLowerCase().contains('.m3u8')) {
            return null;
          }
          final response = await http
              .get(
                Uri.parse(url),
                headers: {
                  if (candidate.proxyUrl?.isNotEmpty != true &&
                      candidate.referer?.isNotEmpty == true)
                    'Referer': candidate.referer!,
                },
              )
              .timeout(const Duration(seconds: 12));
          PlaybackDiagnostics.log(diagnosticId, 'download.playlist_checked', {
            'slug': anime.id,
            'episode': episode.episodeNumber,
            'host': PlaybackDiagnostics.host(url),
            'status': response.statusCode,
          });
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw Exception(
              'The video provider returned HTTP ${response.statusCode}.',
            );
          }
          return response.body;
        },
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(PlaybackDiagnostics.safeError(error))),
        );
      }
      return;
    }
    source = prepared.source;
    watchData = prepared.watchData;
    final masterUrl = _absoluteDownloadUrl(source.playableUrl!);
    final qualities = <Map<String, String>>[
      {'resolution': 'Auto / source quality', 'url': masterUrl},
      if (prepared.playlist != null)
        ..._parseDownloadQualities(
          prepared.playlist!,
          masterUrl,
          episode.durationMinutes,
        ),
    ];

    final subtitleChoices = _availableSubtitleChoices(watchData);
    if (!context.mounted) return;
    final configuration = await showModalBottomSheet<_DownloadConfiguration>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _DownloadConfigurationSheet(
        audioLabel: _audioLabel(source),
        qualities: qualities,
        subtitles: subtitleChoices,
      ),
    );
    if (configuration == null) return;

    ref
        .read(downloadItemsProvider.notifier)
        .startDownload(
          anime,
          episode,
          configuration.videoUrl,
          referer: source.referer,
          sourceType: source.type,
          audioLabel: _audioLabel(source),
          subtitles: configuration.subtitles
              .map(
                (choice) => SubtitleDownloadRequest(
                  url: choice.url,
                  label: choice.track.label,
                  language: choice.track.label,
                  referer: choice.referer,
                ),
              )
              .toList(),
          skipData: watchData.skipData,
        );
  }

  String _audioLabel(VideoSource source) {
    final rawType = source.type.trim();
    final type = rawType.toUpperCase();
    var language = source.language?.trim();
    if (type.startsWith('DUB')) {
      if (language?.isNotEmpty != true) {
        final suffix = rawType.replaceFirst(
          RegExp(r'^dub[\s_:-]*', caseSensitive: false),
          '',
        );
        if (suffix.isNotEmpty) language = suffix;
      }
      return language?.isNotEmpty == true ? 'DUB • $language' : 'DUB audio';
    }
    return type.startsWith('SUB') ? 'SUB • Original audio' : '$type audio';
  }

  List<_SubtitleChoice> _availableSubtitleChoices(WatchData watchData) {
    final choices = <_SubtitleChoice>[];
    final seen = <String>{};
    for (final source in watchData.sources) {
      for (final track in source.tracks) {
        final kind = track.kind.toLowerCase();
        if (kind != 'captions' && kind != 'subtitles') continue;
        final rawUrl = track.proxyUrl ?? track.file;
        if (rawUrl.trim().isEmpty) continue;
        final url = _absoluteDownloadUrl(rawUrl);
        // Providers often expose the same language through several servers.
        // Keep one offline copy per visible language label.
        if (!seen.add(track.label.trim().toLowerCase())) continue;
        choices.add(
          _SubtitleChoice(track: track, url: url, referer: source.referer),
        );
      }
    }
    return choices;
  }

  String _absoluteDownloadUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('/')) return '${ApiConstants.baseUrl}$trimmed';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      throw Exception('The server returned an invalid download URL.');
    }
    return trimmed;
  }

  List<Map<String, String>> _parseDownloadQualities(
    String playlist,
    String baseUrl,
    int durationMinutes,
  ) {
    final lines = playlist.split(RegExp(r'\r?\n'));
    final qualities = <Map<String, String>>[];
    final seen = <String>{};
    for (var index = 0; index < lines.length; index++) {
      final metadata = lines[index].trim();
      if (!metadata.startsWith('#EXT-X-STREAM-INF')) continue;
      var urlIndex = index + 1;
      while (urlIndex < lines.length &&
          (lines[urlIndex].trim().isEmpty ||
              lines[urlIndex].trim().startsWith('#'))) {
        urlIndex++;
      }
      if (urlIndex >= lines.length) continue;
      var variantUrl = lines[urlIndex].trim();
      if (!variantUrl.startsWith('http')) {
        variantUrl = Uri.parse(baseUrl).resolve(variantUrl).toString();
      }
      if (!seen.add(variantUrl)) continue;

      final resolution = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(metadata);
      final bandwidth = RegExp(
        r'(?:AVERAGE-)?BANDWIDTH=(\d+)',
      ).firstMatch(metadata);
      var label = resolution == null
          ? 'Auto quality'
          : '${resolution.group(2)}p';
      if (bandwidth != null) {
        final bitsPerSecond = int.tryParse(bandwidth.group(1)!) ?? 0;
        final seconds = (durationMinutes > 0 ? durationMinutes : 24) * 60;
        final sizeMb = bitsPerSecond / 8 * seconds / 1024 / 1024;
        if (sizeMb > 0) label += ' (~${sizeMb.toStringAsFixed(0)} MB)';
      }
      qualities.add({'resolution': label, 'url': variantUrl});
    }
    return qualities;
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
            expandedHeight: 420.0,
            pinned: true,
            stretch: true,
            centerTitle: false,
            backgroundColor: AppColors.bg,
            actions: [
              IconButton(
                tooltip: _isInMyList ? 'Remove from My List' : 'Add to My List',
                onPressed: _toggleMyList,
                icon: Icon(
                  _isInMyList
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                ),
              ),
              const SizedBox(width: 6),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.fadeTitle,
              ],
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 70, 18),
              title: Text(
                widget.anime.title,
                style: AppTextStyles.heroTitle.copyWith(
                  fontSize: 21,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 20)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.anime.posterUrl != null)
                    CachedArtworkImage(
                      imageUrl: widget.anime.posterUrl!,
                      previewUrl: widget.anime.posterPreviewUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      fallbackBuilder: (_) =>
                          Container(color: AppColors.cardGradients[0][0]),
                    )
                  else
                    Container(color: AppColors.cardGradients[0][0]),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black12,
                          Colors.transparent,
                          AppColors.bg,
                        ],
                        stops: const [0, .42, 1],
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
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentStart,
                  ),
                ),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'Error loading details: $err',
                    style: AppTextStyles.body,
                  ),
                ),
              ),
              data: (detail) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 9,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: .24),
                              ),
                            ),
                            child: Text(
                              '${widget.anime.matchPercentage}% match',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (detail.year.isNotEmpty) ...[
                            _DetailChip(detail.year),
                          ],
                          if (detail.rating.isNotEmpty) ...[
                            _DetailChip(detail.rating),
                          ],
                          if (detail.episodeCount > 0) ...[
                            _DetailChip('${detail.episodeCount} episodes'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => VideoPlayerScreen(
                                      animeTitle: widget.anime.title,
                                      animeSlug: widget.anime.id,
                                      episodeNumber:
                                          1, // Default to episode 1 for main play button
                                      anime: widget.anime,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Watch episode 1',
                                style: AppTextStyles.button,
                              ),
                              style:
                                  ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                    ),
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                  ).copyWith(
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith(
                                          (states) => AppColors.accentStart,
                                        ),
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
                              label: Text(
                                _isInMyList ? 'Saved' : 'My List',
                                style: AppTextStyles.button,
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
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
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                            maxLines: _isDescriptionExpanded ? null : 3,
                            overflow: _isDescriptionExpanded
                                ? null
                                : TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => setState(
                              () => _isDescriptionExpanded =
                                  !_isDescriptionExpanded,
                            ),
                            child: Text(
                              _isDescriptionExpanded
                                  ? 'Read less'
                                  : 'Read more',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.accentStart,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (detail.genres.isNotEmpty) ...[
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: detail.genres
                              .map((genre) => _DetailChip(genre))
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (detail.studios.isNotEmpty) ...[
                        Text(
                          'Studios: ${detail.studios.join(', ')}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                      const SizedBox(height: 32),
                      if (detail.seasons.isNotEmpty) ...[
                        Text(
                          'Related Seasons',
                          style: AppTextStyles.sectionTitle,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200, // accommodate poster + title
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: detail.seasons.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final season = detail.seasons[index];
                              // Convert RelatedSeason to Anime so we can reuse PosterCard
                              final relatedAnime = Anime(
                                id: season.slug ?? season.id,
                                title: season.title,
                                genre:
                                    season.relation ??
                                    'Related', // use genre field for relation badge
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
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentStart,
                  ),
                ),
              ),
            ),
            error: (err, stack) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'Error loading episodes',
                    style: AppTextStyles.body,
                  ),
                ),
              ),
            ),
            data: (episodes) {
              if (episodes.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'No episodes found.',
                        style: AppTextStyles.body,
                      ),
                    ),
                  ),
                );
              }

              final int chunkSize = 100;
              final int totalChunks = (episodes.length / chunkSize).ceil();

              // Determine current chunk episodes
              final startIndex = _selectedChunkIndex * chunkSize;
              final endIndex = (startIndex + chunkSize > episodes.length)
                  ? episodes.length
                  : startIndex + chunkSize;
              final chunkEpisodes = episodes.sublist(startIndex, endIndex);

              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Episodes', style: AppTextStyles.sectionTitle),
                          if (totalChunks > 1)
                            DropdownButton<int>(
                              value: _selectedChunkIndex,
                              dropdownColor: AppColors.bg,
                              underline: const SizedBox(),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: AppColors.textPrimary,
                              ),
                              items: List.generate(totalChunks, (index) {
                                final start = index * chunkSize + 1;
                                final end =
                                    (index * chunkSize + chunkSize >
                                        episodes.length)
                                    ? episodes.length
                                    : index * chunkSize + chunkSize;
                                return DropdownMenuItem(
                                  value: index,
                                  child: Text(
                                    '$start - $end',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
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
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final ep = chunkEpisodes[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        child: Material(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: SizedBox(
                                width: 120,
                                height: 70,
                                child: Stack(
                                  fit: StackFit.expand,
                                  alignment: Alignment.center,
                                  children: [
                                    ColoredBox(color: AppColors.border),
                                    if (widget.anime.posterUrl != null)
                                      CachedArtworkImage(
                                        imageUrl: widget.anime.posterUrl!,
                                        previewUrl:
                                            widget.anime.posterPreviewUrl,
                                        fit: BoxFit.cover,
                                      ),
                                    ColoredBox(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.play_circle_outline,
                                      color: AppColors.textPrimary,
                                      size: 32,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            title: Text(
                              ep.title,
                              style: AppTextStyles.cardTitle.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Episode ${ep.episodeNumber}',
                                  style: AppTextStyles.caption,
                                ),
                                ValueListenableBuilder(
                                  valueListenable: Hive.box(
                                    'watch_progress',
                                  ).listenable(keys: [widget.anime.id]),
                                  builder: (context, _, _) {
                                    final prog = LocalDbService.getProgress(
                                      widget.anime.id,
                                    );
                                    double percentage = 0.0;
                                    if (prog != null) {
                                      final epProgress =
                                          prog.episodes[ep.episodeNumber
                                              .toString()];
                                      if (epProgress != null &&
                                          epProgress.durationSeconds > 0) {
                                        percentage =
                                            (epProgress.positionSeconds /
                                                    epProgress.durationSeconds)
                                                .clamp(0.0, 1.0);
                                      }
                                    }
                                    if (percentage > 0) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                          right: 16.0,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: percentage,
                                          backgroundColor: AppColors.border,
                                          color: AppColors.accentStart,
                                          minHeight: 4,
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                            trailing: Consumer(
                              builder: (context, ref, child) {
                                final downloads = ref.watch(
                                  downloadItemsProvider,
                                );
                                final downloadId =
                                    '${widget.anime.id}_${ep.episodeNumber}';
                                final currentDownload = downloads
                                    .where((d) => d.id == downloadId)
                                    .firstOrNull;

                                if (currentDownload != null) {
                                  if (currentDownload.state ==
                                      DownloadState.downloading) {
                                    return GestureDetector(
                                      onTap: () {
                                        ref
                                            .read(
                                              downloadItemsProvider.notifier,
                                            )
                                            .cancelDownload(downloadId);
                                      },
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              value: currentDownload.progress,
                                              strokeWidth: 2.5,
                                              backgroundColor: AppColors.border,
                                              color: AppColors.accentStart,
                                            ),
                                            const Icon(
                                              Icons.stop,
                                              size: 16,
                                              color: AppColors.textPrimary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else if (currentDownload.state ==
                                      DownloadState.completed) {
                                    return const Icon(
                                      Icons.check_circle,
                                      color: AppColors.accentStart,
                                    );
                                  }
                                }

                                return IconButton(
                                  icon: const Icon(
                                    Icons.download,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () {
                                    _showDownloadQualityDialog(
                                      context,
                                      widget.anime,
                                      ep,
                                      ref,
                                    );
                                  },
                                );
                              },
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => VideoPlayerScreen(
                                    animeTitle: widget.anime.title,
                                    animeSlug: widget.anime.id,
                                    episodeNumber: ep.episodeNumber,
                                    anime: widget.anime,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }, childCount: chunkEpisodes.length),
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

class _SubtitleChoice {
  final VideoTrack track;
  final String url;
  final String? referer;

  const _SubtitleChoice({
    required this.track,
    required this.url,
    required this.referer,
  });
}

class _DownloadConfiguration {
  final String videoUrl;
  final List<_SubtitleChoice> subtitles;

  const _DownloadConfiguration({
    required this.videoUrl,
    required this.subtitles,
  });
}

class _DownloadConfigurationSheet extends StatefulWidget {
  final String audioLabel;
  final List<Map<String, String>> qualities;
  final List<_SubtitleChoice> subtitles;

  const _DownloadConfigurationSheet({
    required this.audioLabel,
    required this.qualities,
    required this.subtitles,
  });

  @override
  State<_DownloadConfigurationSheet> createState() =>
      _DownloadConfigurationSheetState();
}

class _DownloadConfigurationSheetState
    extends State<_DownloadConfigurationSheet> {
  late String selectedUrl;
  late Set<int> selectedSubtitles;

  @override
  void initState() {
    super.initState();
    selectedUrl = widget.qualities.first['url']!;
    selectedSubtitles = {
      for (var index = 0; index < widget.subtitles.length; index++) index,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.86,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                children: [
                  const Text(
                    'Download episode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.audioLabel,
                    style: const TextStyle(color: AppColors.accentStart),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 4),
                    child: Text(
                      'VIDEO QUALITY',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RadioGroup<String>(
                    groupValue: selectedUrl,
                    onChanged: (value) {
                      if (value != null) setState(() => selectedUrl = value);
                    },
                    child: Column(
                      children: widget.qualities
                          .map(
                            (quality) => RadioListTile<String>(
                              value: quality['url']!,
                              activeColor: AppColors.accentStart,
                              title: Text(
                                quality['resolution']!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'OFFLINE SUBTITLES',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.subtitles.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() {
                              if (selectedSubtitles.length ==
                                  widget.subtitles.length) {
                                selectedSubtitles.clear();
                              } else {
                                selectedSubtitles = {
                                  for (
                                    var index = 0;
                                    index < widget.subtitles.length;
                                    index++
                                  )
                                    index,
                                };
                              }
                            }),
                            child: Text(
                              selectedSubtitles.length ==
                                      widget.subtitles.length
                                  ? 'Select none'
                                  : 'Select all',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.subtitles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Text(
                        'This provider did not return downloadable subtitles for this episode.',
                        style: TextStyle(color: Colors.white54, height: 1.4),
                      ),
                    )
                  else
                    ...widget.subtitles.indexed.map(
                      (entry) => CheckboxListTile(
                        value: selectedSubtitles.contains(entry.$1),
                        activeColor: AppColors.accentStart,
                        title: Text(
                          entry.$2.track.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Saved with the episode for offline switching',
                          style: TextStyle(color: Colors.white38),
                        ),
                        onChanged: (checked) => setState(() {
                          if (checked == true) {
                            selectedSubtitles.add(entry.$1);
                          } else {
                            selectedSubtitles.remove(entry.$1);
                          }
                        }),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    _DownloadConfiguration(
                      videoUrl: selectedUrl,
                      subtitles: selectedSubtitles
                          .map((index) => widget.subtitles[index])
                          .toList(),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    selectedSubtitles.isEmpty
                        ? 'Download without subtitles'
                        : 'Download with ${selectedSubtitles.length} subtitle${selectedSubtitles.length == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  const _DetailChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          fontSize: 10.5,
        ),
      ),
    );
  }
}
