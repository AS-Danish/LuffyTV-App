import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// A dedicated, long-lived disk cache for poster and backdrop artwork.
///
/// The default image cache only retains 200 files. Anime catalogs exceed that
/// quickly, which made already-viewed artwork download again after navigation.
class ArtworkCache {
  ArtworkCache._();

  static final CacheManager instance = CacheManager(
    Config(
      'luffytvArtworkV1',
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 800,
    ),
  );

  static ImageProvider provider(String url) =>
      CachedNetworkImageProvider(url, cacheManager: instance);

  static Future<void> prefetch(Iterable<String?> candidates) async {
    final urls = candidates
        .whereType<String>()
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    var cursor = 0;

    Future<void> worker() async {
      while (cursor < urls.length) {
        final url = urls[cursor++];
        try {
          await instance.getSingleFile(url);
        } catch (_) {
          // The visible widget keeps its normal fallback if prefetching fails.
        }
      }
    }

    final workerCount = urls.length < 4 ? urls.length : 4;
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }
}

/// Displays cached full-resolution artwork while using the API thumbnail as an
/// immediate fallback until the upgraded image is ready.
class CachedArtworkImage extends StatelessWidget {
  final String imageUrl;
  final String? previewUrl;
  final BoxFit fit;
  final Alignment alignment;
  final Widget Function(BuildContext context)? fallbackBuilder;

  const CachedArtworkImage({
    super.key,
    required this.imageUrl,
    this.previewUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fallbackBuilder,
  });

  bool get _hasSeparatePreview {
    final preview = previewUrl?.trim();
    return preview != null && preview.isNotEmpty && preview != imageUrl;
  }

  Widget _fallback(BuildContext context) =>
      fallbackBuilder?.call(context) ?? const SizedBox.shrink();

  Widget _preview(BuildContext context) {
    if (!_hasSeparatePreview) return _fallback(context);
    return CachedNetworkImage(
      imageUrl: previewUrl!,
      cacheManager: ArtworkCache.instance,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      fadeInDuration: Duration.zero,
      errorWidget: (context, _, _) => _fallback(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: ArtworkCache.instance,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      useOldImageOnUrlChange: true,
      fadeInDuration: const Duration(milliseconds: 140),
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholder: (context, _) => _preview(context),
      errorWidget: (context, _, _) => _preview(context),
    );
  }
}
