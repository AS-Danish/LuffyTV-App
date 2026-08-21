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
import 'dart:io';

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

  Stream<double> downloadEpisode(
    String id,
    String m3u8Url, {
    String? referer,
  }) async* {
    yield 0.0;

    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/$id.mp4';
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
    arguments.add('-f');
    arguments.add('hls');
    arguments.add('-allowed_segment_extensions');
    arguments.add('ALL');
    arguments.add('-extension_picky');
    arguments.add('0');
    arguments.add('-i');
    arguments.add(m3u8Url);
    arguments.add('-c');
    arguments.add('copy');
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
