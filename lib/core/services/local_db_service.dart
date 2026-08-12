import 'package:hive_flutter/hive_flutter.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'dart:convert';

class EpisodeProgress {
  final int positionSeconds;
  final int durationSeconds;

  EpisodeProgress(this.positionSeconds, this.durationSeconds);

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
        parsedEpisodes[key] = EpisodeProgress.fromJson(Map<String, dynamic>.from(value as Map));
      });
    } else {
      // Backwards compatibility for old format
      if (json['lastWatchedEpisode'] != null && json['positionSeconds'] != null) {
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

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_progressBoxName);
    await Hive.openBox(_myListBoxName);
    await Hive.openBox<List<String>>(_recentSearchesBoxName);
  }

  // --- Watch Progress ---

  static Future<void> saveProgress({
    required String animeSlug,
    required Anime anime,
    required int episodeNumber,
    required Duration position,
    required Duration duration,
  }) async {
    final box = Hive.box(_progressBoxName);
    
    // Retrieve existing progress or create new episodes map
    Map<String, EpisodeProgress> episodes = {};
    final existingData = box.get(animeSlug);
    if (existingData != null) {
      final existingProgress = WatchProgress.fromJson(jsonDecode(existingData as String));
      episodes = Map.from(existingProgress.episodes);
    }

    // Update the specific episode
    episodes[episodeNumber.toString()] = EpisodeProgress(position.inSeconds, duration.inSeconds);

    final progress = WatchProgress(
      animeSlug: animeSlug,
      anime: anime,
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
      return WatchProgress.fromJson(jsonDecode(data as String));
    }
    return null;
  }

  static List<WatchProgress> getAllProgress() {
    final box = Hive.box(_progressBoxName);
    final List<WatchProgress> list = [];
    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        list.add(WatchProgress.fromJson(jsonDecode(data as String)));
      }
    }
    // Sort by most recently updated
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  // --- My List ---

  static Future<void> addToMyList(Anime anime) async {
    final box = Hive.box(_myListBoxName);
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
        list.add(Anime.fromJson(jsonDecode(data as String)));
      }
    }
    return list.reversed.toList(); // Newest first
  }

  // --- Recent Searches ---

  static Future<void> saveSearchQuery(String query) async {
    final box = Hive.box<List<String>>(_recentSearchesBoxName);
    List<String> searches = List.from(box.get('queries', defaultValue: <String>[])!);
    
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
}
