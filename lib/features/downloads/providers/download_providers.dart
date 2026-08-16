import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';
import 'package:luffytv/core/services/hls_downloader_service.dart';
import 'package:luffytv/features/home/data/models/episode.dart';
import 'package:luffytv/features/home/data/models/anime.dart';

final downloadItemsProvider = NotifierProvider<DownloadNotifier, List<DownloadItem>>(DownloadNotifier.new);

class DownloadNotifier extends Notifier<List<DownloadItem>> {
  static const _prefsKey = 'luffytv_downloads';

  @override
  List<DownloadItem> build() {
    // Return empty initially, load from prefs asynchronously
    Future.microtask(_loadFromPrefs);
    return [];
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_prefsKey);
    if (data != null) {
      final items = data.map((jsonStr) => DownloadItem.fromJson(jsonDecode(jsonStr))).toList();
      // Ensure anything that was 'downloading' when app closed is reset to 'failed' or 'pending'
      final resetItems = items.map((item) {
        if (item.state == DownloadState.downloading) {
          return item.copyWith(state: DownloadState.failed);
        }
        return item;
      }).toList();
      state = resetItems;
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_prefsKey, data);
  }

  void startDownload(Anime anime, Episode episode, String m3u8Url, {String? referer}) {
    final id = '${anime.id}_${episode.episodeNumber}'; // using anime.id as slug equivalent
    
    // Check if already downloading or downloaded
    if (state.any((item) => item.id == id && item.state != DownloadState.failed)) {
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

  Future<void> _executeDownload(String id, String m3u8Url, {String? referer}) async {
    final downloader = ref.read(hlsDownloaderProvider);
    await downloader.requestPermissions();
    
    try {
      await for (final progress in downloader.downloadEpisode(id, m3u8Url, referer: referer)) {
        _updateItem(id, (item) => item.copyWith(progress: progress));
      }
      
      final tempDir = await getTemporaryDirectory();
      final localPath = '${tempDir.path}/$id.mp4';
      
      _updateItem(id, (item) => item.copyWith(
        state: DownloadState.completed, 
        progress: 1.0,
        localM3u8Path: localPath
      ));
    } catch (e) {
      _updateItem(id, (item) => item.copyWith(state: DownloadState.failed));
    }
  }

  void _updateItem(String id, DownloadItem Function(DownloadItem) update) {
    state = state.map((item) => item.id == id ? update(item) : item).toList();
    _saveToPrefs();
  }

  void removeDownload(String id) {
    state = state.where((item) => item.id != id).toList();
    _saveToPrefs();
  }

  void cancelDownload(String id) {
    ref.read(hlsDownloaderProvider).cancelDownload(id);
    _updateItem(id, (item) => item.copyWith(state: DownloadState.failed));
  }
}
