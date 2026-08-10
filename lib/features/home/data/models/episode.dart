class Episode {
  final String id;
  final int episodeNumber;
  final String title;
  final int durationMinutes;
  final String description;
  final String? thumbnailUrl;
  final double progress; // 0.0 to 1.0

  const Episode({
    required this.id,
    required this.episodeNumber,
    required this.title,
    required this.durationMinutes,
    required this.description,
    this.thumbnailUrl,
    this.progress = 0.0,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'].toString(),
      episodeNumber: json['episodeNumber'] as int? ?? 0,
      title: json['title'] as String? ?? 'Untitled',
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
