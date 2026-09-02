class WatchData {
  final List<VideoServer> servers;
  final List<VideoSource> sources;
  final SkipData? skipData;

  const WatchData({
    required this.servers,
    required this.sources,
    this.skipData,
  });

  factory WatchData.fromJson(Map<String, dynamic> json) {
    return WatchData(
      servers:
          (json['servers'] as List<dynamic>?)
              ?.map((e) => VideoServer.fromJson(e))
              .toList() ??
          [],
      sources:
          (json['sources'] as List<dynamic>?)
              ?.map((e) => VideoSource.fromJson(e))
              .toList() ??
          [],
      skipData: SkipData.fromJsonOrNull(json['skip_data'] ?? json['skipData']),
    );
  }
}

class SkipData {
  final SkipRange? intro;
  final SkipRange? outro;

  const SkipData({this.intro, this.outro});

  bool get hasAny => intro?.isValid == true || outro?.isValid == true;

  Map<String, dynamic> toJson() => {
    if (intro != null) 'intro': intro!.toJson(),
    if (outro != null) 'outro': outro!.toJson(),
  };

  static SkipData? fromJsonOrNull(Object? value) {
    if (value is! Map) return null;
    final data = Map<String, dynamic>.from(value);
    final result = SkipData(
      intro: SkipRange.fromJsonOrNull(data['intro']),
      outro: SkipRange.fromJsonOrNull(data['outro']),
    );
    return result.hasAny ? result : null;
  }
}

class SkipRange {
  final double startSeconds;
  final double endSeconds;

  const SkipRange({required this.startSeconds, required this.endSeconds});

  bool get isValid =>
      startSeconds >= 0 && endSeconds > startSeconds && endSeconds.isFinite;

  bool contains(Duration position) {
    final seconds = position.inMilliseconds / 1000;
    return isValid && seconds >= startSeconds && seconds < endSeconds;
  }

  Map<String, dynamic> toJson() => {'start': startSeconds, 'end': endSeconds};

  static SkipRange? fromJsonOrNull(Object? value) {
    num? start;
    num? end;
    if (value is Map) {
      start = value['start'] as num?;
      end = value['end'] as num?;
    } else if (value is List && value.length >= 2) {
      start = value[0] as num?;
      end = value[1] as num?;
    }
    if (start == null || end == null) return null;
    final range = SkipRange(
      startSeconds: start.toDouble(),
      endSeconds: end.toDouble(),
    );
    return range.isValid ? range : null;
  }
}

class VideoServer {
  final String id;
  final String name;
  final String type;

  const VideoServer({required this.id, required this.name, required this.type});

  factory VideoServer.fromJson(Map<String, dynamic> json) {
    return VideoServer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }
}

class VideoSource {
  final String server;
  final String type;
  final String url;
  final String? m3u8;
  final String? referer;
  final String? proxyUrl;
  final List<VideoTrack> tracks;
  final String? language;

  const VideoSource({
    required this.server,
    required this.type,
    required this.url,
    this.m3u8,
    this.referer,
    this.proxyUrl,
    required this.tracks,
    this.language,
  });

  String? get playableUrl {
    for (final candidate in [proxyUrl, m3u8, url]) {
      final value = candidate?.trim() ?? '';
      if (value.isEmpty) continue;
      if (value.startsWith('/')) return value;
      final uri = Uri.tryParse(value);
      if (uri != null &&
          uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https')) {
        return value;
      }
    }
    return null;
  }

  bool get isPlayable => playableUrl != null;

  factory VideoSource.fromJson(Map<String, dynamic> json) {
    return VideoSource(
      server: json['server'] as String? ?? '',
      type: json['type'] as String? ?? '',
      url: json['url'] as String? ?? '',
      m3u8: json['m3u8'] as String?,
      referer: json['referer'] as String?,
      proxyUrl: json['proxyUrl'] as String?,
      tracks:
          (json['tracks'] as List<dynamic>?)
              ?.map((e) => VideoTrack.fromJson(e))
              .toList() ??
          [],
      language:
          (json['language'] ?? json['audioLanguage'] ?? json['dubLanguage'])
              ?.toString(),
    );
  }
}

class VideoTrack {
  final String file;
  final String label;
  final String kind;
  final bool? defaultTrack;
  final String? proxyUrl;

  const VideoTrack({
    required this.file,
    required this.label,
    required this.kind,
    this.defaultTrack,
    this.proxyUrl,
  });

  factory VideoTrack.fromJson(Map<String, dynamic> json) {
    return VideoTrack(
      file: json['file'] as String? ?? '',
      label: json['label'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      defaultTrack: json['default'] as bool?,
      proxyUrl: json['proxyUrl'] as String?,
    );
  }
}
