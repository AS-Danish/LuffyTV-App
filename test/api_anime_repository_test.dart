import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luffytv/features/home/data/repository/api_anime_repository.dart';

http.Response jsonResponse(Object data) => http.Response(
  jsonEncode({'ok': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, Object> anime(String slug) => {
  'slug': slug,
  'title': slug,
  'year': 2026,
};

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=https://api.example');
  });

  test('all home consumers share one upstream request', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests += 1;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return jsonResponse({
        'spotlight': [anime('featured')],
        'newRelease': [anime('release')],
        'topDay': [anime('trending')],
        'latestEpisodes': [anime('latest')],
        'justCompleted': [anime('completed')],
        'topMonth': [anime('top')],
      });
    });
    final repository = ApiAnimeRepository(client: client);

    await Future.wait<Object>([
      repository.fetchFeatured(),
      repository.fetchEditorsPicks(),
      repository.fetchTrendingNow(),
      repository.fetchNewEpisodes(),
      repository.fetchRecentlyCompleted(),
      repository.fetchTopMonth(),
    ]);
    await repository.fetchTrendingNow();

    expect(requests, 1);
    client.close();
  });

  test('normalizes and coalesces identical searches', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests += 1;
      expect(request.url.path, '/api/search');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return jsonResponse({
        'results': [anime('one-piece')],
      });
    });
    final repository = ApiAnimeRepository(client: client);

    final results = await Future.wait([
      repository.searchAnime(' One Piece '),
      repository.searchAnime('one piece'),
    ]);

    expect(requests, 1);
    expect(results.every((items) => items.single.id == 'one-piece'), isTrue);
    client.close();
  });

  test('coalesces watch resolution for the same episode', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests += 1;
      expect(request.url.queryParameters['stream'], 'false');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return jsonResponse({
        'servers': [
          {'id': 'one', 'name': 'Server', 'type': 'sub'},
        ],
        'sources': [
          {
            'server': 'Server',
            'type': 'sub',
            'url': 'https://video.example/episode.m3u8',
            'm3u8': 'https://video.example/episode.m3u8',
            'tracks': <Object>[],
          },
        ],
      });
    });
    final repository = ApiAnimeRepository(client: client);

    final results = await Future.wait([
      repository.fetchWatchData('one-piece', 1),
      repository.fetchWatchData('one-piece', 1),
    ]);

    expect(requests, 1);
    expect(results.every((result) => result.sources.length == 1), isTrue);
    client.close();
  });
}
