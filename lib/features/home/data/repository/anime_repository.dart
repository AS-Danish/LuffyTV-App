import '../models/anime.dart';
import '../models/season.dart';
import '../models/episode.dart';
import 'package:luffytv/features/details/data/models/anime_detail.dart';

/// Abstract contract. Screens and providers only ever depend on this —
/// never on a concrete implementation. This is the one seam that lets
/// you plug in a real backend later by writing one new class.
abstract class AnimeRepository {
  Future<Anime> fetchFeatured();
  Future<List<Anime>> fetchEditorsPicks();
  Future<List<Anime>> fetchTrendingNow();
  Future<List<Anime>> fetchNewEpisodes();
  Future<List<Anime>> fetchRecentlyCompleted();
  Future<List<Anime>> fetchTopMonth();

  Future<AnimeDetail> fetchAnimeDetails(String slug);
  Future<List<Episode>> fetchAnimeEpisodes(String slug);
  Future<List<Anime>> searchAnime(String keyword);
}

/// Helper to generate mock seasons
List<Season> _generateSeasons() {
  return [
    Season(
      id: 's1',
      seasonNumber: 1,
      title: 'Season 1',
      episodes: List.generate(12, (index) => Episode(
        id: 'e1_$index',
        episodeNumber: index + 1,
        title: 'Episode ${index + 1}',
        durationMinutes: 24,
        description: 'This is an exciting episode where our heroes face new challenges and discover hidden powers. The animation is top-notch.',
        progress: index == 2 ? 0.4 : (index < 2 ? 1.0 : 0.0),
      )),
    ),
    Season(
      id: 's2',
      seasonNumber: 2,
      title: 'Season 2',
      episodes: List.generate(12, (index) => Episode(
        id: 'e2_$index',
        episodeNumber: index + 1,
        title: 'Episode ${index + 1}',
        durationMinutes: 24,
        description: 'The journey continues as darker forces emerge from the shadows. Betrayal and epic battles await in this new chapter.',
        progress: 0.0,
      )),
    ),
  ];
}

Anime _enrichAnime(Anime base) {
  return Anime(
    id: base.id,
    title: base.title,
    genre: base.genre,
    year: base.year,
    posterUrl: 'https://picsum.photos/seed/${base.id}/400/600',
    gradientIndex: base.gradientIndex,
    description: 'When the world is threatened by an ancient evil, a young hero must rise and master their hidden potential. Joined by a colorful cast of misfits, they embark on an epic quest to save their realm. Gripping action and stunning animation.',
    maturityRating: 'TV-MA',
    matchPercentage: 98,
    cast: const ['Natsuki Hanae', 'Yuki Kaji', 'Kana Hanazawa', 'Mamoru Miyano'],
    creator: 'Hayao Miyazaki',
    seasons: _generateSeasons(),
  );
}

/// Placeholder implementation with fake data + a simulated network
/// delay, so loading states are visible and honest during development.
class MockAnimeRepository implements AnimeRepository {
  @override
  Future<Anime> fetchFeatured() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _enrichAnime(const Anime(id: 'f1', title: 'Crimson Requiem', genre: 'Dark Fantasy / Action', year: 2026, gradientIndex: 1));
  }

  @override
  Future<List<Anime>> fetchEditorsPicks() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      _enrichAnime(const Anime(id: 'p1', title: 'Frostbound Oath', genre: 'Fantasy', year: 2025, gradientIndex: 0)),
      _enrichAnime(const Anime(id: 'p2', title: 'Nightfall Academy', genre: 'Supernatural', year: 2025, gradientIndex: 1)),
      _enrichAnime(const Anime(id: 'p3', title: 'The Last Cartographer', genre: 'Adventure', year: 2024, gradientIndex: 2)),
      _enrichAnime(const Anime(id: 'p4', title: 'Hollow Meridian', genre: 'Sci-Fi', year: 2026, gradientIndex: 3)),
      _enrichAnime(const Anime(id: 'p5', title: 'Ashlight', genre: 'Drama', year: 2024, gradientIndex: 4)),
    ];
  }

  @override
  Future<List<Anime>> fetchTrendingNow() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      _enrichAnime(const Anime(id: 't1', title: 'Jujutsu Kaisen', genre: 'Action', year: 2024, gradientIndex: 1)),
      _enrichAnime(const Anime(id: 't2', title: 'Demon Slayer', genre: 'Action', year: 2024, gradientIndex: 3)),
      _enrichAnime(const Anime(id: 't3', title: 'Attack on Titan', genre: 'Action', year: 2023, gradientIndex: 4)),
      _enrichAnime(const Anime(id: 't4', title: 'Frieren', genre: 'Fantasy', year: 2024, gradientIndex: 0)),
    ];
  }

  @override
  Future<List<Anime>> fetchNewEpisodes() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      _enrichAnime(const Anime(id: 'n1', title: 'Solo Leveling', genre: 'Action', year: 2024, gradientIndex: 2)),
      _enrichAnime(const Anime(id: 'n2', title: 'One Piece', genre: 'Adventure', year: 2024, gradientIndex: 1)),
      _enrichAnime(const Anime(id: 'n3', title: 'Kaiju No. 8', genre: 'Action', year: 2024, gradientIndex: 3)),
      _enrichAnime(const Anime(id: 'n4', title: 'My Hero Academia', genre: 'Action', year: 2024, gradientIndex: 4)),
    ];
  }

  @override
  Future<List<Anime>> fetchRecentlyCompleted() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }

  @override
  Future<List<Anime>> fetchTopMonth() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }

  @override
  Future<AnimeDetail> fetchAnimeDetails(String slug) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return AnimeDetail(
      id: slug,
      title: 'Mock Anime',
      posterUrl: '',
      description: 'Mock description',
      status: 'Unknown',
      year: '2024',
      rating: 'PG',
      duration: '24m',
      episodeCount: 12,
      genres: [],
      studios: [],
      hasSub: true,
      hasDub: false,
    );
  }

  @override
  Future<List<Episode>> fetchAnimeEpisodes(String slug) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      const Episode(id: '1', episodeNumber: 1, title: 'Episode 1', durationMinutes: 24, description: '', hasSub: true, hasDub: false),
    ];
  }

  @override
  Future<List<Anime>> searchAnime(String keyword) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }
}
