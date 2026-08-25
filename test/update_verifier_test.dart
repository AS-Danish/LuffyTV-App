import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luffytv/update/update_manifest.dart';
import 'package:luffytv/update/update_verifier.dart';

UpdateManifest fixture(String hash, int size) => UpdateManifest.fromJson({
  'version': '1.1.0',
  'versionCode': 2,
  'minimumSupportedVersionCode': 2,
  'apkUrl': 'https://releases.example/app.apk',
  'sha256': hash,
  'apkSize': size,
  'mandatory': true,
});

void main() {
  test('streaming SHA-256 verification accepts an exact file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'luffy-update-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/app.apk');
    final bytes = List<int>.generate(4096, (index) => index % 251);
    await file.writeAsBytes(bytes);
    await const UpdateVerifier().verifyFile(
      file.path,
      fixture(sha256.convert(bytes).toString(), bytes.length),
    );
  });

  test('rejects size and checksum mismatches', () async {
    final directory = await Directory.systemTemp.createTemp(
      'luffy-update-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/app.apk');
    await file.writeAsBytes([1, 2, 3]);
    expect(
      () => const UpdateVerifier().verifyFile(
        file.path,
        fixture(List.filled(64, 'a').join(), 4),
      ),
      throwsA(isA<UpdateVerificationException>()),
    );
    expect(
      () => const UpdateVerifier().verifyFile(
        file.path,
        fixture(List.filled(64, 'a').join(), 3),
      ),
      throwsA(
        isA<UpdateVerificationException>().having(
          (error) => error.failure,
          'failure',
          VerificationFailure.checksumMismatch,
        ),
      ),
    );
  });
}
