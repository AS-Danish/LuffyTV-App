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

  const Anime({
    required this.id,
    required this.title,
    required this.genre,
    required this.year,
    this.posterUrl,
    this.gradientIndex = 0,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: json['id'].toString(),
      title: json['title'] as String? ?? 'Untitled',
      genre: json['genre'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      posterUrl: json['poster'] as String? ?? json['image'] as String?,
    );
  }
}
