/// Only a finite VOD playlist can establish the expected download duration.
double? hlsVodDuration(String playlist) {
  if (!playlist.trimLeft().startsWith('#EXTM3U') ||
      !playlist.contains('#EXT-X-ENDLIST') ||
      playlist.contains('#EXT-X-STREAM-INF')) {
    return null;
  }
  var duration = 0.0;
  var segments = 0;
  for (final line in playlist.split('\n')) {
    if (!line.trim().startsWith('#EXTINF:')) continue;
    final seconds = double.tryParse(line.trim().substring(8).split(',').first);
    if (seconds == null || !seconds.isFinite || seconds <= 0) return null;
    duration += seconds;
    segments++;
  }
  return segments > 0 ? duration : null;
}
