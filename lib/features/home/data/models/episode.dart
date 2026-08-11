class Episode {
  final String id;
  final int episodeNumber;
  final String title;
  final int durationMinutes;
  final String description;
  final String? thumbnailUrl;
  final double progress; // 0.0 to 1.0
  final bool hasSub;
  final bool hasDub;

  const Episode({
    required this.id,
    required this.episodeNumber,
    required this.title,
    required this.durationMinutes,
    required this.description,
    this.thumbnailUrl,
    this.progress = 0.0,
    this.hasSub = false,
    this.hasDub = false,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    // API returns number as string sometimes, and id in dataIds
    final numStr = json['number']?.toString() ?? json['episodeNumber']?.toString() ?? '0';
    final parsedNum = int.tryParse(numStr) ?? 0;
    
    return Episode(
      id: json['dataIds']?.toString() ?? json['id']?.toString() ?? '',
      episodeNumber: parsedNum,
      title: json['title'] as String? ?? 'Episode $parsedNum',
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      hasSub: json['hasSub'] as bool? ?? false,
      hasDub: json['hasDub'] as bool? ?? false,
    );
  }
}
