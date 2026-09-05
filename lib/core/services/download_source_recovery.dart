import 'package:luffytv/features/home/data/models/watch_data.dart';

class PreparedDownloadSource {
  final VideoSource source;
  final WatchData watchData;
  final String? playlist;
  const PreparedDownloadSource(this.source, this.watchData, this.playlist);
}

/// Two bounded rounds: available sources, then freshly resolved sources.
/// Keep the user's audio selection while rejecting aliases within each round.
Future<PreparedDownloadSource> prepareDownloadSource({
  required VideoSource selected,
  required WatchData initial,
  required Future<WatchData> Function() refresh,
  required Future<String?> Function(VideoSource source) loadPlaylist,
}) async {
  var data = initial;
  Object? lastError;
  for (var round = 0; round < 2; round++) {
    if (round == 1) data = await refresh();
    final attempted = <String>{};
    final candidates = [if (round == 0) selected, ...data.sources];
    for (final candidate in candidates) {
      if (!candidate.isPlayable ||
          candidate.type.toLowerCase() != selected.type.toLowerCase() ||
          (candidate.language ?? '').toLowerCase() !=
              (selected.language ?? '').toLowerCase() ||
          !attempted.add(candidate.playbackKey)) {
        continue;
      }
      try {
        final playlist = await loadPlaylist(candidate);
        if (playlist != null && !playlist.trimLeft().startsWith('#EXTM3U')) {
          throw Exception(
            'The video provider did not return a video playlist.',
          );
        }
        return PreparedDownloadSource(candidate, data, playlist);
      } catch (error) {
        lastError = error;
      }
    }
  }
  throw Exception(
    'No working download source is available for the selected audio. ${lastError ?? ''}',
  );
}
