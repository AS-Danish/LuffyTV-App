import 'season.dart';

/// Core domain model. Kept intentionally flat — no nested value objects
/// until the API response actually demands them. Add fields as your
/// real data source requires (e.g. episodeCount, rating, synopsis).
class Anime {
  final String id;
  final String title;
  final String genre;
  final int year;
  final String? posterUrl;
  final int gradientIndex; // fallback visual while posterUrl is null
  
  // Netflix-style detailed fields
  final String description;
  final String maturityRating;
  final int matchPercentage;
  final List<String> cast;
  final String creator;
  final List<Season> seasons;

  const Anime({
    required this.id,
    required this.title,
    required this.genre,
    required this.year,
    this.posterUrl,
    this.gradientIndex = 0,
    this.description = '',
    this.maturityRating = 'TV-14',
    this.matchPercentage = 90,
    this.cast = const [],
    this.creator = 'Unknown',
    this.seasons = const [],
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: json['id'].toString(),
      title: json['title'] as String? ?? 'Untitled',
      genre: json['genre'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      posterUrl: json['poster'] as String? ?? json['image'] as String?,
      description: json['description'] as String? ?? '',
      maturityRating: json['maturityRating'] as String? ?? 'TV-14',
      matchPercentage: json['matchPercentage'] as int? ?? 90,
      cast: (json['cast'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      creator: json['creator'] as String? ?? 'Unknown',
      seasons: (json['seasons'] as List<dynamic>?)
              ?.map((e) => Season.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
