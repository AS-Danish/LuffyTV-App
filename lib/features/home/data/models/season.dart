import 'episode.dart';

class Season {
  final String id;
  final int seasonNumber;
  final String title;
  final List<Episode> episodes;

  const Season({
    required this.id,
    required this.seasonNumber,
    required this.title,
    this.episodes = const [],
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'].toString(),
      seasonNumber: json['seasonNumber'] as int? ?? 1,
      title: json['title'] as String? ?? 'Season 1',
      episodes: (json['episodes'] as List<dynamic>?)
              ?.map((e) => Episode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
