/// Validate the video stream, since full-length audio can mask truncated video.
void validateDownloadedVideo({
  required double expectedSeconds,
  required double? videoSeconds,
  required int fileBytes,
}) {
  if (!expectedSeconds.isFinite ||
      expectedSeconds <= 0 ||
      videoSeconds == null ||
      !videoSeconds.isFinite ||
      videoSeconds <= 0 ||
      fileBytes <= 0) {
    throw StateError(
      'Downloaded video could not be verified. Please download again.',
    );
  }
  // Allow small timestamp/rounding differences, never minutes of missing video.
  final tolerance = (expectedSeconds * 0.01).clamp(2.0, 10.0);
  if (videoSeconds < expectedSeconds - tolerance) {
    throw StateError(
      'Download is incomplete. Please download the episode again.',
    );
  }
}
