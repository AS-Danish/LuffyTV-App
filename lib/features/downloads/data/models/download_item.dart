import 'package:luffytv/features/home/data/models/episode.dart';
import 'package:luffytv/features/home/data/models/watch_data.dart';

enum DownloadState { pending, downloading, completed, failed }

class DownloadedSubtitle {
  final String label;
  final String language;
  final String localPath;

  const DownloadedSubtitle({
    required this.label,
    required this.language,
    required this.localPath,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'language': language,
    'localPath': localPath,
  };

  factory DownloadedSubtitle.fromJson(Map<String, dynamic> json) =>
      DownloadedSubtitle(
        label: json['label']?.toString() ?? 'Subtitle',
        language: json['language']?.toString() ?? '',
        localPath: json['localPath']?.toString() ?? '',
      );
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
  final String sourceType;
  final String audioLabel;
  final List<DownloadedSubtitle> subtitles;
  final int failedSubtitleCount;
  final SkipData? skipData;
  final String? errorMessage;

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
    this.sourceType = 'sub',
    this.audioLabel = 'Original audio',
    this.subtitles = const [],
    this.failedSubtitleCount = 0,
    this.skipData,
    this.errorMessage,
  });

  DownloadItem copyWith({
    DownloadState? state,
    double? progress,
    String? localM3u8Path,
    int? watchProgressSeconds,
    String? sourceType,
    String? audioLabel,
    List<DownloadedSubtitle>? subtitles,
    int? failedSubtitleCount,
    SkipData? skipData,
    String? errorMessage,
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
      sourceType: sourceType ?? this.sourceType,
      audioLabel: audioLabel ?? this.audioLabel,
      subtitles: subtitles ?? this.subtitles,
      failedSubtitleCount: failedSubtitleCount ?? this.failedSubtitleCount,
      skipData: skipData ?? this.skipData,
      errorMessage: errorMessage ?? this.errorMessage,
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
      'sourceType': sourceType,
      'audioLabel': audioLabel,
      'subtitles': subtitles.map((subtitle) => subtitle.toJson()).toList(),
      'failedSubtitleCount': failedSubtitleCount,
      'skipData': skipData?.toJson(),
      'errorMessage': errorMessage,
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
      state: DownloadState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => DownloadState.pending,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      localM3u8Path: json['localM3u8Path'],
      watchProgressSeconds: json['watchProgressSeconds'] as int? ?? 0,
      sourceType: json['sourceType']?.toString() ?? 'sub',
      audioLabel: json['audioLabel']?.toString() ?? 'Original audio',
      subtitles:
          (json['subtitles'] as List?)
              ?.whereType<Map>()
              .map(
                (value) => DownloadedSubtitle.fromJson(
                  Map<String, dynamic>.from(value),
                ),
              )
              .where((subtitle) => subtitle.localPath.isNotEmpty)
              .toList() ??
          const [],
      failedSubtitleCount: (json['failedSubtitleCount'] as num?)?.toInt() ?? 0,
      skipData: SkipData.fromJsonOrNull(json['skipData']),
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
