import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:luffytv/core/utils/api_constants.dart';
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

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;
  bool _isLoading = true;
  String? _error;

  WatchData? _watchData;
  VideoSource? _currentSource;
  VideoTrack? _currentSubtitleTrack;
  Duration? _savedPosition;
  bool _isFastForwarding = false;
  double _brightness = 0.5;
  String? _seekAnimationSide;
  Timer? _seekAnimationTimer;
  Timer? _progressSaveTimer;
  StreamSubscription<String>? _playerErrorSubscription;
  bool _sourceFallbackInProgress = false;
  bool _playingLocalFile = false;
  bool _subtitlesEnabled = true;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    player = Player();
    controller = VideoController(player);
    _playerErrorSubscription = player.stream.error.listen(_handlePlaybackError);

    _initPlayer();
    _initBrightness();

    // Save progress periodically
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _saveProgress();
    });
  }

  void _saveProgress() {
    if (widget.anime != null && player.state.duration > Duration.zero) {
      LocalDbService.saveProgress(
        animeSlug: widget.animeSlug,
        anime: widget.anime!,
        episodeNumber: widget.episodeNumber,
        position: player.state.position,
        duration: player.state.duration,
      );
    }
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

  String _absoluteApiUrl(String url) {
    final value = url.trim();
    if (value.startsWith('/')) return '${ApiConstants.baseUrl}$value';
    return value;
  }

  Future<WatchData> _fetchPlayableWatchData({bool forceRefresh = false}) async {
    final repo = ref.read(animeRepositoryProvider);
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final watchData = await repo.fetchWatchData(
          widget.animeSlug,
          widget.episodeNumber,
          forceRefresh: forceRefresh || attempt > 0,
        );
        if (_playableSources(watchData).isNotEmpty) return watchData;
        lastError = Exception('The API returned an empty source list.');
      } catch (error) {
        lastError = error;
      }
      if (attempt < 2) {
        await Future<void>.delayed(
          Duration(milliseconds: attempt == 0 ? 350 : 900),
        );
      }
    }
    if (kDebugMode) debugPrint('Source resolution failed: $lastError');
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
      try {
        await _playSource(source);
        return source;
      } catch (error) {
        lastError = error;
        if (kDebugMode) {
          debugPrint('Source ${source.server} failed: $error');
        }
      }
    }
    throw Exception(lastError ?? 'All resolved video sources failed.');
  }

  Future<void> _handlePlaybackError(String message) async {
    if (!mounted ||
        widget.isLocal ||
        _playingLocalFile ||
        _isLoading ||
        _sourceFallbackInProgress ||
        _watchData == null) {
      return;
    }
    _sourceFallbackInProgress = true;
    _savedPosition = player.state.position;
    try {
      final alternatives = _playableSources(_watchData!);
      try {
        await _playFirstAvailable(alternatives, exclude: _currentSource);
      } catch (_) {
        final refreshed = await _fetchPlayableWatchData(forceRefresh: true);
        _watchData = refreshed;
        await _playFirstAvailable(
          _playableSources(refreshed),
          exclude: _currentSource,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Switched to a working video server.')),
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Automatic source fallback failed: $message / $error');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Playback was interrupted. Tap retry if it continues.',
            ),
          ),
        );
      }
    } finally {
      _sourceFallbackInProgress = false;
    }
  }

  Future<void> _retryPlayer() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await player.stop();
    await _initPlayer(forceRefresh: true);
  }

  Future<void> _initPlayer({bool forceRefresh = false}) async {
    try {
      await _loadPlaybackPreferences();
      final downloadId = '${widget.animeSlug}_${widget.episodeNumber}';
      final downloads = ref.read(downloadItemsProvider);
      final localItem = downloads
          .where(
            (d) => d.id == downloadId && d.state == DownloadState.completed,
          )
          .firstOrNull;

      // If the file is downloaded (or forced local), play the local file
      if (widget.isLocal || localItem != null) {
        _playingLocalFile = true;
        if (localItem == null || localItem.localM3u8Path == null) {
          throw Exception('Local file not found.');
        }

        // Restore progress
        final savedProgress = LocalDbService.getProgress(widget.animeSlug);
        if (savedProgress != null) {
          final epProgress =
              savedProgress.episodes[widget.episodeNumber.toString()];
          if (epProgress != null) {
            _savedPosition = Duration(seconds: epProgress.positionSeconds);
          }
        }

        await player.open(Media(localItem.localM3u8Path!));
        if (_savedPosition != null) {
          await player.seek(_savedPosition!);
        }
        player.play();

        // Fetch watch data in background to enable subtitles and settings for local files
        try {
          final watchData = await _fetchPlayableWatchData(
            forceRefresh: forceRefresh,
          );
          _watchData = watchData;
          final playableSources = _playableSources(watchData);
          final bestSource = playableSources.firstOrNull;
          if (bestSource != null) {
            _currentSource = bestSource;
            final captions = _captionTracks(bestSource);
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
            }
          }
        } catch (_) {}

        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Otherwise fetch from API and stream
      _playingLocalFile = false;
      final watchData = await _fetchPlayableWatchData(
        forceRefresh: forceRefresh,
      );
      _watchData = watchData;

      // Check if we have saved progress to resume from
      final savedProgress = LocalDbService.getProgress(widget.animeSlug);
      if (savedProgress != null) {
        final epProgress =
            savedProgress.episodes[widget.episodeNumber.toString()];
        if (epProgress != null) {
          _savedPosition = Duration(seconds: epProgress.positionSeconds);
        }
      }

      await _playFirstAvailable(_playableSources(watchData));

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _playSource(VideoSource source) async {
    _currentSource = source;
    final playableUrl = source.playableUrl;
    if (playableUrl == null) {
      throw Exception('Source ${source.server} has no playable URL.');
    }
    final url = _absoluteApiUrl(playableUrl);

    final Map<String, String> headers = {};
    if (source.referer != null) {
      headers['Referer'] = source.referer!;
    }

    if (kDebugMode) {
      debugPrint('Headers: $headers');
      debugPrint('==========================\n');
    }

    await player.open(Media(url, httpHeaders: headers));

    if (_savedPosition != null) {
      await player.seek(_savedPosition!);
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
    if (_watchData == null) return;

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
                    Tab(text: 'Server'),
                    Tab(text: 'Quality'),
                    Tab(text: 'Subtitles'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Audio & Server Tab
                      ListView(
                        children: _watchData!.sources.map((source) {
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
                            trailing: _currentSubtitleTrack == null
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
                              });
                            },
                          ),
                          if (_currentSource != null)
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
    player.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentStart),
        ),
      );
    }

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
                '${widget.animeTitle} - Episode ${widget.episodeNumber}',
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
                controls: MaterialVideoControls,
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
