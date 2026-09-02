import 'package:flutter_test/flutter_test.dart';
import 'package:luffytv/features/downloads/data/models/download_item.dart';
import 'package:luffytv/features/home/data/models/episode.dart';
import 'package:luffytv/features/home/data/models/watch_data.dart';

void main() {
  test('watch data retains valid intro and outro ranges', () {
    final data = WatchData.fromJson({
      'servers': <Object>[],
      'sources': <Object>[],
      'skip_data': {
        'intro': {'start': 12, 'end': 94.5},
        'outro': [1320, 1410],
      },
    });

    expect(data.skipData?.intro?.startSeconds, 12);
    expect(data.skipData?.intro?.endSeconds, 94.5);
    expect(data.skipData?.outro?.startSeconds, 1320);
    expect(data.skipData?.intro?.contains(const Duration(seconds: 30)), isTrue);
  });

  test('download metadata round-trips audio, subtitles, and skip data', () {
    final item = DownloadItem(
      id: 'show_1',
      animeSlug: 'show',
      animeTitle: 'Show',
      episode: const Episode(
        id: 'episode-1',
        episodeNumber: 1,
        title: 'Episode 1',
        durationMinutes: 24,
        description: '',
      ),
      sourceType: 'dub',
      audioLabel: 'DUB • English',
      subtitles: const [
        DownloadedSubtitle(
          label: 'English',
          language: 'en',
          localPath: r'C:\offline\english.vtt',
        ),
      ],
      skipData: const SkipData(
        intro: SkipRange(startSeconds: 0, endSeconds: 90),
      ),
    );

    final restored = DownloadItem.fromJson(item.toJson());
    expect(restored.sourceType, 'dub');
    expect(restored.audioLabel, 'DUB • English');
    expect(restored.subtitles.single.label, 'English');
    expect(restored.skipData?.intro?.endSeconds, 90);
  });
}
