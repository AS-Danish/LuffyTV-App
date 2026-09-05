import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luffytv/features/home/data/repository/api_anime_repository.dart';
import 'package:luffytv/features/home/data/models/watch_data.dart';
import 'package:luffytv/core/services/download_source_recovery.dart';

http.Response response(String token) => http.Response(
  jsonEncode({
    'ok': true,
    'data': {
      'sources': [
        {
          'server': 'HD',
          'type': 'sub',
          'm3u8': 'https://media.example/$token.m3u8',
          'url': 'https://embed.example/1',
        },
      ],
    },
  }),
  200,
  headers: {'content-type': 'application/json'},
);

VideoSource source(String id, {String type = 'sub', String? language}) =>
    VideoSource(
      server: id,
      type: type,
      url: 'https://embed.example/1',
      m3u8: 'https://media.example/$id.m3u8',
      tracks: [],
      language: language,
    );
WatchData watch(List<VideoSource> sources) =>
    WatchData(servers: [], sources: sources);

void main() {
  setUpAll(
    () => dotenv.loadFromString(envString: 'API_BASE_URL=https://api.example'),
  );

  test(
    'force refresh requests server recovery without an admin secret',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return response(
          request.url.queryParameters['recover'] == '1' ? 'fresh' : 'old',
        );
      });
      final repo = ApiAnimeRepository(client: client);
      await repo.fetchWatchData('example', 1);
      final fresh = await repo.fetchWatchData('example', 1, forceRefresh: true);
      expect(requests.last.url.queryParameters['recover'], '1');
      expect(requests.last.headers.containsKey('x-cache-refresh-token'), false);
      expect(fresh.sources.single.m3u8, contains('fresh'));
      expect(
        (await repo.fetchWatchData('example', 1)).sources.single.m3u8,
        contains('fresh'),
      );
      expect(requests.length, 2);
      client.close();
    },
  );

  test('an in-flight old response cannot replace recovered links', () async {
    final old = Completer<http.Response>();
    var calls = 0;
    final client = MockClient((request) {
      calls++;
      return request.url.queryParameters['recover'] == '1'
          ? Future.value(response('fresh'))
          : old.future;
    });
    final repo = ApiAnimeRepository(client: client);
    final initial = repo.fetchWatchData('example', 1);
    final fresh = await repo.fetchWatchData('example', 1, forceRefresh: true);
    old.complete(response('old'));
    await initial;
    expect(
      (await repo.fetchWatchData('example', 1)).sources.single.m3u8,
      fresh.sources.single.m3u8,
    );
    expect(calls, 2);
    client.close();
  });

  test('simultaneous recovery requests share one HTTP request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return response('fresh');
    });
    final repo = ApiAnimeRepository(client: client);
    await Future.wait(
      List.generate(
        5,
        (_) => repo.fetchWatchData('example', 1, forceRefresh: true),
      ),
    );
    expect(calls, 1);
    client.close();
  });

  test(
    'failed recovery is surfaced, not replaced with a cached stream',
    () async {
      final client = MockClient(
        (request) async => request.url.queryParameters['recover'] == '1'
            ? http.Response('unavailable', 503)
            : response('old'),
      );
      final repo = ApiAnimeRepository(client: client);
      await repo.fetchWatchData('example', 1);
      await expectLater(
        repo.fetchWatchData('example', 1, forceRefresh: true),
        throwsException,
      );
      client.close();
    },
  );

  test('download failure refreshes once and uses the renewed source', () async {
    final expired = source('expired');
    final fresh = source('fresh');
    var refreshes = 0;
    final attempted = <String>[];
    final result = await prepareDownloadSource(
      selected: expired,
      initial: watch([expired, expired]),
      refresh: () async {
        refreshes++;
        return watch([fresh]);
      },
      loadPlaylist: (s) async {
        attempted.add(s.server);
        if (s.server == 'expired') throw Exception('HTTP 403');
        return '#EXTM3U\n#EXTINF:5,\nfirst.ts';
      },
    );
    expect(result.source, fresh);
    expect(refreshes, 1);
    expect(attempted, ['expired', 'fresh']);
  });

  test(
    'all blocked sources terminate after two rounds and never change audio',
    () async {
      final sub = source('blocked');
      final dub = source('working', type: 'dub');
      var calls = 0;
      var refreshes = 0;
      await expectLater(
        prepareDownloadSource(
          selected: sub,
          initial: watch([sub, dub]),
          refresh: () async {
            refreshes++;
            return watch([sub, dub]);
          },
          loadPlaylist: (s) async {
            calls++;
            expect(s.type, 'sub');
            return '<html>Blocked</html>';
          },
        ),
        throwsException,
      );
      expect(refreshes, 1);
      expect(calls, 2);
    },
  );

  test('a healthy selected source does not trigger recovery', () async {
    final healthy = source('healthy');
    final result = await prepareDownloadSource(
      selected: healthy,
      initial: watch([healthy]),
      refresh: () async => throw StateError('must not refresh'),
      loadPlaylist: (_) async => '#EXTM3U\n#EXTINF:5,\nfirst.ts',
    );
    expect(result.source, healthy);
  });
}
