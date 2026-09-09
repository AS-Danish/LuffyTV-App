import 'package:flutter_test/flutter_test.dart';
import 'package:luffytv/core/services/download_validation.dart';

void main() {
  test('rejects seven minutes of a twenty-four minute episode', () {
    expect(
      () => validateDownloadedVideo(
        expectedSeconds: 1440,
        videoSeconds: 420,
        fileBytes: 1000000,
      ),
      throwsStateError,
    );
  });
  test('accepts a complete short episode with minor timestamp differences', () {
    validateDownloadedVideo(
      expectedSeconds: 180,
      videoSeconds: 179,
      fileBytes: 1000,
    );
  });
  test('rejects missing video duration even if the container has audio', () {
    expect(
      () => validateDownloadedVideo(
        expectedSeconds: 1440,
        videoSeconds: null,
        fileBytes: 1000000,
      ),
      throwsStateError,
    );
  });
  test('rejects empty or invalid output', () {
    for (final duration in [0.0, double.nan, double.infinity]) {
      expect(
        () => validateDownloadedVideo(
          expectedSeconds: 1440,
          videoSeconds: duration,
          fileBytes: 1000,
        ),
        throwsStateError,
      );
    }
    expect(
      () => validateDownloadedVideo(
        expectedSeconds: 1440,
        videoSeconds: 1440,
        fileBytes: 0,
      ),
      throwsStateError,
    );
  });
}
