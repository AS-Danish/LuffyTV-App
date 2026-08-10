import '../models/anime.dart';

/// Abstract contract. Screens and providers only ever depend on this —
/// never on a concrete implementation. This is the one seam that lets
/// you plug in a real backend later by writing one new class.
abstract class AnimeRepository {
  Future<Anime> fetchFeatured();
  Future<List<Anime>> fetchEditorsPicks();
  Future<List<Anime>> fetchTrendingNow();
  Future<List<Anime>> fetchNewEpisodes();
}

/// Placeholder implementation with fake data + a simulated network
/// delay, so loading states are visible and honest during development.
/// Replace with an HTTP-backed implementation when your API is ready —
/// the rest of the app won't need to change.
class MockAnimeRepository implements AnimeRepository {
  @override
  Future<Anime> fetchFeatured() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const Anime(id: 'f1', title: 'Crimson Requiem', genre: 'Dark Fantasy / Action', year: 2026, gradientIndex: 1);
  }

  @override
  Future<List<Anime>> fetchEditorsPicks() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const [
      Anime(id: 'p1', title: 'Frostbound Oath', genre: 'Fantasy', year: 2025, gradientIndex: 0),
      Anime(id: 'p2', title: 'Nightfall Academy', genre: 'Supernatural', year: 2025, gradientIndex: 1),
      Anime(id: 'p3', title: 'The Last Cartographer', genre: 'Adventure', year: 2024, gradientIndex: 2),
      Anime(id: 'p4', title: 'Hollow Meridian', genre: 'Sci-Fi', year: 2026, gradientIndex: 3),
      Anime(id: 'p5', title: 'Ashlight', genre: 'Drama', year: 2024, gradientIndex: 4),
    ];
  }

  @override
  Future<List<Anime>> fetchTrendingNow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      Anime(id: 't1', title: 'Jujutsu Kaisen', genre: 'Action', year: 2024, gradientIndex: 1),
      Anime(id: 't2', title: 'Demon Slayer', genre: 'Action', year: 2024, gradientIndex: 3),
      Anime(id: 't3', title: 'Attack on Titan', genre: 'Action', year: 2023, gradientIndex: 4),
      Anime(id: 't4', title: 'Frieren', genre: 'Fantasy', year: 2024, gradientIndex: 0),
    ];
  }

  @override
  Future<List<Anime>> fetchNewEpisodes() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const [
      Anime(id: 'n1', title: 'Solo Leveling', genre: 'Action', year: 2024, gradientIndex: 2),
      Anime(id: 'n2', title: 'One Piece', genre: 'Adventure', year: 2024, gradientIndex: 1),
      Anime(id: 'n3', title: 'Kaiju No. 8', genre: 'Action', year: 2024, gradientIndex: 3),
      Anime(id: 'n4', title: 'My Hero Academia', genre: 'Action', year: 2024, gradientIndex: 4),
    ];
  }
}
