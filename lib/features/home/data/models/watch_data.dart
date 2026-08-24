class WatchData {
  final List<VideoServer> servers;
  final List<VideoSource> sources;

  const WatchData({required this.servers, required this.sources});

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
    );
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

  const VideoSource({
    required this.server,
    required this.type,
    required this.url,
    this.m3u8,
    this.referer,
    this.proxyUrl,
    required this.tracks,
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
