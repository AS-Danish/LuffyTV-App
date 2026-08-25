import 'package:flutter_test/flutter_test.dart';
import 'package:luffytv/update/update_manifest.dart';
import 'package:luffytv/update/update_state.dart';

Map<String, dynamic> manifestJson({
  int versionCode = 14,
  int minimumCode = 14,
  bool mandatory = true,
  String hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
}) => {
  'version': '1.4.0',
  'versionCode': versionCode,
  'minimumSupportedVersionCode': minimumCode,
  'apkUrl': 'https://releases.example/luffy-tv.apk',
  'sha256': hash,
  'apkSize': 1024,
  'mandatory': mandatory,
  'title': 'Update required',
  'message': 'Install now.',
  'changelog': ['One', 'Two'],
  'publishedAt': '2026-08-25T00:00:00Z',
};

void main() {
  test('parses a valid compulsory manifest defensively', () {
    final manifest = UpdateManifest.fromJson(manifestJson());
    expect(manifest.versionCode, 14);
    expect(manifest.minimumSupportedVersionCode, 14);
    expect(manifest.apkUrl.scheme, 'https');
    expect(manifest.changelog, ['One', 'Two']);
  });

  test('rejects optional, insecure, malformed, and downgrade manifests', () {
    expect(
      () => UpdateManifest.fromJson(manifestJson(mandatory: false)),
      throwsFormatException,
    );
    final insecure = manifestJson()..['apkUrl'] = 'http://example.com/app.apk';
    expect(() => UpdateManifest.fromJson(insecure), throwsFormatException);
    expect(
      () => UpdateManifest.fromJson(manifestJson(hash: 'bad')),
      throwsFormatException,
    );
    expect(
      () => UpdateManifest.fromJson(
        manifestJson(versionCode: 10, minimumCode: 11),
      ),
      throwsFormatException,
    );
  });

  test('build number is authoritative and every newer release blocks', () {
    final manifest = UpdateManifest.fromJson(manifestJson(versionCode: 14));
    expect(
      AppUpdateState(
        manifest: manifest,
        installedVersionCode: 13,
      ).blocksStreaming,
      isTrue,
    );
    expect(
      AppUpdateState(
        manifest: manifest,
        installedVersionCode: 14,
      ).blocksStreaming,
      isFalse,
    );
    expect(
      AppUpdateState(
        manifest: manifest,
        installedVersionCode: 15,
      ).blocksStreaming,
      isFalse,
    );
  });
}
