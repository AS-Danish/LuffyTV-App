import 'package:luffytv/features/home/data/models/watch_data.dart';

class PreparedDownloadSource {
  final VideoSource source;
  final WatchData watchData;
  final String? playlist;
  const PreparedDownloadSource(this.source, this.watchData, this.playlist);
}

bool matchesDownloadAudio(VideoSource selected, VideoSource candidate) {
  final selectedType = selected.type.trim().toLowerCase();
  final candidateType = candidate.type.trim().toLowerCase();
  if (selectedType != candidateType) return false;
  if (!selectedType.startsWith('dub')) return true;
  final selectedLanguage = (selected.language ?? '').trim().toLowerCase();
  final candidateLanguage = (candidate.language ?? '').trim().toLowerCase();
  // Providers do not consistently include a language tag on every refresh.
  // An absent tag must not make the same dub source look incompatible.
  return selectedLanguage.isEmpty ||
      candidateLanguage.isEmpty ||
      selectedLanguage == candidateLanguage;
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
          !matchesDownloadAudio(selected, candidate) ||
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
