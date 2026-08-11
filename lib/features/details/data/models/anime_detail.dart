class AnimeDetail {
  final String id;
  final String title;
  final String posterUrl;
  final String description;
  final String status;
  final String year;
  final String rating;
  final String duration;
  final int episodeCount;
  final List<String> genres;
  final List<String> studios;
  final bool hasSub;
  final bool hasDub;

  const AnimeDetail({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.description,
    required this.status,
    required this.year,
    required this.rating,
    required this.duration,
    required this.episodeCount,
    required this.genres,
    required this.studios,
    required this.hasSub,
    required this.hasDub,
  });

  factory AnimeDetail.fromJson(Map<String, dynamic> json) {
    return AnimeDetail(
      id: json['slug'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      posterUrl: json['image'] as String? ?? '',
      description: json['synopsis'] as String? ?? '',
      status: json['status'] as String? ?? 'Unknown',
      year: json['premiered'] as String? ?? json['aired'] as String? ?? '',
      rating: json['rating'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      episodeCount: json['episodeCount'] as int? ?? 0,
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      studios: (json['studios'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      hasSub: json['hasSub'] as bool? ?? false,
      hasDub: json['hasDub'] as bool? ?? false,
    );
  }
}
