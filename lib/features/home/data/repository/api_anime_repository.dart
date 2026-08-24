import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:luffytv/core/utils/api_constants.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/home/data/models/episode.dart';
import 'package:luffytv/features/home/data/repository/anime_repository.dart';
import 'package:luffytv/features/details/data/models/anime_detail.dart';
import 'package:luffytv/features/home/data/models/watch_data.dart';

class _MemoryCacheEntry {
  final Object value;
  final DateTime freshUntil;
  final DateTime staleUntil;

  const _MemoryCacheEntry({
    required this.value,
    required this.freshUntil,
    required this.staleUntil,
  });
}

class _ArtworkCacheEntry {
  final String? url;
  final DateTime expiresAt;

  const _ArtworkCacheEntry({required this.url, required this.expiresAt});
}

class ApiAnimeRepository implements AnimeRepository {
  final http.Client client;
  final Map<String, _MemoryCacheEntry> _memoryCache = {};
  final Map<String, Future<dynamic>> _inFlight = {};
  final Map<String, _ArtworkCacheEntry> _artworkCache = {};
  Future<void>? _artworkHydration;
  DateTime? _blockedUntil;

  static const _maximumCacheEntries = 160;
  static const _requestTimeout = Duration(seconds: 12);
  static const _artworkRequestTimeout = Duration(seconds: 4);
  static const _artworkCacheDuration = Duration(hours: 12);
  static const _negativeArtworkCacheDuration = Duration(minutes: 15);
  static final _anilistUri = Uri.parse('https://graphql.anilist.co');

  ApiAnimeRepository({required this.client});

  Future<T> _cached<T>({
    required String key,
    required Duration freshFor,
    required Duration staleFor,
    required Future<T> Function() load,
    bool Function(T value)? shouldCache,
  }) async {
    final now = DateTime.now();
    final cached = _memoryCache[key];
    if (cached != null && cached.freshUntil.isAfter(now)) {
      _memoryCache.remove(key);
      _memoryCache[key] = cached;
      return cached.value as T;
    }

    final existing = _inFlight[key];
    if (existing != null) {
      return cached != null && cached.staleUntil.isAfter(now)
          ? cached.value as T
          : (await existing) as T;
    }

    late final Future<T> request;
    request = load()
        .then((value) {
          if (shouldCache?.call(value) ?? true) {
            final loadedAt = DateTime.now();
            _memoryCache.remove(key);
            _memoryCache[key] = _MemoryCacheEntry(
              value: value as Object,
              freshUntil: loadedAt.add(freshFor),
              staleUntil: loadedAt.add(staleFor),
            );
            while (_memoryCache.length > _maximumCacheEntries) {
              _memoryCache.remove(_memoryCache.keys.first);
            }
          }
          return value;
        })
        .whenComplete(() {
          if (identical(_inFlight[key], request)) _inFlight.remove(key);
        });
    _inFlight[key] = request;

    if (cached != null && cached.staleUntil.isAfter(now)) {
      unawaited(request.then<void>((_) {}, onError: (_) {}));
      return cached.value as T;
    }
    return request;
  }

  Duration _retryAfter(http.Response response) {
    final raw = response.headers['retry-after'];
    final seconds = int.tryParse(raw ?? '');
    if (seconds != null) {
      return Duration(seconds: seconds.clamp(1, 120));
    }
    final date = raw == null ? null : DateTime.tryParse(raw);
    if (date == null) return const Duration(seconds: 30);
    final delay = date.difference(DateTime.now().toUtc()).inSeconds;
    return Duration(seconds: delay.clamp(1, 120));
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    if (_blockedUntil?.isAfter(DateTime.now()) == true) {
      throw Exception('Anime service is cooling down after rate limiting.');
    }
    final response = await client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(_requestTimeout);
    if (response.statusCode == 429) {
      _blockedUntil = DateTime.now().add(_retryAfter(response));
      throw Exception('Anime service rate limit reached.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode >= 500) {
        _blockedUntil = DateTime.now().add(const Duration(seconds: 10));
      }
      throw Exception('Anime service request failed (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Anime service returned an invalid response.');
    }
    _blockedUntil = null;
    return decoded;
  }

  String _artworkKey(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  bool _needsArtworkUpgrade(Anime anime) {
    final url = anime.posterUrl?.toLowerCase() ?? '';
    return url.contains('/thumbnail/') || url.contains('picsum.photos');
  }

  Future<void> _fetchArtworkChunk(List<Anime> anime) async {
    final fields = anime.indexed
        .map((entry) {
          final (index, item) = entry;
          return '''
        a$index: Media(search: ${jsonEncode(item.title)}, type: ANIME) {
          coverImage { extraLarge large }
        }
      ''';
        })
        .join('\n');

    final response = await client
        .post(
          _anilistUri,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'query': 'query LuffyArtwork { $fields }'}),
        )
        .timeout(_artworkRequestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Artwork request failed (${response.statusCode}).');
    }

    final payload = jsonDecode(response.body);
    final data = payload is Map<String, dynamic>
        ? payload['data'] as Map<String, dynamic>?
        : null;
    final now = DateTime.now();
    final persistenceWrites = <Future<void>>[];
    for (final entry in anime.indexed) {
      final (index, item) = entry;
      final media = data?['a$index'];
      final cover = media is Map<String, dynamic>
          ? media['coverImage'] as Map<String, dynamic>?
          : null;
      final extraLarge = cover?['extraLarge']?.toString().trim();
      final large = cover?['large']?.toString().trim();
      final resolved = extraLarge?.isNotEmpty == true
          ? extraLarge
          : (large?.isNotEmpty == true ? large : null);
      _artworkCache[_artworkKey(item.title)] = _ArtworkCacheEntry(
        url: resolved,
        expiresAt: now.add(
          resolved == null
              ? _negativeArtworkCacheDuration
              : _artworkCacheDuration,
        ),
      );
      if (resolved != null) {
        persistenceWrites.add(
          LocalDbService.cacheArtworkUrl(item.title, resolved),
        );
      }
    }
    await Future.wait(persistenceWrites);
  }

  Future<void> _hydrateArtwork(List<Anime> anime) async {
    const chunkSize = 8;
    final chunks = <List<Anime>>[];
    for (var index = 0; index < anime.length; index += chunkSize) {
      chunks.add(
        anime.sublist(index, (index + chunkSize).clamp(0, anime.length)),
      );
    }

    var cursor = 0;
    Future<void> worker() async {
      while (cursor < chunks.length) {
        final chunk = chunks[cursor++];
        try {
          await _fetchArtworkChunk(chunk);
        } catch (_) {
          final expiresAt = DateTime.now().add(_negativeArtworkCacheDuration);
          for (final item in chunk) {
            _artworkCache[_artworkKey(item.title)] = _ArtworkCacheEntry(
              url: null,
              expiresAt: expiresAt,
            );
          }
        }
      }
    }

    await Future.wait(
      List.generate(chunks.length.clamp(0, 2), (_) => worker()),
    );
  }

  @override
  Future<List<Anime>> upgradeArtwork(List<Anime> anime) async {
    if (anime.isEmpty) return anime;
    final candidates = <String, Anime>{
      for (final item in anime.where(_needsArtworkUpgrade))
        _artworkKey(item.title): item,
    };
    if (candidates.isEmpty) return anime;

    final persistedUntil = DateTime.now().add(_artworkCacheDuration);
    for (final entry in candidates.entries) {
      final persisted = LocalDbService.getCachedArtworkUrl(entry.value.title);
      if (persisted != null) {
        _artworkCache[entry.key] = _ArtworkCacheEntry(
          url: persisted,
          expiresAt: persistedUntil,
        );
      }
    }

    while (true) {
      final now = DateTime.now();
      final missing = candidates.entries
          .where((entry) {
            final cached = _artworkCache[entry.key];
            return cached == null || !cached.expiresAt.isAfter(now);
          })
          .map((entry) => entry.value)
          .toList();
      if (missing.isEmpty) break;
      final activeHydration = _artworkHydration;
      if (activeHydration != null) {
        await activeHydration;
        continue;
      }
      final hydration = _hydrateArtwork(missing);
      _artworkHydration = hydration;
      try {
        await hydration;
      } finally {
        if (identical(_artworkHydration, hydration)) {
          _artworkHydration = null;
        }
      }
    }

    return anime.map((item) {
      if (!_needsArtworkUpgrade(item)) return item;
      final upgraded = _artworkCache[_artworkKey(item.title)]?.url;
      if (upgraded == null || upgraded.isEmpty) return item;
      return item.copyWith(
        posterUrl: upgraded,
        posterPreviewUrl: item.posterUrl,
      );
    }).toList();
  }

  Future<Map<String, dynamic>> _fetchHomeData() => _cached(
    key: 'home',
    freshFor: const Duration(minutes: 5),
    staleFor: const Duration(hours: 6),
    load: _doFetchHomeData,
  );

  Future<Map<String, dynamic>> _doFetchHomeData() async {
    final response = await _getJson(
      Uri.parse('${ApiConstants.baseUrl}/api/home'),
    );
    if (response['ok'] == true && response['data'] is Map<String, dynamic>) {
      return response['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to load anime data');
  }

  @override
  Future<Anime> fetchFeatured() async {
    final data = await _fetchHomeData();
    final spotlight = data['spotlight'] as List<dynamic>? ?? [];
    if (spotlight.isNotEmpty) {
      final featured = Anime.fromJson(spotlight.first as Map<String, dynamic>);
      return (await upgradeArtwork([featured])).first;
    }
    throw Exception('No featured anime found');
  }

  @override
  Future<List<Anime>> fetchEditorsPicks() async {
    final data = await _fetchHomeData();
    final newRelease = data['newRelease'] as List<dynamic>? ?? [];
    return upgradeArtwork(
      newRelease.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  @override
  Future<List<Anime>> fetchTrendingNow() async {
    final data = await _fetchHomeData();
    final topDay = data['topDay'] as List<dynamic>? ?? [];
    return upgradeArtwork(
      topDay.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  @override
  Future<List<Anime>> fetchNewEpisodes() async {
    final data = await _fetchHomeData();
    final latestEpisodes = data['latestEpisodes'] as List<dynamic>? ?? [];
    return upgradeArtwork(
      latestEpisodes
          .map((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<List<Anime>> fetchRecentlyCompleted() async {
    final data = await _fetchHomeData();
    final justCompleted = data['justCompleted'] as List<dynamic>? ?? [];
    return upgradeArtwork(
      justCompleted
          .map((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<List<Anime>> fetchTopMonth() async {
    final data = await _fetchHomeData();
    final topMonth = data['topMonth'] as List<dynamic>? ?? [];
    return upgradeArtwork(
      topMonth.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  @override
  Future<AnimeDetail> fetchAnimeDetails(String slug) => _cached(
    key: 'detail:${slug.toLowerCase()}',
    freshFor: const Duration(minutes: 30),
    staleFor: const Duration(hours: 12),
    load: () async {
      final encodedSlug = Uri.encodeComponent(slug);
      final response = await _getJson(
        Uri.parse('${ApiConstants.baseUrl}/api/anime/$encodedSlug'),
      );
      if (response['ok'] == true && response['data'] is Map<String, dynamic>) {
        return AnimeDetail.fromJson(response['data'] as Map<String, dynamic>);
      }
      throw Exception('API returned ok: false');
    },
  );

  @override
  Future<List<Episode>> fetchAnimeEpisodes(String slug) => _cached(
    key: 'episodes:${slug.toLowerCase()}',
    freshFor: const Duration(minutes: 10),
    staleFor: const Duration(hours: 3),
    load: () async {
      final encodedSlug = Uri.encodeComponent(slug);
      final response = await _getJson(
        Uri.parse('${ApiConstants.baseUrl}/api/anime/$encodedSlug/episodes'),
      );
      final data = response['data'];
      if (response['ok'] == true && data is Map<String, dynamic>) {
        final episodes = data['episodes'];
        if (episodes is List) {
          return episodes
              .whereType<Map<String, dynamic>>()
              .map(Episode.fromJson)
              .toList();
        }
      }
      return [];
    },
  );

  @override
  Future<List<Anime>> searchAnime(String keyword) async {
    final normalized = keyword.trim();
    if (normalized.length < 2) return [];
    final bounded = normalized.length > 80
        ? normalized.substring(0, 80)
        : normalized;
    return _cached(
      key: 'search:${bounded.toLowerCase()}',
      freshFor: const Duration(minutes: 5),
      staleFor: const Duration(hours: 1),
      load: () async {
        final uri = Uri.parse(
          '${ApiConstants.baseUrl}/api/search',
        ).replace(queryParameters: {'keyword': bounded});
        final response = await _getJson(uri);
        final data = response['data'];
        if (response['ok'] == true && data is Map<String, dynamic>) {
          final results = data['results'];
          if (results is List) {
            return upgradeArtwork(
              results
                  .whereType<Map<String, dynamic>>()
                  .map(Anime.fromJson)
                  .toList(),
            );
          }
        }
        return [];
      },
    );
  }

  @override
  Future<WatchData> fetchWatchData(
    String slug,
    int episodeNumber, {
    bool forceRefresh = false,
  }) {
    final key = 'watch:${slug.toLowerCase()}:$episodeNumber';
    if (forceRefresh) _memoryCache.remove(key);
    return _cached(
      key: key,
      freshFor: const Duration(seconds: 45),
      staleFor: const Duration(minutes: 3),
      load: () async {
        final encodedSlug = Uri.encodeComponent(slug);
        final uri = Uri.parse(
          '${ApiConstants.baseUrl}/api/watch/$encodedSlug',
        ).replace(queryParameters: {'ep': '$episodeNumber', 'stream': 'false'});
        final response = await _getJson(uri);
        if (response['ok'] == true &&
            response['data'] is Map<String, dynamic>) {
          return WatchData.fromJson(response['data'] as Map<String, dynamic>);
        }
        throw Exception('API returned ok: false');
      },
      shouldCache: (data) => data.sources.any((source) => source.isPlayable),
    );
  }
}
