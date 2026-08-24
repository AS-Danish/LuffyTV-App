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
  final String? posterPreviewUrl;
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
    this.posterPreviewUrl,
    this.gradientIndex = 0,
    this.description = '',
    this.maturityRating = 'TV-14',
    this.matchPercentage = 90,
    this.cast = const [],
    this.creator = 'Unknown',
    this.seasons = const [],
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    // Determine the year from date if available
    int parsedYear = 0;
    if (json['year'] != null) {
      parsedYear = json['year'] as int;
    } else if (json['date'] != null) {
      final dateStr = json['date'] as String;
      // Extract 4 digit year from something like "Jul 25, 2026 to ?" or "2026-08-05"
      final yearRegex = RegExp(r'\b(19|20)\d{2}\b');
      final match = yearRegex.firstMatch(dateStr);
      if (match != null) {
        parsedYear = int.parse(match.group(0)!);
      }
    }

    return Anime(
      id: (json['slug'] ?? json['id'] ?? '').toString(),
      title: json['title'] as String? ?? 'Untitled',
      genre: json['genre'] as String? ?? '',
      year: parsedYear,
      posterUrl:
          json['posterUrl'] as String? ??
          json['image'] as String? ??
          json['poster'] as String?,
      posterPreviewUrl: json['posterPreviewUrl'] as String?,
      description:
          json['synopsis'] as String? ?? json['description'] as String? ?? '',
      maturityRating:
          json['rating'] as String? ??
          json['maturityRating'] as String? ??
          'TV-14',
      matchPercentage: json['matchPercentage'] as int? ?? 90,
      cast:
          (json['cast'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      creator: json['creator'] as String? ?? 'Unknown',
      seasons:
          (json['seasons'] as List<dynamic>?)
              ?.map((e) => Season.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'genre': genre,
      'year': year,
      'posterUrl': posterUrl,
      'posterPreviewUrl': posterPreviewUrl,
      'gradientIndex': gradientIndex,
      'description': description,
      'maturityRating': maturityRating,
      'matchPercentage': matchPercentage,
      'cast': cast,
      'creator': creator,
      'seasons': seasons.map((e) => e.toJson()).toList(),
    };
  }

  Anime copyWith({String? posterUrl, String? posterPreviewUrl}) {
    return Anime(
      id: id,
      title: title,
      genre: genre,
      year: year,
      posterUrl: posterUrl ?? this.posterUrl,
      posterPreviewUrl: posterPreviewUrl ?? this.posterPreviewUrl,
      gradientIndex: gradientIndex,
      description: description,
      maturityRating: maturityRating,
      matchPercentage: matchPercentage,
      cast: cast,
      creator: creator,
      seasons: seasons,
    );
  }
}
