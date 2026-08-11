import 'dart:async';
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

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String animeTitle;
  final String animeSlug;
  final int episodeNumber;
  final bool isLocal;

  const VideoPlayerScreen({
    super.key,
    required this.animeTitle,
    required this.animeSlug,
    required this.episodeNumber,
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

    _initPlayer();
    _initBrightness();
  }

  Future<void> _initBrightness() async {
    try {
      final current = await ScreenBrightness().current;
      if (mounted) {
        setState(() {
          _brightness = current;
        });
      }
    } catch (_) {}
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

  Future<void> _initPlayer() async {
    try {
      final repo = ref.read(animeRepositoryProvider);
      final watchData = await repo.fetchWatchData(widget.animeSlug, widget.episodeNumber);
      _watchData = watchData;

      VideoSource? bestSource;
      try {
        bestSource = watchData.sources.firstWhere((s) => s.type == 'sub' && s.m3u8 != null);
      } catch (_) {
        if (watchData.sources.isNotEmpty) {
          bestSource = watchData.sources.first;
        }
      }

      if (bestSource == null) {
        throw Exception('No playable video sources found');
      }

      await _playSource(bestSource);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _playSource(VideoSource source) async {
    _currentSource = source;
    String url = source.proxyUrl ?? source.m3u8 ?? source.url;
    if (url.startsWith('/')) {
      url = '${ApiConstants.baseUrl}$url';
    }
    
    final Map<String, String> headers = {};
    if (source.referer != null) {
      headers['Referer'] = source.referer!;
    }
    
    await player.open(Media(url, httpHeaders: headers));
    
    if (_savedPosition != null) {
      await player.seek(_savedPosition!);
    }
    
    player.play();

    // Default to the first available subtitle track if any exist
    final captions = source.tracks.where((t) => t.kind == 'captions').toList();
    if (captions.isNotEmpty) {
      final firstCaption = captions.first;
      String subUrl = firstCaption.proxyUrl ?? firstCaption.file;
      if (subUrl.startsWith('/')) subUrl = '${ApiConstants.baseUrl}$subUrl';
      player.setSubtitleTrack(SubtitleTrack.uri(subUrl, title: firstCaption.label, language: firstCaption.label));
      _currentSubtitleTrack = firstCaption;
    } else {
      player.setSubtitleTrack(SubtitleTrack.no());
      _currentSubtitleTrack = null;
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
          length: 2,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                const TabBar(
                  indicatorColor: AppColors.accentStart,
                  labelColor: AppColors.accentStart,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    Tab(text: 'Audio & Server'),
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
                            title: Text('${source.server} (${source.type.toUpperCase()})', style: const TextStyle(color: Colors.white)),
                            trailing: _currentSource == source ? const Icon(Icons.check, color: AppColors.accentStart) : null,
                            onTap: () {
                              Navigator.pop(context);
                              setState(() { 
                                _isLoading = true; 
                                _savedPosition = player.state.position;
                              });
                              _playSource(source).then((_) {
                                setState(() { _isLoading = false; });
                              });
                            },
                          );
                        }).toList(),
                      ),
                      // Subtitles Tab
                      ListView(
                        children: [
                          ListTile(
                            title: const Text('None', style: TextStyle(color: Colors.white)),
                            trailing: _currentSubtitleTrack == null ? const Icon(Icons.check, color: AppColors.accentStart) : null,
                            onTap: () {
                              Navigator.pop(context);
                              player.setSubtitleTrack(SubtitleTrack.no());
                              setState(() { _currentSubtitleTrack = null; });
                            },
                          ),
                          if (_currentSource != null)
                            ..._currentSource!.tracks.where((t) => t.kind == 'captions').map((track) {
                              return ListTile(
                                title: Text(track.label, style: const TextStyle(color: Colors.white)),
                                trailing: _currentSubtitleTrack?.label == track.label ? const Icon(Icons.check, color: AppColors.accentStart) : null,
                                onTap: () {
                                  Navigator.pop(context);
                                  String subUrl = track.proxyUrl ?? track.file;
                                  if (subUrl.startsWith('/')) subUrl = '${ApiConstants.baseUrl}$subUrl';
                                  player.setSubtitleTrack(SubtitleTrack.uri(subUrl, title: track.label, language: track.label));
                                  setState(() { _currentSubtitleTrack = track; });
                                },
                              );
                            }).toList(),
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
    _seekAnimationTimer?.cancel();
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
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
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
          bottomButtonBarMargin: const EdgeInsets.only(left: 48, right: 48, bottom: 48),
          seekBarMargin: const EdgeInsets.only(left: 48, right: 48, bottom: 48),
          topButtonBarMargin: const EdgeInsets.only(left: 16, right: 16, top: 24),
          topButtonBar: [
            MaterialCustomButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.animeTitle} - Episode ${widget.episodeNumber}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          primaryButtonBar: [
            StatefulBuilder(
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
                            await ScreenBrightness().setScreenBrightness(value);
                          } catch (_) {}
                        },
                      ),
                    ),
                  ),
                );
              }
            ),
            const Spacer(),
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
                player.seek(pos > player.state.duration ? player.state.duration : pos);
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
        ),
        fullscreen: const MaterialVideoControlsThemeData(),
        child: GestureDetector(
          onDoubleTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx > screenWidth / 2) {
              final pos = player.state.position + const Duration(seconds: 10);
              player.seek(pos > player.state.duration ? player.state.duration : pos);
              _triggerSeekAnimation('right');
            } else {
              final pos = player.state.position - const Duration(seconds: 10);
              player.seek(pos < Duration.zero ? Duration.zero : pos);
              _triggerSeekAnimation('left');
            }
          },
          onLongPressStart: (_) {
            player.setRate(2.0);
            setState(() { _isFastForwarding = true; });
          },
          onLongPressEnd: (_) {
            player.setRate(1.0);
            setState(() { _isFastForwarding = false; });
          },
          child: Stack(
            children: [
              Video(
                controller: controller,
                controls: MaterialVideoControls,
                subtitleViewConfiguration: const SubtitleViewConfiguration(
                  style: TextStyle(
                    height: 1.4,
                    fontSize: 28.0,
                    letterSpacing: 0.0,
                    wordSpacing: 0.0,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    backgroundColor: Color(0xaa000000),
                  ),
                  textAlign: TextAlign.center,
                  padding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
                ),
              ),
              if (_isFastForwarding)
                const Positioned(
                  top: 32,
                  right: 32,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('2x Speed ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
                          left: _seekAnimationSide == 'right' ? const Radius.circular(150) : Radius.zero,
                          right: _seekAnimationSide == 'left' ? const Radius.circular(150) : Radius.zero,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _seekAnimationSide == 'right' ? Icons.fast_forward : Icons.fast_rewind,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          const Text('10 seconds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
