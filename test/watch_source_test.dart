import 'package:flutter_test/flutter_test.dart';
import 'package:luffytv/features/home/data/models/watch_data.dart';

VideoSource source({
  String url = 'https://player.test/embed/1',
  String? media,
  String? proxy,
  String server = 'HD-1',
  String type = 'sub',
}) => VideoSource(
  server: server,
  type: type,
  url: url,
  m3u8: media,
  proxyUrl: proxy,
  tracks: [],
);

void main() {
  test('embed-only responses are not playable or downloadable', () {
    expect(source().isPlayable, false);
    expect(
      source(url: 'https://media.test/movie.mp4?token=1').isPlayable,
      true,
    );
    expect(source(media: 'https://media.test/playlist').isPlayable, true);
    expect(source(proxy: '/api/proxy?url=signed').isPlayable, true);
  });

  test('server aliases and renewed proxy signatures identify the same media', () {
    final first = source(
      proxy:
          'https://proxy.test/?url=https%3A%2F%2Fmedia.test%2Fmaster.m3u8&sig=old',
    );
    final renewed = source(
      server: 'HD-2',
      proxy:
          'https://proxy.test/?url=https%3A%2F%2Fmedia.test%2Fmaster.m3u8&sig=new',
    );
    expect(first.playbackKey, renewed.playbackKey);
    expect(
      source(media: 'https://media.test/master.m3u8').playbackKey,
      first.playbackKey,
    );
    expect(
      source(type: 'dub', media: 'https://media.test/master.m3u8').playbackKey,
      isNot(first.playbackKey),
    );
  });
}
