import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/session_state.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class SubtitleDownloadRequest {
  final String url;
  final String label;
  final String language;
  final String? referer;

  const SubtitleDownloadRequest({
    required this.url,
    required this.label,
    required this.language,
    this.referer,
  });
}

class SubtitleDownloadResult {
  final String label;
  final String language;
  final String localPath;

  const SubtitleDownloadResult({
    required this.label,
    required this.language,
    required this.localPath,
  });
}

class HlsDownloaderService {
  final _notifications = FlutterLocalNotificationsPlugin();
  final Map<String, FFmpegSession> _activeSessions = {};

  HlsDownloaderService() {
    _initNotifications();
  }

  void _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(settings: initSettings);
  }

  Future<void> requestPermissions() async {
    await Permission.notification.request();
  }

  Future<void> cancelDownload(String id) async {
    final session = _activeSessions[id];
    if (session != null) {
      final sessionId = session.getSessionId();
      await FFmpegKit.cancel(sessionId);
      _activeSessions.remove(id);
      _notifications.cancel(id: id.hashCode);
    }
  }

  static Future<String> outputPathFor(String id) async {
    final supportDir = await getApplicationSupportDirectory();
    final downloadsDir = Directory('${supportDir.path}/downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return '${downloadsDir.path}/$id.mp4';
  }

  static Future<Directory> subtitleDirectoryFor(String id) async {
    final supportDir = await getApplicationSupportDirectory();
    final directory = Directory('${supportDir.path}/downloads/${id}_subtitles');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<List<SubtitleDownloadResult>> downloadSubtitles(
    String id,
    List<SubtitleDownloadRequest> requests,
  ) async {
    if (requests.isEmpty) return const [];
    final directory = await subtitleDirectoryFor(id);
    await for (final entity in directory.list()) {
      if (entity is File) await entity.delete();
    }

    final client = http.Client();
    final downloaded = <SubtitleDownloadResult>[];
    try {
      for (var index = 0; index < requests.length; index++) {
        final request = requests[index];
        try {
          final uri = Uri.parse(request.url);
          final response = await client
              .send(
                http.Request('GET', uri)
                  ..followRedirects = true
                  ..maxRedirects = 5
                  ..headers.addAll({
                    'Accept': 'text/vtt, application/x-subrip, text/plain, */*',
                    if (request.referer?.isNotEmpty == true)
                      'Referer': request.referer!,
                  }),
              )
              .timeout(const Duration(seconds: 20));
          if (response.statusCode < 200 || response.statusCode >= 300) {
            continue;
          }
          final extension = _subtitleExtension(
            response.request?.url ?? uri,
            response.headers['content-type'],
          );
          final safeLabel = request.label
              .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
              .replaceAll(RegExp(r'^_+|_+$'), '');
          final file = File(
            '${directory.path}/${index + 1}_${safeLabel.isEmpty ? 'subtitle' : safeLabel}.$extension',
          );
          final part = File('${file.path}.part');
          final sink = part.openWrite();
          await response.stream.pipe(sink);
          if (await part.length() == 0) {
            await part.delete();
            continue;
          }
          await part.rename(file.path);
          downloaded.add(
            SubtitleDownloadResult(
              label: request.label,
              language: request.language,
              localPath: file.path,
            ),
          );
        } catch (_) {
          // A broken subtitle must not discard an otherwise playable episode.
        }
      }
    } finally {
      client.close();
    }
    return downloaded;
  }

  static String _subtitleExtension(Uri uri, String? contentType) {
    final path = uri.path.toLowerCase();
    for (final extension in const ['vtt', 'srt', 'ass', 'ssa']) {
      if (path.endsWith('.$extension')) return extension;
    }
    final normalized = contentType?.toLowerCase() ?? '';
    if (normalized.contains('subrip')) return 'srt';
    if (normalized.contains('ass')) return 'ass';
    return 'vtt';
  }

  Stream<double> downloadEpisode(
    String id,
    String m3u8Url, {
    String? referer,
  }) async* {
    yield 0.0;

    final outputPath = await outputPathFor(id);
    final notificationId = id.hashCode;

    // Check if already exists
    if (File(outputPath).existsSync()) {
      File(outputPath).deleteSync();
    }

    // Attempt to get duration using FFprobe
    int totalDurationMs =
        1440000; // Default to 24 mins for Anime if probe fails
    try {
      final sessionInfo = await FFprobeKit.getMediaInformation(m3u8Url);
      final mediaInfo = sessionInfo.getMediaInformation();
      if (mediaInfo != null) {
        final durationStr = mediaInfo.getDuration();
        if (durationStr != null) {
          totalDurationMs = (double.parse(durationStr) * 1000).toInt();
        }
      }
    } catch (e) {
      // Ignore and use default 24 mins
    }
    if (totalDurationMs <= 0) totalDurationMs = 1440000;

    double currentProgress = 0.0;
    int currentSizeInBytes = 0;

    final arguments = <String>[];
    if (referer != null && referer.isNotEmpty) {
      arguments.add('-headers');
      arguments.add('Referer: $referer\r\n');
    }
    final isHls = m3u8Url.toLowerCase().contains('.m3u8');
    if (isHls) {
      arguments.add('-allowed_segment_extensions');
      arguments.add('ALL');
      arguments.add('-extension_picky');
      arguments.add('0');
    }
    arguments.add('-i');
    arguments.add(m3u8Url);
    // Explicitly retain every audio stream exposed by the selected HLS source.
    // The previous implicit mapping kept only the first/default audio stream.
    arguments.addAll(['-map', '0:v:0?', '-map', '0:a?']);
    arguments.add('-c');
    arguments.add('copy');
    arguments.add('-movflags');
    arguments.add('+faststart');
    arguments.add('-y');
    arguments.add(outputPath);

    final session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) async {},
      (log) {
        if (kDebugMode) {
          debugPrint('FFmpeg Log: ${log.getMessage()}');
        }
      },
      (statistics) {
        final timeInMs = statistics.getTime();
        currentSizeInBytes = statistics.getSize();
        if (timeInMs > 0) {
          currentProgress = timeInMs / totalDurationMs;
          if (currentProgress > 0.99) currentProgress = 0.99;
        }
      },
    );

    _activeSessions[id] = session;

    void showProgressNotification(double progress, int sizeInBytes) {
      final sizeInMb = (sizeInBytes / 1024 / 1024).toStringAsFixed(1);
      final estimatedTotalMb = progress > 0.0
          ? ((sizeInBytes / progress) / 1024 / 1024).toStringAsFixed(1)
          : '...';

      _notifications.show(
        id: notificationId,
        title: 'Downloading Episode...',
        body: '$sizeInMb MB / $estimatedTotalMb MB',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'download_channel',
            'Downloads',
            channelDescription: 'Anime download progress',
            importance: Importance.low,
            priority: Priority.low,
            showProgress: true,
            maxProgress: 100,
            progress: (progress * 100).toInt(),
            ongoing: true,
            onlyAlertOnce: true,
            actions: [
              const AndroidNotificationAction(
                'cancel_download',
                'Cancel',
                cancelNotification: true,
                showsUserInterface: false,
              ),
            ],
          ),
        ),
      );
    }

    // fake progress fallback if stats fail
    double fakeProgress = 0.0;

    while (true) {
      await Future.delayed(const Duration(milliseconds: 1000));
      final state = await session.getState();

      if (currentProgress == 0.0) {
        fakeProgress += 0.01;
        if (fakeProgress > 0.15) fakeProgress = 0.15;
      }
      final displayProgress = currentProgress > 0.0
          ? currentProgress
          : fakeProgress;

      if (state == SessionState.completed || state == SessionState.failed) {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          _notifications.show(
            id: notificationId,
            title: 'Download Complete',
            body: 'Episode downloaded successfully.',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'download_channel',
                'Downloads',
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
              ),
            ),
          );
          _activeSessions.remove(id);
          yield 1.0;
        } else {
          _notifications.show(
            id: notificationId,
            title: 'Download Failed / Cancelled',
            body: 'Episode failed or was cancelled.',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'download_channel',
                'Downloads',
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
              ),
            ),
          );
          _activeSessions.remove(id);
          final failLog = await session.getFailStackTrace();
          throw Exception(
            'Download failed with state: $state, error: $failLog',
          );
        }
        break;
      } else {
        showProgressNotification(displayProgress, currentSizeInBytes);
        yield displayProgress;
      }
    }
  }
}

final hlsDownloaderProvider = Provider((ref) => HlsDownloaderService());
