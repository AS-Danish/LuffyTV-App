import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repository/anime_repository.dart';
import '../data/models/anime.dart';

/// Swap MockAnimeRepository() for a real implementation here — this is
/// the single line the rest of the app depends on.
final animeRepositoryProvider = Provider<AnimeRepository>((ref) => MockAnimeRepository());

/// FutureProvider handles loading/error/data states automatically —
/// screens consume this via AsyncValue and get a switch-case-free
/// .when(loading:, error:, data:) instead of manual bool flags.
final featuredAnimeProvider = FutureProvider<Anime>((ref) {
  return ref.watch(animeRepositoryProvider).fetchFeatured();
});

final editorsPicksProvider = FutureProvider<List<Anime>>((ref) {
  return ref.watch(animeRepositoryProvider).fetchEditorsPicks();
});

final trendingNowProvider = FutureProvider<List<Anime>>((ref) {
  return ref.watch(animeRepositoryProvider).fetchTrendingNow();
});

final newEpisodesProvider = FutureProvider<List<Anime>>((ref) {
  return ref.watch(animeRepositoryProvider).fetchNewEpisodes();
});

final allAnimeProvider = FutureProvider<List<Anime>>((ref) async {
  final repo = ref.watch(animeRepositoryProvider);
  final featured = await repo.fetchFeatured();
  final editors = await repo.fetchEditorsPicks();
  final trending = await repo.fetchTrendingNow();
  final newEps = await repo.fetchNewEpisodes();
  
  final all = [featured, ...editors, ...trending, ...newEps];
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
final selectedCategoryProvider = NotifierProvider<SelectedCategoryNotifier, int>(SelectedCategoryNotifier.new);

class SelectedNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}
final selectedNavIndexProvider = NotifierProvider<SelectedNavIndexNotifier, int>(SelectedNavIndexNotifier.new);

const categories = ['All', 'Shounen', 'Isekai', 'Romance', 'Slice of Life', 'Mecha'];
