import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:luffytv/features/home/data/models/anime.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('offline_progress_test');
    Hive.init(directory.path);
    await Hive.openBox('watch_progress');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'remove one episode, one anime, and all search history independently',
    () async {
      for (final number in [71, 72]) {
        await LocalDbService.saveProgress(
          animeSlug: 'example',
          episodeNumber: number,
          position: const Duration(seconds: 50),
          duration: const Duration(minutes: 24),
        );
      }
      await LocalDbService.removeWatchHistory('example', episodeNumber: 72);
      expect(LocalDbService.getProgress('example')!.lastWatchedEpisode, 71);
      expect(LocalDbService.getProgress('example')!.episodes.keys, ['71']);
      await LocalDbService.removeWatchHistory('example');
      expect(LocalDbService.getAllProgress(), isEmpty);
      await Hive.openBox<List<String>>('recent_searches');
      await LocalDbService.saveSearchQuery('One Piece');
      await LocalDbService.saveSearchQuery('Naruto');
      await LocalDbService.removeSearchQuery('Naruto');
      expect(LocalDbService.getRecentSearches(), ['One Piece']);
      await LocalDbService.clearRecentSearches();
      expect(LocalDbService.getRecentSearches(), isEmpty);
    },
  );

  test(
    'offline progress without an Anime survives reopening storage',
    () async {
      await LocalDbService.saveProgress(
        animeSlug: 'example',
        animeTitle: 'Example',
        posterUrl: 'poster.jpg',
        episodeNumber: 1,
        position: const Duration(minutes: 7),
        duration: const Duration(minutes: 24),
      );
      await Hive.box('watch_progress').close();
      await Hive.openBox('watch_progress');
      final saved = LocalDbService.getProgress('example')!;
      expect(saved.anime.title, 'Example');
      expect(saved.anime.posterUrl, 'poster.jpg');
      expect(saved.episodes['1']!.positionSeconds, 420);
    },
  );

  test(
    'offline completion stores full duration even when position resets',
    () async {
      await LocalDbService.saveProgress(
        animeSlug: 'example',
        animeTitle: 'Example',
        episodeNumber: 1,
        position: Duration.zero,
        duration: const Duration(minutes: 24),
        completed: true,
      );
      await Hive.box('watch_progress').close();
      await Hive.openBox('watch_progress');
      final episode = LocalDbService.getProgress('example')!.episodes['1']!;
      expect(episode.positionSeconds, 1440);
      expect(episode.durationSeconds, 1440);
    },
  );

  test('offline updates retain rich metadata and other episodes', () async {
    const anime = Anime(
      id: 'example',
      title: 'Example',
      genre: 'Action',
      year: 2026,
    );
    await LocalDbService.saveProgress(
      animeSlug: 'example',
      anime: anime,
      episodeNumber: 1,
      position: const Duration(minutes: 24),
      duration: const Duration(minutes: 24),
    );
    await LocalDbService.saveProgress(
      animeSlug: 'example',
      animeTitle: 'Offline title',
      episodeNumber: 2,
      position: const Duration(minutes: 3),
      duration: const Duration(minutes: 24),
    );
    // An uninitialized/stopped player must not erase the stored position.
    await LocalDbService.saveProgress(
      animeSlug: 'example',
      episodeNumber: 2,
      position: Duration.zero,
      duration: Duration.zero,
    );
    final saved = LocalDbService.getProgress('example')!;
    expect(saved.anime.genre, 'Action');
    expect(saved.anime.year, 2026);
    expect(saved.episodes['1']!.positionSeconds, 1440);
    expect(saved.episodes['2']!.positionSeconds, 180);
    expect(saved.lastWatchedEpisode, 2);
  });
}
