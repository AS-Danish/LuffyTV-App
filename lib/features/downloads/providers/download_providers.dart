import 'dart:convert';
import 'dart:io';
import 'package:luffytv/core/services/app_telemetry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';
import 'package:luffytv/core/services/hls_downloader_service.dart';
import 'package:luffytv/features/home/data/models/episode.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/home/data/models/watch_data.dart';

final downloadItemsProvider =
    NotifierProvider<DownloadNotifier, List<DownloadItem>>(
      DownloadNotifier.new,
    );

class DownloadNotifier extends Notifier<List<DownloadItem>> {
  static const _prefsKey = 'luffytv_downloads';
  final Map<String, Object> _jobs = {};
  Future<void> _queue = Future<void>.value();

  static Future<List<DownloadItem>> loadStoredDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_prefsKey) ?? const <String>[];
    return data.map((value) {
      return DownloadItem.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
    }).toList();
  }

  @override
  List<DownloadItem> build() {
    // Return empty initially, load from prefs asynchronously
    Future.microtask(_loadFromPrefs);
    return [];
  }

  Future<void> _loadFromPrefs() async {
    final items = await loadStoredDownloads();
    if (items.isNotEmpty) {
      // Ensure anything that was 'downloading' when app closed is reset to 'failed' or 'pending'
      final resetItems = <DownloadItem>[];
      for (final item in items) {
        if (item.state == DownloadState.downloading ||
            item.state == DownloadState.pending) {
          resetItems.add(item.copyWith(state: DownloadState.failed));
          continue;
        }
        if (item.state == DownloadState.completed &&
            (item.localM3u8Path?.isEmpty != false ||
                !await File(item.localM3u8Path!).exists())) {
          resetItems.add(item.copyWith(state: DownloadState.failed));
          continue;
        }
        final existingSubtitles = <DownloadedSubtitle>[];
        for (final subtitle in item.subtitles) {
          if (await File(subtitle.localPath).exists()) {
            existingSubtitles.add(subtitle);
          }
        }
        resetItems.add(item.copyWith(subtitles: existingSubtitles));
      }
      final currentIds = state.map((item) => item.id).toSet();
      state = [
        ...resetItems.where((item) => !currentIds.contains(item.id)),
        ...state,
      ];
      await _saveToPrefs();
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_prefsKey, data);
  }

  void startDownload(
    Anime anime,
    Episode episode,
    String m3u8Url, {
    String? referer,
    String sourceType = 'sub',
    String audioLabel = 'Original audio',
    List<SubtitleDownloadRequest> subtitles = const [],
    SkipData? skipData,
    Future<({String url, String? referer})> Function()? refreshSource,
  }) {
    final id =
        '${anime.id}_${episode.episodeNumber}'; // using anime.id as slug equivalent

    // Check if already downloading or downloaded
    if (state.any(
      (item) => item.id == id && item.state != DownloadState.failed,
    )) {
      return;
    }

    final newItem = DownloadItem(
      id: id,
      animeSlug: anime.id,
      animeTitle: anime.title,
      posterUrl: anime.posterUrl,
      episode: episode,
      state: DownloadState.pending,
      progress: 0.0,
      sourceType: sourceType,
      audioLabel: audioLabel,
      skipData: skipData,
    );

    // Remove existing if it was a failed attempt
    state = [...state.where((item) => item.id != id), newItem];
    _saveToPrefs();

    final job = Object();
    _jobs[id] = job;
    _queue = _queue.then((_) async {
      if (!identical(_jobs[id], job)) return;
      await _executeDownload(
        id,
        m3u8Url,
        job: job,
        referer: referer,
        subtitles: subtitles,
        refreshSource: refreshSource,
      );
    });
  }

  Future<void> _executeDownload(
    String id,
    String m3u8Url, {
    String? referer,
    List<SubtitleDownloadRequest> subtitles = const [],
    required Object job,
    Future<({String url, String? referer})> Function()? refreshSource,
  }) async {
    final downloader = ref.read(hlsDownloaderProvider);
    try {
      await downloader.requestPermissions();
      if (!identical(_jobs[id], job)) return;
      _updateItem(
        id,
        (item) => item.copyWith(state: DownloadState.downloading),
      );
      // Subtitle proxy links can expire, so save them before the much longer
      // video transfer starts.
      final localSubtitles = await downloader.downloadSubtitles(id, subtitles);
      if (!identical(_jobs[id], job)) return;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await for (final progress in downloader.downloadEpisode(
            id,
            m3u8Url,
            referer: referer,
          )) {
            if (!identical(_jobs[id], job)) {
              await downloader.cancelDownload(id);
              return;
            }
            _updateItem(id, (item) => item.copyWith(progress: progress));
          }
          break;
        } catch (_) {
          if (!identical(_jobs[id], job)) return;
          if (attempt == 1 || refreshSource == null) rethrow;
          final refreshed = await refreshSource();
          if (!identical(_jobs[id], job)) return;
          m3u8Url = refreshed.url;
          referer = refreshed.referer;
          _updateItem(id, (item) => item.copyWith(progress: 0));
        }
      }
      if (!identical(_jobs[id], job)) return;

      final localPath = await HlsDownloaderService.outputPathFor(id);

      _updateItem(
        id,
        (item) => item.copyWith(
          state: DownloadState.completed,
          progress: 1.0,
          localM3u8Path: localPath,
          subtitles: localSubtitles
              .map(
                (subtitle) => DownloadedSubtitle(
                  label: subtitle.label,
                  language: subtitle.language,
                  localPath: subtitle.localPath,
                ),
              )
              .toList(),
          failedSubtitleCount: subtitles.length - localSubtitles.length,
        ),
      );
    } catch (e, stack) {
      if (!identical(_jobs[id], job)) return;
      AppTelemetry.report(
        'download.failed',
        e,
        stack: stack,
        context: {'host': Uri.tryParse(m3u8Url)?.host},
      );
      _updateItem(
        id,
        (item) => item.copyWith(
          state: DownloadState.failed,
          errorMessage:
              'Download could not finish. Check your connection and retry from the episode page.',
        ),
      );
      try {
        await _deleteSubtitleDirectory(id);
      } catch (_) {
        /* Cleanup must not block the queue. */
      }
    } finally {
      if (identical(_jobs[id], job)) _jobs.remove(id);
    }
  }

  void _updateItem(String id, DownloadItem Function(DownloadItem) update) {
    state = state.map((item) => item.id == id ? update(item) : item).toList();
    _saveToPrefs();
  }

  Future<void> removeDownload(String id) async {
    _jobs.remove(id);
    await ref.read(hlsDownloaderProvider).cancelDownload(id);
    final item = state.where((entry) => entry.id == id).firstOrNull;
    state = state.where((item) => item.id != id).toList();
    await _saveToPrefs();
    final path = item?.localM3u8Path;
    if (path?.isNotEmpty == true) {
      final file = File(path!);
      if (await file.exists()) await file.delete();
    }
    await _deleteSubtitleDirectory(id);
  }

  Future<void> cancelDownload(String id) async {
    _jobs.remove(id);
    await ref.read(hlsDownloaderProvider).cancelDownload(id);
    _updateItem(id, (item) => item.copyWith(state: DownloadState.failed));
    final path = await HlsDownloaderService.outputPathFor(id);
    final file = File(path);
    if (await file.exists()) await file.delete();
    await _deleteSubtitleDirectory(id);
  }

  Future<void> _deleteSubtitleDirectory(String id) async {
    final directory = await HlsDownloaderService.subtitleDirectoryFor(id);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
