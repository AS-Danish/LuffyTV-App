import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luffytv/core/services/catalog_revision_provider.dart';
import '../data/repository/anime_repository.dart';
import '../data/models/anime.dart';

import 'package:http/http.dart' as http;
import '../data/repository/api_anime_repository.dart';

/// Swap MockAnimeRepository() for a real implementation here — this is
/// the single line the rest of the app depends on.
final animeRepositoryProvider = Provider<AnimeRepository>((ref) {
  final client = http.Client();
  ref.onDispose(() => client.close());
  return ApiAnimeRepository(
    client: client,
    onCatalogUpdated: () {
      if (ref.mounted) ref.read(catalogRevisionProvider.notifier).changed();
    },
  );
});

/// FutureProvider handles loading/error/data states automatically —
/// screens consume this via AsyncValue and get a switch-case-free
/// .when(loading:, error:, data:) instead of manual bool flags.
final featuredAnimeProvider = FutureProvider<Anime>((ref) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(animeRepositoryProvider).fetchFeatured();
});

final editorsPicksProvider = FutureProvider<List<Anime>>((ref) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(animeRepositoryProvider).fetchEditorsPicks();
});

final trendingNowProvider = FutureProvider<List<Anime>>((ref) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(animeRepositoryProvider).fetchTrendingNow();
});

final newEpisodesProvider = FutureProvider<List<Anime>>((ref) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(animeRepositoryProvider).fetchNewEpisodes();
});

final recentlyCompletedProvider = FutureProvider<List<Anime>>((ref) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(animeRepositoryProvider).fetchRecentlyCompleted();
});

final topMonthProvider = FutureProvider<List<Anime>>((ref) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(animeRepositoryProvider).fetchTopMonth();
});

final allAnimeProvider = FutureProvider<List<Anime>>((ref) async {
  ref.watch(catalogRevisionProvider);
  final repo = ref.watch(animeRepositoryProvider);
  final featured = await repo.fetchFeatured();
  final editors = await repo.fetchEditorsPicks();
  final trending = await repo.fetchTrendingNow();
  final newEps = await repo.fetchNewEpisodes();
  final recentlyCompleted = await repo.fetchRecentlyCompleted();
  final topMonth = await repo.fetchTopMonth();

  final all = [
    featured,
    ...editors,
    ...trending,
    ...newEps,
    ...recentlyCompleted,
    ...topMonth,
  ];
  final map = {for (var a in all) a.id: a}; // deduplicate
  return map.values.toList();
});

/// Simple UI-only state — which category tab and nav item are selected.
/// StateProvider is the right tool for trivial state like this; no
/// need for a full StateNotifier/Notifier class for a single int.
class SelectedCategoryNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, int>(
      SelectedCategoryNotifier.new,
    );

class SelectedNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final selectedNavIndexProvider =
    NotifierProvider<SelectedNavIndexNotifier, int>(
      SelectedNavIndexNotifier.new,
    );

const categories = [
  'All',
  'Action',
  'Romance',
  'Comedy',
  'Fantasy',
  'Drama',
  'Sci-Fi',
  'Slice of Life',
  'Mecha',
  'Supernatural',
  'Sports',
  'Horror',
  'Mystery',
];
