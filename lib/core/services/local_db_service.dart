import 'package:hive_flutter/hive_flutter.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'dart:convert';

class EpisodeProgress {
  final int positionSeconds;
  final int durationSeconds;

  EpisodeProgress(this.positionSeconds, this.durationSeconds);

  bool get isCompleted =>
      durationSeconds > 0 && positionSeconds >= durationSeconds - 2;

  Map<String, dynamic> toJson() => {
    'positionSeconds': positionSeconds,
    'durationSeconds': durationSeconds,
  };

  factory EpisodeProgress.fromJson(Map<String, dynamic> json) {
    return EpisodeProgress(
      json['positionSeconds'] as int? ?? 0,
      json['durationSeconds'] as int? ?? 0,
    );
  }
}

class WatchProgress {
  final String animeSlug;
  final Anime anime;
  final int lastWatchedEpisode;
  final DateTime updatedAt;
  final Map<String, EpisodeProgress> episodes;

  WatchProgress({
    required this.animeSlug,
    required this.anime,
    required this.lastWatchedEpisode,
    required this.updatedAt,
    required this.episodes,
  });

  Map<String, dynamic> toJson() {
    return {
      'animeSlug': animeSlug,
      'anime': anime.toJson(),
      'lastWatchedEpisode': lastWatchedEpisode,
      'updatedAt': updatedAt.toIso8601String(),
      'episodes': episodes.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  factory WatchProgress.fromJson(Map<String, dynamic> json) {
    final epMap = json['episodes'] as Map<String, dynamic>?;
    Map<String, EpisodeProgress> parsedEpisodes = {};
    if (epMap != null) {
      epMap.forEach((key, value) {
        parsedEpisodes[key] = EpisodeProgress.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
      });
    } else {
      // Backwards compatibility for old format
      if (json['lastWatchedEpisode'] != null &&
          json['positionSeconds'] != null) {
        final epNum = json['lastWatchedEpisode'].toString();
        parsedEpisodes[epNum] = EpisodeProgress(
          json['positionSeconds'] as int,
          json['durationSeconds'] as int? ?? 0,
        );
      }
    }

    return WatchProgress(
      animeSlug: json['animeSlug'] as String,
      anime: Anime.fromJson(Map<String, dynamic>.from(json['anime'] as Map)),
      lastWatchedEpisode: json['lastWatchedEpisode'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      episodes: parsedEpisodes,
    );
  }
}

class LocalDbService {
  static const String _progressBoxName = 'watch_progress';
  static const String _myListBoxName = 'my_list';
  static const String _recentSearchesBoxName = 'recent_searches';
  static const String _artworkBoxName = 'artwork_metadata';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_progressBoxName);
    await Hive.openBox(_myListBoxName);
    await Hive.openBox<List<String>>(_recentSearchesBoxName);
    await Hive.openBox<String>(_artworkBoxName);
  }

  // --- Watch Progress ---

  static Future<void> saveProgress({
    required String animeSlug,
    Anime? anime,
    String? animeTitle,
    String? posterUrl,
    required int episodeNumber,
    required Duration position,
    required Duration duration,
    bool completed = false,
  }) async {
    if (duration <= Duration.zero) return;
    final box = Hive.box(_progressBoxName);

    // Retrieve existing progress or create new episodes map
    Map<String, EpisodeProgress> episodes = {};
    Anime? storedAnime;
    final existingData = box.get(animeSlug);
    if (existingData != null) {
      final existingProgress = WatchProgress.fromJson(
        jsonDecode(existingData as String),
      );
      episodes = Map.from(existingProgress.episodes);
      storedAnime = existingProgress.anime;
    }

    // Reinsert to retain the order in which episodes were last watched.
    episodes.remove(episodeNumber.toString());
    episodes[episodeNumber.toString()] = EpisodeProgress(
      completed
          ? duration.inSeconds
          : position.inSeconds.clamp(0, duration.inSeconds),
      duration.inSeconds,
    );

    final progress = WatchProgress(
      animeSlug: animeSlug,
      anime:
          anime ??
          storedAnime ??
          Anime(
            id: animeSlug,
            title: animeTitle ?? animeSlug,
            posterUrl: posterUrl,
            genre: '',
            year: 0,
          ),
      lastWatchedEpisode: episodeNumber,
      updatedAt: DateTime.now(),
      episodes: episodes,
    );
    await box.put(animeSlug, jsonEncode(progress.toJson()));
  }

  static WatchProgress? getProgress(String animeSlug) {
    final box = Hive.box(_progressBoxName);
    final data = box.get(animeSlug);
    if (data != null) {
      return _withCachedProgress(
        WatchProgress.fromJson(jsonDecode(data as String)),
      );
    }
    return null;
  }

  static List<WatchProgress> getAllProgress() {
    final box = Hive.box(_progressBoxName);
    final List<WatchProgress> list = [];
    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        list.add(
          _withCachedProgress(
            WatchProgress.fromJson(jsonDecode(data as String)),
          ),
        );
      }
    }
    // Sort by most recently updated
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  static Future<void> clearWatchHistory() async {
    await Hive.box(_progressBoxName).clear();
  }

  static Future<void> removeWatchHistory(
    String slug, {
    int? episodeNumber,
  }) async {
    final box = Hive.box(_progressBoxName);
    if (episodeNumber == null) {
      await box.delete(slug);
      return;
    }
    final progress = getProgress(slug);
    if (progress == null) return;
    final episodes = Map<String, EpisodeProgress>.from(progress.episodes)
      ..remove('$episodeNumber');
    if (episodes.isEmpty) {
      await box.delete(slug);
      return;
    }
    await box.put(
      slug,
      jsonEncode(
        WatchProgress(
          animeSlug: slug,
          anime: progress.anime,
          lastWatchedEpisode:
              episodes.containsKey('${progress.lastWatchedEpisode}')
              ? progress.lastWatchedEpisode
              : int.parse(episodes.keys.last),
          updatedAt: progress.updatedAt,
          episodes: episodes,
        ).toJson(),
      ),
    );
  }

  // --- My List ---

  static String _artworkKey(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static String? getCachedArtworkUrl(String title) {
    if (!Hive.isBoxOpen(_artworkBoxName)) return null;
    final url = Hive.box<String>(_artworkBoxName).get(_artworkKey(title));
    return url?.trim().isNotEmpty == true ? url : null;
  }

  static Future<void> cacheArtworkUrl(String title, String url) async {
    if (!Hive.isBoxOpen(_artworkBoxName) || url.trim().isEmpty) return;
    await Hive.box<String>(_artworkBoxName).put(_artworkKey(title), url.trim());
  }

  static Anime _withCachedArtwork(Anime anime) {
    final cachedUrl = getCachedArtworkUrl(anime.title);
    if (cachedUrl == null || cachedUrl == anime.posterUrl) return anime;
    return anime.copyWith(
      posterUrl: cachedUrl,
      posterPreviewUrl: anime.posterPreviewUrl ?? anime.posterUrl,
    );
  }

  static WatchProgress _withCachedProgress(WatchProgress progress) {
    final anime = _withCachedArtwork(progress.anime);
    if (identical(anime, progress.anime)) return progress;
    return WatchProgress(
      animeSlug: progress.animeSlug,
      anime: anime,
      lastWatchedEpisode: progress.lastWatchedEpisode,
      updatedAt: progress.updatedAt,
      episodes: progress.episodes,
    );
  }

  static Future<void> addToMyList(Anime anime) async {
    final box = Hive.box(_myListBoxName);
    await box.put(anime.id, jsonEncode(_withCachedArtwork(anime).toJson()));
  }

  static Future<void> updateMyListArtwork(Anime anime) async {
    final box = Hive.box(_myListBoxName);
    if (!box.containsKey(anime.id)) return;
    await box.put(anime.id, jsonEncode(anime.toJson()));
  }

  static Future<void> removeFromMyList(String animeSlug) async {
    final box = Hive.box(_myListBoxName);
    await box.delete(animeSlug);
  }

  static bool isInMyList(String animeSlug) {
    final box = Hive.box(_myListBoxName);
    return box.containsKey(animeSlug);
  }

  static List<Anime> getMyList() {
    final box = Hive.box(_myListBoxName);
    final List<Anime> list = [];
    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        list.add(
          _withCachedArtwork(Anime.fromJson(jsonDecode(data as String))),
        );
      }
    }
    return list.reversed.toList(); // Newest first
  }

  // --- Recent Searches ---

  static Future<void> saveSearchQuery(String query) async {
    final box = Hive.box<List<String>>(_recentSearchesBoxName);
    List<String> searches = List.from(
      box.get('queries', defaultValue: <String>[])!,
    );

    // Remove if already exists to move it to the top
    searches.remove(query);
    searches.insert(0, query);

    // Keep only the last 10 searches
    if (searches.length > 10) {
      searches = searches.sublist(0, 10);
    }

    await box.put('queries', searches);
  }

  static List<String> getRecentSearches() {
    final box = Hive.box<List<String>>(_recentSearchesBoxName);
    return box.get('queries', defaultValue: <String>[])!;
  }

  static Future<void> clearRecentSearches() async {
    final box = Hive.box<List<String>>(_recentSearchesBoxName);
    await box.put('queries', <String>[]);
  }

  static Future<void> removeSearchQuery(String query) async {
    final searches = List<String>.from(getRecentSearches())..remove(query);
    await Hive.box<List<String>>(
      _recentSearchesBoxName,
    ).put('queries', searches);
  }
}
