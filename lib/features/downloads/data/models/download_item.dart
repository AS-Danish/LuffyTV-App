import 'package:luffytv/features/home/data/models/episode.dart';

enum DownloadState {
  pending,
  downloading,
  completed,
  failed,
}

class DownloadItem {
  final String id; // Unique ID (e.g. animeSlug_episodeNumber)
  final String animeSlug;
  final String animeTitle;
  final String? posterUrl;
  final Episode episode;
  final DownloadState state;
  final double progress; // 0.0 to 1.0
  final String? localM3u8Path;
  final int watchProgressSeconds; // where user left off

  const DownloadItem({
    required this.id,
    required this.animeSlug,
    required this.animeTitle,
    this.posterUrl,
    required this.episode,
    this.state = DownloadState.pending,
    this.progress = 0.0,
    this.localM3u8Path,
    this.watchProgressSeconds = 0,
  });

  DownloadItem copyWith({
    DownloadState? state,
    double? progress,
    String? localM3u8Path,
    int? watchProgressSeconds,
  }) {
    return DownloadItem(
      id: id,
      animeSlug: animeSlug,
      animeTitle: animeTitle,
      posterUrl: posterUrl,
      episode: episode,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      localM3u8Path: localM3u8Path ?? this.localM3u8Path,
      watchProgressSeconds: watchProgressSeconds ?? this.watchProgressSeconds,
    );
  }

  // Very basic serialization for SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'animeSlug': animeSlug,
      'animeTitle': animeTitle,
      'posterUrl': posterUrl,
      'episodeId': episode.id,
      'episodeNumber': episode.episodeNumber,
      'episodeTitle': episode.title,
      'state': state.name,
      'progress': progress,
      'localM3u8Path': localM3u8Path,
      'watchProgressSeconds': watchProgressSeconds,
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'],
      animeSlug: json['animeSlug'],
      animeTitle: json['animeTitle'],
      posterUrl: json['posterUrl'],
      episode: Episode(
        id: json['episodeId'] ?? '',
        episodeNumber: json['episodeNumber'] ?? 0,
        title: json['episodeTitle'] ?? '',
        durationMinutes: 24, // Mock
        description: '',
      ),
      state: DownloadState.values.firstWhere((e) => e.name == json['state'], orElse: () => DownloadState.pending),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      localM3u8Path: json['localM3u8Path'],
      watchProgressSeconds: json['watchProgressSeconds'] as int? ?? 0,
    );
  }
}
