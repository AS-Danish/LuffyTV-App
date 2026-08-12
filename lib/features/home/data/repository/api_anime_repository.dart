import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:luffytv/core/utils/api_constants.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/home/data/models/episode.dart';
import 'package:luffytv/features/home/data/repository/anime_repository.dart';
import 'package:luffytv/features/details/data/models/anime_detail.dart';
import 'package:luffytv/features/home/data/models/watch_data.dart';
import 'package:luffytv/core/services/cache_manager.dart';

class ApiAnimeRepository implements AnimeRepository {
  final http.Client client;
  final CacheManager? cacheManager;

  ApiAnimeRepository({required this.client, this.cacheManager});

  Future<Map<String, dynamic>>? _homeDataFuture;

  Future<Map<String, dynamic>> _fetchHomeData() {
    if (_homeDataFuture != null) {
      return _homeDataFuture!;
    }
    
    _homeDataFuture = _doFetchHomeData().catchError((e) {
      _homeDataFuture = null;
      throw e;
    });
    
    return _homeDataFuture!;
  }

  Future<Map<String, dynamic>> _doFetchHomeData() async {
    const cacheKey = 'home_data';
    if (cacheManager != null) {
      final cached = await cacheManager!.get(cacheKey);
      if (cached != null) return cached;
    }

    final response = await client.get(Uri.parse('${ApiConstants.baseUrl}/api/home')).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['ok'] == true && jsonResponse['data'] != null) {
        final data = jsonResponse['data'] as Map<String, dynamic>;
        if (cacheManager != null) {
          await cacheManager!.set(cacheKey, data);
        }
        return data;
      }
    }
    throw Exception('Failed to load anime data');
  }

  @override
  Future<Anime> fetchFeatured() async {
    final data = await _fetchHomeData();
    final spotlight = data['spotlight'] as List<dynamic>? ?? [];
    if (spotlight.isNotEmpty) {
      return Anime.fromJson(spotlight.first as Map<String, dynamic>);
    }
    throw Exception('No featured anime found');
  }

  @override
  Future<List<Anime>> fetchEditorsPicks() async {
    final data = await _fetchHomeData();
    final newRelease = data['newRelease'] as List<dynamic>? ?? [];
    return newRelease.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Anime>> fetchTrendingNow() async {
    final data = await _fetchHomeData();
    final topDay = data['topDay'] as List<dynamic>? ?? [];
    return topDay.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Anime>> fetchNewEpisodes() async {
    final data = await _fetchHomeData();
    final latestEpisodes = data['latestEpisodes'] as List<dynamic>? ?? [];
    return latestEpisodes.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Anime>> fetchRecentlyCompleted() async {
    final data = await _fetchHomeData();
    final justCompleted = data['justCompleted'] as List<dynamic>? ?? [];
    return justCompleted.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Anime>> fetchTopMonth() async {
    final data = await _fetchHomeData();
    final topMonth = data['topMonth'] as List<dynamic>? ?? [];
    return topMonth.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<AnimeDetail> fetchAnimeDetails(String slug) async {
    final cacheKey = 'details_$slug';
    if (cacheManager != null) {
      final cached = await cacheManager!.get(cacheKey);
      if (cached != null) return AnimeDetail.fromJson(cached);
    }

    final response = await client.get(Uri.parse('${ApiConstants.baseUrl}/api/anime/$slug'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['ok'] == true && json['data'] != null) {
        if (cacheManager != null) {
          await cacheManager!.set(cacheKey, json['data']);
        }
        return AnimeDetail.fromJson(json['data']);
      }
      throw Exception('API returned ok: false');
    }
    throw Exception('Failed to load anime details');
  }

  @override
  Future<List<Episode>> fetchAnimeEpisodes(String slug) async {
    final cacheKey = 'episodes_$slug';
    if (cacheManager != null) {
      final cached = await cacheManager!.get(cacheKey);
      if (cached != null && cached['episodes'] != null) {
        final List<dynamic> epsList = cached['episodes'];
        return epsList.map((e) => Episode.fromJson(e)).toList();
      }
    }

    final response = await client.get(Uri.parse('${ApiConstants.baseUrl}/api/anime/$slug/episodes'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['ok'] == true && json['data'] != null && json['data']['episodes'] != null) {
        if (cacheManager != null) {
          await cacheManager!.set(cacheKey, {'episodes': json['data']['episodes']});
        }
        final List<dynamic> epsList = json['data']['episodes'];
        return epsList.map((e) => Episode.fromJson(e)).toList();
      }
      return [];
    }
    throw Exception('Failed to load episodes');
  }

  @override
  Future<List<Anime>> searchAnime(String keyword) async {
    final encodedKeyword = Uri.encodeComponent(keyword);
    final response = await client.get(Uri.parse('${ApiConstants.baseUrl}/api/search?keyword=$encodedKeyword'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['ok'] == true && json['data'] != null && json['data']['results'] != null) {
        final List<dynamic> resultsList = json['data']['results'];
        return resultsList.map((e) => Anime.fromJson(e)).toList();
      }
      return [];
    }
    throw Exception('Failed to search anime');
  }

  @override
  Future<WatchData> fetchWatchData(String slug, int episodeNumber) async {
    final response = await client.get(Uri.parse('${ApiConstants.baseUrl}/api/watch/$slug?ep=$episodeNumber&stream=false'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['ok'] == true && json['data'] != null) {
        return WatchData.fromJson(json['data']);
      }
      throw Exception('API returned ok: false');
    }
    throw Exception('Failed to load watch data');
  }
}
