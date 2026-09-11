import 'dart:async';
import 'package:luffytv/core/services/app_telemetry.dart';
import 'package:flutter/material.dart';
import 'package:luffytv/core/utils/api_constants.dart';
import 'package:luffytv/core/utils/playback_diagnostics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide VideoTrack;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/features/home/data/models/watch_data.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:luffytv/features/downloads/providers/download_providers.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../home/data/models/anime.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String animeTitle;
  final String animeSlug;
  final int episodeNumber;
  final Anime? anime;
  final bool isLocal;

  const VideoPlayerScreen({
    super.key,
    required this.animeTitle,
    required this.animeSlug,
    required this.episodeNumber,
    this.anime,
    this.isLocal = false,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with WidgetsBindingObserver {
  late int _episodeNumber;
  int? _nextEpisode;
  bool _episodeCompleted = false;
  bool _nextPrefetched = false;
  Timer? _stallTimer;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  Stopwatch? _bufferingTimer;
  Duration _lastPosition = Duration.zero;
  DateTime _lastAdvanced = DateTime.now();
  int _stallRecoveries = 0;
  int _audioDecodeErrors = 0;
  DateTime? _firstAudioDecodeError;
  late final Player player;
  late final VideoController controller;
  bool _isLoading = true;
  String? _error;

  WatchData? _watchData;
  VideoSource? _currentSource;
  VideoTrack? _currentSubtitleTrack;
  DownloadItem? _localDownload;
  DownloadedSubtitle? _currentLocalSubtitle;
  SkipData? _skipData;
  Duration? _savedPosition;
  bool _isFastForwarding = false;
  double _brightness = 0.5;
  String? _seekAnimationSide;
  Timer? _seekAnimationTimer;
  Timer? _progressSaveTimer;
  StreamSubscription<String>? _playerErrorSubscription;
  StreamSubscription<bool>? _playerCompletedSubscription;
  final Set<String> _attemptedSources = {};
  bool _automaticRefreshUsed = false;
  bool _playingLocalFile = false;
  bool _subtitlesEnabled = true;
  late String _playbackRequestId;

  @override
  void initState() {
    super.initState();
    _episodeNumber = widget.episodeNumber;
    WidgetsBinding.instance.addObserver(this);
    _playbackRequestId = PlaybackDiagnostics.newRequestId('player');
    PlaybackDiagnostics.log(_playbackRequestId, 'player.screen_opened', {
      'slug': widget.animeSlug,
      'episode': _episodeNumber,
      'local': widget.isLocal,
    });
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    player = Player(
      configuration: const PlayerConfiguration(bufferSize: 64 * 1024 * 1024),
    );
    controller = VideoController(player);
    final firstFrameTimer = Stopwatch()..start();
    unawaited(
      controller.waitUntilFirstFrameRendered.then((_) {
        if (!mounted) return;
        PlaybackDiagnostics.log(_playbackRequestId, 'player.first_frame', {
          'elapsedMs': firstFrameTimer.elapsedMilliseconds,
        });
      }, onError: (Object _) {}),
    );
    _playerErrorSubscription = player.stream.error.listen(_handlePlaybackError);
    _bufferingSubscription = player.stream.buffering.listen((buffering) {
      if (buffering && !_isLoading) {
        _bufferingTimer ??= Stopwatch()..start();
      } else if (!buffering && _bufferingTimer != null) {
        AppTelemetry.duration(
          'player_rebuffer',
          _bufferingTimer!.elapsedMilliseconds,
          server: _currentSource?.server,
        );
        _bufferingTimer = null;
      }
    });
    _playerCompletedSubscription = player.stream.completed.listen((completed) {
      if (completed) {
        _saveProgress(completed: true);
        if (mounted) setState(() => _episodeCompleted = true);
      }
    });

    _initPlayer();
    _findNextEpisode();
    _positionSubscription = player.stream.position.listen((position) {
      if (position != _lastPosition) {
        _lastPosition = position;
        _lastAdvanced = DateTime.now();
      }
      final remaining = player.state.duration - position;
      if (!_nextPrefetched &&
          _nextEpisode != null &&
          !_playingLocalFile &&
          player.state.duration > Duration.zero &&
          remaining.inSeconds <= 45 &&
          !player.state.buffering) {
        _nextPrefetched = true;
        unawaited(
          ref
              .read(animeRepositoryProvider)
              .fetchWatchData(widget.animeSlug, _nextEpisode!)
              .then<void>((_) {}, onError: (Object _) {}),
        );
      }
    });
    _stallTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted ||
          _isLoading ||
          _playingLocalFile ||
          _episodeCompleted ||
          !player.state.playing ||
          !player.state.buffering) {
        _lastAdvanced = DateTime.now();
        return;
      }
      if (DateTime.now().difference(_lastAdvanced).inSeconds >= 45 &&
          _stallRecoveries < 2) {
        unawaited(_recoverStall());
      }
    });
    _initBrightness();

    // Save progress periodically
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _saveProgress();
    });
  }

  Future<void> _findNextEpisode() async {
    final current = _episodeNumber;
    try {
      final numbers = widget.isLocal
          ? (await DownloadNotifier.loadStoredDownloads())
                .where(
                  (d) =>
                      d.animeSlug == widget.animeSlug &&
                      d.state == DownloadState.completed,
                )
                .map((d) => d.episode.episodeNumber)
                .toList()
          : (await ref
                    .read(animeRepositoryProvider)
                    .fetchAnimeEpisodes(widget.animeSlug))
                .map((e) => e.episodeNumber)
                .toList();
      numbers.sort();
      if (mounted && current == _episodeNumber) {
        setState(
          () => _nextEpisode = numbers.where((n) => n > current).firstOrNull,
        );
      }
    } catch (_) {
      /* Playback remains usable if episode metadata is unavailable. */
    }
  }

  Future<void> _playNextEpisode() async {
    final next = _nextEpisode;
    if (next == null || _isLoading) return;
    setState(() => _isLoading = true);
    await _saveProgress(completed: _episodeCompleted);
    await player.stop();
    if (!mounted) return;
    setState(() {
      _episodeNumber = next;
      _nextEpisode = null;
      _episodeCompleted = false;
      _nextPrefetched = false;
      _savedPosition = null;
      _watchData = null;
      _currentSource = null;
      _localDownload = null;
      _error = null;
      _attemptedSources.clear();
      _automaticRefreshUsed = false;
      _stallRecoveries = 0;
    });
    unawaited(_findNextEpisode());
    await _initPlayer();
  }

  Future<void> _recoverStall({bool replaceBrokenAudio = false}) async {
    final source = _currentSource;
    if (_isLoading || source == null) return;
    _stallRecoveries++;
    setState(() {
      _isLoading = true;
      _savedPosition = player.state.position;
    });
    try {
      final native = player.platform;
      if (native is NativePlayer) {
        await native.setProperty('hls-bitrate', 'min');
      }
      final fresh = await _fetchPlayableWatchData(forceRefresh: true);
      if (!mounted) return;
      _watchData = fresh;
      _attemptedSources.clear();
      await _playFirstAvailable(
        _playableSources(fresh).where(
          (candidate) =>
              (!replaceBrokenAudio ||
                  candidate.playbackKey != source.playbackKey) &&
              candidate.type.toLowerCase() == source.type.toLowerCase() &&
              (candidate.language ?? '').toLowerCase() ==
                  (source.language ?? '').toLowerCase(),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'This stream stalled. Retry or choose another server.',
        );
      }
    } finally {
      _lastAdvanced = DateTime.now();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProgress({bool completed = false}) async {
    try {
      await LocalDbService.saveProgress(
        animeSlug: widget.animeSlug,
        anime: widget.anime,
        animeTitle: _localDownload?.animeTitle ?? widget.animeTitle,
        posterUrl: _localDownload?.posterUrl,
        episodeNumber: _episodeNumber,
        position: player.state.position,
        duration: player.state.duration,
        completed: completed || player.state.completed,
      );
    } catch (error) {
      PlaybackDiagnostics.log(
        _playbackRequestId,
        'player.progress_save_failed',
        {'error': PlaybackDiagnostics.safeError(error)},
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _saveProgress();
  }

  Future<void> _initBrightness() async {
    try {
      final current = await ScreenBrightness().application;
      if (mounted) {
        setState(() {
          _brightness = current;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPlaybackPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _subtitlesEnabled = prefs.getBool('playback_subtitles') ?? true;
    final native = player.platform;
    if (native is NativePlayer) {
      // A bounded read-ahead absorbs short CDN stalls without waiting for it to fill.
      await native.setProperty('cache', 'yes');
      await native.setProperty('cache-secs', '60');
      await native.setProperty('cache-pause-initial', 'no');
      await native.setProperty('cache-pause-wait', '1');
      await native.setProperty('demuxer-max-back-bytes', '${8 * 1024 * 1024}');
      await native.setProperty(
        'hls-bitrate',
        (prefs.getBool('playback_high_quality') ?? false) ? 'max' : '2500000',
      );
    }
  }

  void _triggerSeekAnimation(String side) {
    setState(() {
      _seekAnimationSide = side;
    });
    _seekAnimationTimer?.cancel();
    _seekAnimationTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _seekAnimationSide = null;
        });
      }
    });
  }

  List<VideoSource> _playableSources(WatchData watchData) {
    final sources = watchData.sources
        .where((source) => source.isPlayable)
        .toList();
    sources.sort((a, b) {
      final aScore =
          (a.type.toLowerCase() == 'sub' ? 2 : 0) +
          (a.proxyUrl?.trim().isNotEmpty == true ? 1 : 0);
      final bScore =
          (b.type.toLowerCase() == 'sub' ? 2 : 0) +
          (b.proxyUrl?.trim().isNotEmpty == true ? 1 : 0);
      return bScore.compareTo(aScore);
    });
    return sources;
  }

  List<VideoTrack> _captionTracks(VideoSource source) =>
      source.tracks.where((track) {
        final kind = track.kind.toLowerCase();
        return kind == 'captions' || kind == 'subtitles';
      }).toList();

  void _setDownloadedSubtitle(DownloadedSubtitle? subtitle) {
    if (subtitle == null) {
      player.setSubtitleTrack(SubtitleTrack.no());
    } else {
      player.setSubtitleTrack(
        SubtitleTrack.uri(
          Uri.file(subtitle.localPath).toString(),
          title: subtitle.label,
          language: subtitle.language.isEmpty
              ? subtitle.label
              : subtitle.language,
        ),
      );
    }
    if (mounted) {
      setState(() {
        _currentLocalSubtitle = subtitle;
        _currentSubtitleTrack = null;
      });
    }
  }

  ({String label, SkipRange range})? _activeSkipAction(Duration position) {
    final intro = _skipData?.intro;
    if (intro?.contains(position) == true) {
      return (label: 'Skip intro', range: intro!);
    }
    final outro = _skipData?.outro;
    if (outro?.contains(position) == true) {
      return (label: 'Skip outro', range: outro!);
    }
    return null;
  }

  String _absoluteApiUrl(String url) {
    final value = url.trim();
    if (value.startsWith('/')) return '${ApiConstants.baseUrl}$value';
    return value;
  }

  Future<WatchData> _fetchPlayableWatchData({bool forceRefresh = false}) async {
    final repo = ref.read(animeRepositoryProvider);
    Object? lastError;
    final attempts = forceRefresh ? 1 : 2;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        if (forceRefresh || attempt > 0) _automaticRefreshUsed = true;
        PlaybackDiagnostics.log(_playbackRequestId, 'player.resolve_attempt', {
          'attempt': attempt + 1,
          'forceRefresh': forceRefresh || attempt > 0,
        });
        final watchData = await repo.fetchWatchData(
          widget.animeSlug,
          _episodeNumber,
          forceRefresh: forceRefresh || attempt > 0,
          diagnosticId: _playbackRequestId,
        );
        final playable = _playableSources(watchData);
        if (playable.isNotEmpty) {
          PlaybackDiagnostics.log(
            _playbackRequestId,
            'player.resolve_succeeded',
            {
              'attempt': attempt + 1,
              'sourceCount': watchData.sources.length,
              'playableCount': playable.length,
            },
          );
          return watchData;
        }
        lastError = Exception('The API returned an empty source list.');
      } catch (error, stack) {
        AppTelemetry.report(
          'player.resolve_failed',
          error,
          stack: stack,
          context: {
            'requestId': _playbackRequestId,
            'attempt': attempt + 1,
            'stage': 'source_resolution',
          },
        );
        lastError = error;
        PlaybackDiagnostics.log(_playbackRequestId, 'player.resolve_failed', {
          'attempt': attempt + 1,
          'error': PlaybackDiagnostics.safeError(error),
        });
      }
      if (attempt + 1 < attempts) {
        await Future<void>.delayed(
          Duration(milliseconds: attempt == 0 ? 350 : 900),
        );
      }
    }
    PlaybackDiagnostics.log(_playbackRequestId, 'player.resolve_exhausted', {
      'error': PlaybackDiagnostics.safeError(lastError),
    });
    throw Exception(
      'No playable video source is available right now. Please retry.',
    );
  }

  Future<VideoSource> _playFirstAvailable(
    Iterable<VideoSource> sources, {
    VideoSource? exclude,
  }) async {
    Object? lastError;
    for (final source in sources) {
      if (identical(source, exclude)) continue;
      if (!_attemptedSources.add(source.playbackKey)) continue;
      try {
        PlaybackDiagnostics.log(_playbackRequestId, 'player.source_attempt', {
          'server': source.server,
          'type': source.type,
          'host': PlaybackDiagnostics.host(source.playableUrl),
          'proxied': source.proxyUrl?.trim().isNotEmpty == true,
        });
        await _playSource(source);
        PlaybackDiagnostics.log(_playbackRequestId, 'player.source_opened', {
          'server': source.server,
          'type': source.type,
          'host': PlaybackDiagnostics.host(source.playableUrl),
        });
        return source;
      } catch (error, stack) {
        AppTelemetry.report(
          'player.source_failed',
          error,
          stack: stack,
          context: {
            'requestId': _playbackRequestId,
            'server': source.server,
            'host': PlaybackDiagnostics.host(source.playableUrl),
          },
        );
        lastError = error;
        PlaybackDiagnostics.log(_playbackRequestId, 'player.source_failed', {
          'server': source.server,
          'type': source.type,
          'host': PlaybackDiagnostics.host(source.playableUrl),
          'error': PlaybackDiagnostics.safeError(error),
        });
      }
    }
    throw Exception(lastError ?? 'All resolved video sources failed.');
  }

  Future<void> _handlePlaybackError(String message) async {
    PlaybackDiagnostics.log(_playbackRequestId, 'player.runtime_error', {
      'server': _currentSource?.server ?? '',
      'host': PlaybackDiagnostics.host(_currentSource?.playableUrl),
      'positionSeconds': player.state.position.inSeconds,
      'error': PlaybackDiagnostics.safeError(message),
    });
    // A single damaged packet can recover naturally. Repeated audio decoding
    // failures need a different source even if the video clock keeps moving.
    if (!message.toLowerCase().contains('error decoding audio') ||
        !mounted ||
        _isLoading) {
      return;
    }
    final now = DateTime.now();
    if (_firstAudioDecodeError == null ||
        now.difference(_firstAudioDecodeError!) > const Duration(seconds: 10)) {
      _firstAudioDecodeError = now;
      _audioDecodeErrors = 0;
    }
    if (++_audioDecodeErrors < 3) return;
    _audioDecodeErrors = 0;
    if (!_playingLocalFile && _stallRecoveries < 2) {
      await _recoverStall(replaceBrokenAudio: true);
    } else {
      setState(
        () => _error =
            'The audio could not be decoded. Choose another server or download this episode again.',
      );
    }
  }

  Future<void> _retryPlayer() async {
    if (_isLoading) return;
    _attemptedSources.clear();
    _automaticRefreshUsed = false;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await player.stop();
    _playbackRequestId = PlaybackDiagnostics.newRequestId('retry');
    PlaybackDiagnostics.log(_playbackRequestId, 'player.manual_retry', {
      'slug': widget.animeSlug,
      'episode': _episodeNumber,
    });
    await _initPlayer(forceRefresh: true);
  }

  Future<void> _initPlayer({bool forceRefresh = false}) async {
    try {
      // Preferences/native configuration and disk metadata are independent.
      final initialization = await Future.wait<Object?>([
        _loadPlaybackPreferences(),
        DownloadNotifier.loadStoredDownloads(),
      ]);
      final downloadId = '${widget.animeSlug}_$_episodeNumber';
      final downloads = ref.read(downloadItemsProvider);
      var localItem = downloads
          .where(
            (d) => d.id == downloadId && d.state == DownloadState.completed,
          )
          .firstOrNull;
      localItem ??= (initialization[1] as List<DownloadItem>)
          .where(
            (item) =>
                item.id == downloadId && item.state == DownloadState.completed,
          )
          .firstOrNull;

      // If the file is downloaded (or forced local), play the local file
      if (widget.isLocal || localItem != null) {
        _playingLocalFile = true;
        if (localItem == null || localItem.localM3u8Path == null) {
          throw Exception('Local file not found.');
        }
        _localDownload = localItem;
        _skipData = localItem.skipData;

        // Restore progress
        final savedProgress = LocalDbService.getProgress(widget.animeSlug);
        if (savedProgress != null) {
          final epProgress = savedProgress.episodes[_episodeNumber.toString()];
          if (epProgress != null && !epProgress.isCompleted) {
            _savedPosition = Duration(seconds: epProgress.positionSeconds);
          }
        }

        await player.open(Media(localItem.localM3u8Path!));
        if (_savedPosition != null) {
          await player.seek(_savedPosition!);
        }
        player.play();

        if (_subtitlesEnabled && localItem.subtitles.isNotEmpty) {
          _setDownloadedSubtitle(localItem.subtitles.first);
        } else {
          _setDownloadedSubtitle(null);
        }

        // Saved media and subtitles are self-contained. Network metadata must
        // never delay the video surface while local audio is already playing.
        _watchData = null;
        _currentSource = null;

        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Otherwise fetch from API and stream
      _playingLocalFile = false;
      final watchData = await _fetchPlayableWatchData(
        forceRefresh: forceRefresh,
      );
      _watchData = watchData;
      _skipData = watchData.skipData;

      // Check if we have saved progress to resume from
      final savedProgress = LocalDbService.getProgress(widget.animeSlug);
      if (savedProgress != null) {
        final epProgress = savedProgress.episodes[_episodeNumber.toString()];
        if (epProgress != null && !epProgress.isCompleted) {
          _savedPosition = Duration(seconds: epProgress.positionSeconds);
        }
      }

      await _playWithRecovery(watchData);

      if (mounted) setState(() => _isLoading = false);
    } catch (e, stack) {
      AppTelemetry.report(
        'player.initialization_failed',
        e,
        stack: stack,
        context: {'requestId': _playbackRequestId},
      );
      PlaybackDiagnostics.log(
        _playbackRequestId,
        'player.initialization_failed',
        {'error': PlaybackDiagnostics.safeError(e)},
      );
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _playWithRecovery(WatchData data, {VideoSource? exclude}) async {
    try {
      await _playFirstAvailable(_playableSources(data), exclude: exclude);
    } catch (_) {
      if (_automaticRefreshUsed) rethrow;
      _automaticRefreshUsed = true;
      final refreshed = await _fetchPlayableWatchData(forceRefresh: true);
      _watchData = refreshed;
      _skipData = refreshed.skipData;
      // A renewed signature may repair the same media URL. Allow one fresh
      // round, while continuing to deduplicate aliases within that round.
      _attemptedSources.clear();
      await _playFirstAvailable(_playableSources(refreshed));
    }
  }

  Future<void> _playSource(VideoSource source) async {
    _currentSource = source;
    _currentLocalSubtitle = null;
    final playableUrl = source.playableUrl;
    if (playableUrl == null) {
      throw Exception('Source ${source.server} has no playable URL.');
    }
    final url = _absoluteApiUrl(playableUrl);

    final Map<String, String> headers = {
      if (PlaybackDiagnostics.enabled)
        'X-Playback-Request-Id': _playbackRequestId,
    };
    if (source.referer != null) {
      headers['Referer'] = source.referer!;
    }

    PlaybackDiagnostics.log(_playbackRequestId, 'player.media_open', {
      'server': source.server,
      'type': source.type,
      'host': PlaybackDiagnostics.host(url),
      'proxied': source.proxyUrl?.trim().isNotEmpty == true,
      'refererHost': PlaybackDiagnostics.host(source.referer),
      'captionCount': source.tracks.length,
    });

    // Opening a URL only queues it in the native player. Await actual media
    // progress or an error before reporting that a server works.
    final startup = Stopwatch()..start();
    await player.stop();
    final ready = Completer<void>();
    // libmpv emits recoverable packet/audio warnings here as well as fatal
    // errors. Progress (or the bounded startup deadline) decides readiness.
    final positions = player.stream.position.listen((position) {
      if (position > (_savedPosition ?? Duration.zero) && !ready.isCompleted) {
        PlaybackDiagnostics.log(_playbackRequestId, 'player.first_progress', {
          'elapsedMs': startup.elapsedMilliseconds,
          'server': source.server,
        });
        ready.complete();
      }
    });
    // Attach the error handler immediately, including while open is pending.
    final opened = () async {
      await player.open(
        Media(url, httpHeaders: headers, start: _savedPosition),
      );
      await player.play();
      await ready.future;
    }();
    try {
      await Future.wait([
        opened,
        ready.future,
      ], eagerError: true).timeout(const Duration(seconds: 45));
    } catch (_) {
      await player.stop();
      rethrow;
    } finally {
      if (!ready.isCompleted) ready.complete();
      await positions.cancel();
    }

    await player.play();

    // Default to the first available subtitle track if any exist
    final captions = _captionTracks(source);
    if (_subtitlesEnabled && captions.isNotEmpty) {
      final firstCaption = captions.first;
      final subUrl = _absoluteApiUrl(
        firstCaption.proxyUrl ?? firstCaption.file,
      );
      player.setSubtitleTrack(
        SubtitleTrack.uri(
          subUrl,
          title: firstCaption.label,
          language: firstCaption.label,
        ),
      );
      _currentSubtitleTrack = firstCaption;
    } else {
      player.setSubtitleTrack(SubtitleTrack.no());
      _currentSubtitleTrack = null;
    }
  }

  Future<void> _switchSource(VideoSource source) async {
    if (_isLoading) return;
    _attemptedSources.add(source.playbackKey);
    setState(() {
      _isLoading = true;
      _savedPosition = player.state.position;
    });
    try {
      await _playSource(source);
    } catch (_) {
      try {
        await _playFirstAvailable(
          _playableSources(_watchData!),
          exclude: source,
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to switch server: $error')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSettingsModal() {
    if (_watchData == null && _localDownload == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DefaultTabController(
          length: 3,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                const TabBar(
                  indicatorColor: AppColors.accentStart,
                  labelColor: AppColors.accentStart,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    Tab(text: 'Audio'),
                    Tab(text: 'Quality'),
                    Tab(text: 'Subtitles'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Online builds choose a language/server source. Local
                      // files expose every audio stream retained by FFmpeg.
                      ListView(
                        children: _playingLocalFile
                            ? [
                                if (_localDownload != null)
                                  ListTile(
                                    leading: const Icon(
                                      Icons.download_done_rounded,
                                      color: AppColors.accentStart,
                                    ),
                                    title: Text(
                                      _localDownload!.audioLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Downloaded audio version',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  ),
                                ...player.state.tracks.audio.map((track) {
                                  final selected =
                                      player.state.track.audio.id == track.id;
                                  final label =
                                      track.title?.trim().isNotEmpty == true
                                      ? track.title!
                                      : (track.language?.trim().isNotEmpty ==
                                                true
                                            ? track.language!
                                            : 'Audio ${track.id}');
                                  return ListTile(
                                    title: Text(
                                      label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    trailing: selected
                                        ? const Icon(
                                            Icons.check,
                                            color: AppColors.accentStart,
                                          )
                                        : null,
                                    onTap: () {
                                      Navigator.pop(context);
                                      player.setAudioTrack(track);
                                    },
                                  );
                                }),
                              ]
                            : (_watchData?.sources ?? const <VideoSource>[]).map((
                                source,
                              ) {
                                return ListTile(
                                  title: Text(
                                    '${source.server} (${source.type.toUpperCase()})',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  trailing: _currentSource == source
                                      ? const Icon(
                                          Icons.check,
                                          color: AppColors.accentStart,
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.pop(context);
                                    _switchSource(source);
                                  },
                                );
                              }).toList(),
                      ),
                      // Quality Tab
                      ListView(
                        children: player.state.tracks.video.map((track) {
                          final isSelected =
                              player.state.track.video.id == track.id;

                          String trackName = track.title ?? track.id;
                          if (track.id == 'auto') {
                            trackName = 'Auto';
                          } else if (track.id == 'no') {
                            trackName = 'Video Disabled';
                          } else if (track.h != null && track.h! > 0) {
                            trackName = '${track.h}p';
                          }

                          return ListTile(
                            title: Text(
                              trackName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.accentStart,
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(context);
                              player.setVideoTrack(track);
                            },
                          );
                        }).toList(),
                      ),
                      // Subtitles Tab
                      ListView(
                        children: [
                          ListTile(
                            title: const Text(
                              'None',
                              style: TextStyle(color: Colors.white),
                            ),
                            trailing:
                                _currentSubtitleTrack == null &&
                                    _currentLocalSubtitle == null
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.accentStart,
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(context);
                              player.setSubtitleTrack(SubtitleTrack.no());
                              setState(() {
                                _currentSubtitleTrack = null;
                                _currentLocalSubtitle = null;
                              });
                            },
                          ),
                          if (_playingLocalFile && _localDownload != null)
                            ..._localDownload!.subtitles.map((subtitle) {
                              return ListTile(
                                leading: const Icon(
                                  Icons.offline_pin_rounded,
                                  color: AppColors.accentStart,
                                ),
                                title: Text(
                                  subtitle.label,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: const Text(
                                  'Available offline',
                                  style: TextStyle(color: Colors.white54),
                                ),
                                trailing:
                                    _currentLocalSubtitle?.localPath ==
                                        subtitle.localPath
                                    ? const Icon(
                                        Icons.check,
                                        color: AppColors.accentStart,
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.pop(context);
                                  _setDownloadedSubtitle(subtitle);
                                },
                              );
                            })
                          else if (_currentSource != null)
                            ..._currentSource!.tracks
                                .where((track) {
                                  final kind = track.kind.toLowerCase();
                                  return kind == 'captions' ||
                                      kind == 'subtitles';
                                })
                                .map((track) {
                                  return ListTile(
                                    title: Text(
                                      track.label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    trailing:
                                        _currentSubtitleTrack?.label ==
                                            track.label
                                        ? const Icon(
                                            Icons.check,
                                            color: AppColors.accentStart,
                                          )
                                        : null,
                                    onTap: () {
                                      Navigator.pop(context);
                                      final subUrl = _absoluteApiUrl(
                                        track.proxyUrl ?? track.file,
                                      );
                                      player.setSubtitleTrack(
                                        SubtitleTrack.uri(
                                          subUrl,
                                          title: track.label,
                                          language: track.label,
                                        ),
                                      );
                                      setState(() {
                                        _currentSubtitleTrack = track;
                                      });
                                    },
                                  );
                                }),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _saveProgress();
    _progressSaveTimer?.cancel();
    _seekAnimationTimer?.cancel();
    _playerErrorSubscription?.cancel();
    _playerCompletedSubscription?.cancel();
    _positionSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _stallTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    player.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _retryPlayer,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: MaterialVideoControlsTheme(
        normal: MaterialVideoControlsThemeData(
          bottomButtonBarMargin: const EdgeInsets.only(
            left: 48,
            right: 48,
            bottom: 48,
          ),
          seekBarMargin: const EdgeInsets.only(left: 48, right: 48, bottom: 48),
          topButtonBarMargin: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
          ),
          topButtonBar: [
            MaterialCustomButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.animeTitle} - Episode $_episodeNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          primaryButtonBar: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatefulBuilder(
                  builder: (context, setSliderState) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 32.0),
                      child: SizedBox(
                        height: 150,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: _brightness,
                            min: 0.0,
                            max: 1.0,
                            activeColor: AppColors.accentStart,
                            inactiveColor: Colors.white24,
                            onChanged: (value) async {
                              setSliderState(() {
                                _brightness = value;
                              });
                              try {
                                await ScreenBrightness()
                                    .setApplicationScreenBrightness(value);
                              } catch (_) {}
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            MaterialCustomButton(
              iconSize: 48,
              icon: const Icon(Icons.replay_10, color: Colors.white),
              onPressed: () {
                final pos = player.state.position - const Duration(seconds: 10);
                player.seek(pos < Duration.zero ? Duration.zero : pos);
                _triggerSeekAnimation('left');
              },
            ),
            const SizedBox(width: 32),
            const MaterialPlayOrPauseButton(iconSize: 64),
            const SizedBox(width: 32),
            MaterialCustomButton(
              iconSize: 48,
              icon: const Icon(Icons.forward_10, color: Colors.white),
              onPressed: () {
                final pos = player.state.position + const Duration(seconds: 10);
                player.seek(
                  pos > player.state.duration ? player.state.duration : pos,
                );
                _triggerSeekAnimation('right');
              },
            ),
            const Spacer(),
          ],
          bottomButtonBar: [
            const MaterialPositionIndicator(),
            const Spacer(),
            MaterialCustomButton(
              onPressed: _showSettingsModal,
              icon: const Icon(Icons.settings, color: Colors.white),
            ),
          ],
          buttonBarButtonColor: Colors.white,
          seekBarPositionColor: AppColors.accentStart,
          seekBarThumbColor: AppColors.accentStart,
          seekBarBufferColor: Colors.white24,
          seekBarColor: Colors.white38,
          shiftSubtitlesOnControlsVisibilityChange: true,
        ),
        fullscreen: const MaterialVideoControlsThemeData(),
        child: GestureDetector(
          onDoubleTapDown: (details) {
            if (_isLoading) return;
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx > screenWidth / 2) {
              final pos = player.state.position + const Duration(seconds: 10);
              player.seek(
                pos > player.state.duration ? player.state.duration : pos,
              );
              _triggerSeekAnimation('right');
            } else {
              final pos = player.state.position - const Duration(seconds: 10);
              player.seek(pos < Duration.zero ? Duration.zero : pos);
              _triggerSeekAnimation('left');
            }
          },
          onLongPressStart: (_) {
            if (_isLoading) return;
            player.setRate(2.0);
            setState(() {
              _isFastForwarding = true;
            });
          },
          onLongPressEnd: (_) {
            player.setRate(1.0);
            setState(() {
              _isFastForwarding = false;
            });
          },
          child: Stack(
            children: [
              Video(
                controller: controller,
                controls: _isLoading ? NoVideoControls : MaterialVideoControls,
                subtitleViewConfiguration: const SubtitleViewConfiguration(
                  style: TextStyle(
                    height: 1.4,
                    fontSize: 36.0,
                    letterSpacing: 0.0,
                    wordSpacing: 0.0,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    backgroundColor: Color(0x66000000),
                  ),
                  textAlign: TextAlign.center,
                  padding: EdgeInsets.only(left: 24, right: 24, bottom: 30),
                ),
              ),
              if (_isLoading)
                const Positioned.fill(
                  child: AbsorbPointer(
                    child: ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentStart,
                        ),
                      ),
                    ),
                  ),
                ),
              StreamBuilder<Duration>(
                stream: player.stream.position,
                initialData: player.state.position,
                builder: (context, snapshot) {
                  final action = _activeSkipAction(
                    snapshot.data ?? Duration.zero,
                  );
                  if (_isLoading || action == null) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    right: 24,
                    bottom: 104,
                    child: SafeArea(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.78),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        onPressed: () => player.seek(
                          Duration(
                            milliseconds: (action.range.endSeconds * 1000)
                                .round(),
                          ),
                        ),
                        icon: const Icon(Icons.skip_next_rounded),
                        label: Text(action.label),
                      ),
                    ),
                  );
                },
              ),
              if (_episodeCompleted && _nextEpisode != null)
                Positioned(
                  right: 24,
                  bottom: 40,
                  child: SafeArea(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _playNextEpisode,
                        icon: const Icon(Icons.skip_next_rounded),
                        label: Text('Play next episode · Ep $_nextEpisode'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_isFastForwarding)
                const Positioned(
                  top: 32,
                  right: 32,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '2x Speed ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Icon(Icons.fast_forward, color: Colors.white),
                    ],
                  ),
                ),
              if (_seekAnimationSide != null)
                Positioned(
                  left: _seekAnimationSide == 'left' ? 0 : null,
                  right: _seekAnimationSide == 'right' ? 0 : null,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.35,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.horizontal(
                          left: _seekAnimationSide == 'right'
                              ? const Radius.circular(150)
                              : Radius.zero,
                          right: _seekAnimationSide == 'left'
                              ? const Radius.circular(150)
                              : Radius.zero,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _seekAnimationSide == 'right'
                                ? Icons.fast_forward
                                : Icons.fast_rewind,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '10 seconds',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
