import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luffytv/core/services/catalog_cache.dart';
import 'package:luffytv/features/home/data/repository/api_anime_repository.dart';

void main() {
  late Directory directory;
  late Box<String> box;
  final uri = Uri.parse('https://api.example/api/home');
  var now = DateTime(2026, 9, 8);
  Map<String, dynamic> payload(String title) => {
    'ok': true,
    'data': {
      'topDay': [
        {'slug': title, 'title': title, 'year': 2026},
      ],
    },
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('luffytv-catalog-test-');
    Hive.init(directory.path);
    box = await Hive.openBox<String>(CatalogCache.boxName);
    now = DateTime(2026, 9, 8);
    dotenv.loadFromString(envString: 'API_BASE_URL=https://api.example');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'reopening disk and repository serves fresh home without HTTP',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(jsonEncode(payload('saved')), 200);
      });
      final repo = ApiAnimeRepository(client: client);
      expect((await repo.fetchTrendingNow()).single.title, 'saved');
      await box.close();
      box = await Hive.openBox<String>(CatalogCache.boxName);
      final restarted = ApiAnimeRepository(client: client);
      expect((await restarted.fetchTrendingNow()).single.title, 'saved');
      expect(calls, 1);
      expect(CatalogCache().hasUsableHome(uri), isTrue);
      client.close();
    },
  );

  test(
    'stale home displays immediately, coalesces refresh and notifies when changed',
    () async {
      final cache = CatalogCache(box: box, now: () => now);
      await cache.get(uri, () async => payload('old'));
      now = now.add(const Duration(minutes: 6));
      final response = Completer<Map<String, dynamic>>();
      var calls = 0;
      final updated = Completer<void>();
      Future<Map<String, dynamic>> load() {
        calls++;
        return response.future;
      }

      expect(
        (await cache.get(
          uri,
          load,
          onUpdated: () => updated.complete(),
        ))['data'],
        payload('old')['data'],
      );
      await cache.get(uri, load);
      expect(calls, 1);
      response.complete(payload('new'));
      await updated.future;
      expect((await cache.get(uri, load))['data'], payload('new')['data']);
      expect(calls, 1);
    },
  );

  test(
    'offline refresh preserves cached catalog; ancient entries require network',
    () async {
      final cache = CatalogCache(box: box, now: () => now);
      await cache.get(uri, () async => payload('saved'));
      now = now.add(const Duration(days: 1));
      Future<Map<String, dynamic>> offline() async =>
          throw const SocketException('offline');
      expect((await cache.get(uri, offline))['ok'], true);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(days: 7));
      await expectLater(
        cache.get(uri, offline),
        throwsA(isA<SocketException>()),
      );
    },
  );

  test(
    'watch responses never persist or reuse signed links across calls',
    () async {
      final cache = CatalogCache(box: box);
      final watch = Uri.parse('https://api.example/api/watch/show?ep=1');
      var calls = 0;
      Future<Map<String, dynamic>> load() async {
        calls++;
        return payload('link');
      }

      await cache.get(watch, load);
      await cache.get(watch, load);
      expect(calls, 2);
      expect(box.isEmpty, true);
    },
  );

  test('manual home refresh bypasses fresh disk and memory caches', () async {
    var calls = 0;
    final client = MockClient(
      (_) async => http.Response(jsonEncode(payload('title-${++calls}')), 200),
    );
    final repo = ApiAnimeRepository(client: client);
    expect((await repo.fetchTrendingNow()).single.title, 'title-1');
    await repo.refreshHome();
    expect((await repo.fetchTrendingNow()).single.title, 'title-2');
    expect(calls, 2);
    client.close();
  });

  test(
    'corrupt cache and unsuccessful JSON never poison later requests',
    () async {
      await box.put(uri.toString(), 'invalid json');
      final cache = CatalogCache(box: box);
      await expectLater(
        cache.get(uri, () async => {'ok': false}),
        throwsException,
      );
      expect((await cache.get(uri, () async => payload('fixed')))['ok'], true);
    },
  );
}
