import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:luffytv/core/theme/app_theme.dart';
import 'package:luffytv/features/details/data/models/anime_detail.dart';
import 'package:luffytv/features/details/presentation/anime_details_screen.dart';
import 'package:luffytv/features/details/providers/details_providers.dart';
import 'package:luffytv/features/home/data/models/anime.dart';
import 'package:luffytv/features/home/data/models/episode.dart';
import 'package:luffytv/features/home/data/models/watch_data.dart';
import 'package:luffytv/features/home/data/repository/anime_repository.dart';
import 'package:luffytv/features/home/providers/anime_providers.dart';

class _Repository extends MockAnimeRepository {
  final warmed = <int>[];
  @override
  Future<WatchData> fetchWatchData(String slug, int episodeNumber,
      {bool forceRefresh = false, String? diagnosticId}) async {
    warmed.add(episodeNumber);
    return const WatchData(servers: [], sources: []);
  }
}

void main() {
  testWidgets('small-screen resume label updates after completion and preloads only target', (tester) async {
    final directory = (await tester.runAsync(() => Directory.systemTemp.createTemp('details_ui')))!;
    Hive.init(directory.path);
    await tester.runAsync(() async {
      await Hive.openBox('watch_progress');
      await Hive.openBox('my_list');
    });
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await Hive.close();
      await directory.delete(recursive: true);
    });
    const anime = Anime(id: 'test', title: 'Test anime', genre: '', year: 0);
    await tester.runAsync(() => LocalDbService.saveProgress(animeSlug: 'test', anime: anime,
        episodeNumber: 72, position: const Duration(minutes: 5), duration: const Duration(minutes: 24)));
    final repo = _Repository();
    await tester.pumpWidget(ProviderScope(overrides: [
      animeRepositoryProvider.overrideWithValue(repo),
      animeDetailProvider('test').overrideWith((ref) async => AnimeDetail.fromJson({'title': 'Test anime'})),
      animeEpisodesProvider('test').overrideWith((ref) async => [
        for (final number in [72, 73]) Episode(id: '$number', episodeNumber: number,
          title: 'Episode $number', durationMinutes: 24, description: ''),
      ]),
    ], child: MaterialApp(theme: AppTheme.dark, home: const AnimeDetailsScreen(anime: anime))));
    await tester.pumpAndSettle();
    expect(find.text('Continue watching ep 72'), findsOneWidget);
    expect(repo.warmed, [72]);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => LocalDbService.saveProgress(animeSlug: 'test', episodeNumber: 72,
        position: Duration.zero, duration: const Duration(minutes: 24), completed: true));
    await tester.pumpAndSettle();
    expect(find.text('Watch ep 73'), findsOneWidget);
    expect(repo.warmed, [72, 73]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
