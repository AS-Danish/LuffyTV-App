import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';
import 'package:luffytv/core/services/hls_downloader_service.dart';
import 'package:luffytv/features/home/data/models/episode.dart';
import 'package:luffytv/features/home/data/models/anime.dart';

final downloadItemsProvider =
    NotifierProvider<DownloadNotifier, List<DownloadItem>>(
      DownloadNotifier.new,
    );

class DownloadNotifier extends Notifier<List<DownloadItem>> {
  static const _prefsKey = 'luffytv_downloads';

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
        if (item.state == DownloadState.downloading) {
          resetItems.add(item.copyWith(state: DownloadState.failed));
          continue;
        }
        if (item.state == DownloadState.completed &&
            (item.localM3u8Path?.isEmpty != false ||
                !await File(item.localM3u8Path!).exists())) {
          resetItems.add(item.copyWith(state: DownloadState.failed));
          continue;
        }
        resetItems.add(item);
      }
      state = resetItems;
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
      state: DownloadState.downloading,
      progress: 0.0,
    );

    // Remove existing if it was a failed attempt
    state = [...state.where((item) => item.id != id), newItem];
    _saveToPrefs();

    _executeDownload(id, m3u8Url, referer: referer);
  }

  Future<void> _executeDownload(
    String id,
    String m3u8Url, {
    String? referer,
  }) async {
    final downloader = ref.read(hlsDownloaderProvider);
    await downloader.requestPermissions();

    try {
      await for (final progress in downloader.downloadEpisode(
        id,
        m3u8Url,
        referer: referer,
      )) {
        _updateItem(id, (item) => item.copyWith(progress: progress));
      }

      final localPath = await HlsDownloaderService.outputPathFor(id);

      _updateItem(
        id,
        (item) => item.copyWith(
          state: DownloadState.completed,
          progress: 1.0,
          localM3u8Path: localPath,
        ),
      );
    } catch (e) {
      _updateItem(id, (item) => item.copyWith(state: DownloadState.failed));
    }
  }

  void _updateItem(String id, DownloadItem Function(DownloadItem) update) {
    state = state.map((item) => item.id == id ? update(item) : item).toList();
    _saveToPrefs();
  }

  Future<void> removeDownload(String id) async {
    final item = state.where((entry) => entry.id == id).firstOrNull;
    state = state.where((item) => item.id != id).toList();
    await _saveToPrefs();
    final path = item?.localM3u8Path;
    if (path?.isNotEmpty == true) {
      final file = File(path!);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> cancelDownload(String id) async {
    await ref.read(hlsDownloaderProvider).cancelDownload(id);
    _updateItem(id, (item) => item.copyWith(state: DownloadState.failed));
    final path = await HlsDownloaderService.outputPathFor(id);
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
