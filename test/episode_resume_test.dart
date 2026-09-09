import 'package:flutter_test/flutter_test.dart';
import 'package:luffytv/core/services/episode_resume.dart';
import 'package:luffytv/core/services/local_db_service.dart';
import 'package:luffytv/core/services/hls_duration.dart';
import 'package:luffytv/features/home/data/models/anime.dart';

void main() {
  WatchProgress progress(int position) => WatchProgress(
    animeSlug: 'test',
    anime: const Anime(id: 'test', title: 'Test', genre: '', year: 0),
    lastWatchedEpisode: 72,
    updatedAt: DateTime(2026),
    episodes: {'72': EpisodeProgress(position, 1440)},
  );
  test('unfinished episode resumes and completed episode advances', () {
    expect(episodeResume([73, 72, 1], progress(400)), (
      episode: 72,
      resume: true,
    ));
    expect(episodeResume([73, 72, 1], progress(1440)), (
      episode: 73,
      resume: false,
    ));
  });
  test('finales, missing numbers and empty catalogue', () {
    expect(episodeResume([72], progress(1440)), (episode: 72, resume: false));
    expect(episodeResume([72, 74], progress(1440)), (
      episode: 74,
      resume: false,
    ));
    expect(episodeResume([], progress(400)), isNull);
    expect(episodeResume([3, 1], null), (episode: 1, resume: false));
  });
  test('duration fallback accepts finite VOD only', () {
    expect(
      hlsVodDuration(
        '#EXTM3U\n#EXTINF:6.5,\na.ts\n#EXTINF:4,\nb.ts\n#EXT-X-ENDLIST',
      ),
      10.5,
    );
    expect(hlsVodDuration('#EXTM3U\n#EXTINF:6,\na.ts'), isNull);
    expect(hlsVodDuration('<html>error</html>'), isNull);
    expect(
      hlsVodDuration('#EXTM3U\n#EXTINF:NaN,\na.ts\n#EXT-X-ENDLIST'),
      isNull,
    );
  });
}
