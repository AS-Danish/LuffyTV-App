import 'dart:async';
import 'dart:convert';
import 'package:hive/hive.dart';

/// Public catalog JSON only. Signed media URLs and account data never go here.
class CatalogCache {
  static const boxName = 'catalog_cache_v1';
  final Box<String>? _box;
  final DateTime Function() _now;
  final _pending = <String, Future<Map<String, dynamic>>>{};

  CatalogCache({Box<String>? box, DateTime Function()? now})
    : _box =
          box ?? (Hive.isBoxOpen(boxName) ? Hive.box<String>(boxName) : null),
      _now = now ?? DateTime.now;

  static Future<void> init() async {
    try {
      await Hive.openBox<String>(boxName);
    } catch (_) {
      // A cache/storage failure must not stop app startup.
    }
  }

  static Duration? freshness(Uri uri) {
    if (uri.path == '/api/home') return const Duration(minutes: 5);
    if (RegExp(r'^/api/anime/[^/]+/episodes$').hasMatch(uri.path)) {
      return const Duration(minutes: 10);
    }
    if (RegExp(r'^/api/anime/[^/]+$').hasMatch(uri.path)) {
      return const Duration(minutes: 30);
    }
    return null;
  }

  bool hasUsableHome(Uri uri) {
    try {
      final raw = _box?.get(uri.toString());
      if (raw == null) return false;
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final age = _now().difference(
        DateTime.fromMillisecondsSinceEpoch(envelope['at'] as int),
      );
      return !age.isNegative &&
          age < const Duration(days: 7) &&
          envelope['payload']?['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> get(
    Uri uri,
    Future<Map<String, dynamic>> Function() load, {
    void Function()? onUpdated,
    bool forceRefresh = false,
  }) async {
    final ttl = freshness(uri);
    if (_box == null || ttl == null) return load();
    final key = uri.toString(); // Also isolates caches when API hosts change.
    Map<String, dynamic>? cached;
    var age = const Duration(days: 8);
    try {
      final raw = _box.get(key);
      if (raw != null) {
        final envelope = jsonDecode(raw) as Map<String, dynamic>;
        age = _now().difference(
          DateTime.fromMillisecondsSinceEpoch(envelope['at'] as int),
        );
        final payload = envelope['payload'];
        if (!age.isNegative &&
            payload is Map<String, dynamic> &&
            payload['ok'] == true &&
            payload['data'] is Map) {
          cached = payload;
        }
      }
    } catch (_) {
      // Malformed/older cache entries are ordinary misses.
    }
    if (!forceRefresh && cached != null && age < ttl) return cached;
    final usable =
        !forceRefresh && cached != null && age < const Duration(days: 7);
    final existing = _pending[key];
    if (existing != null) return usable ? cached : existing;

    late final Future<Map<String, dynamic>> request;
    request = Future.sync(load)
        .then((value) async {
          if (value['ok'] != true || value['data'] is! Map<String, dynamic>) {
            throw Exception('Anime service returned invalid catalog data.');
          }
          try {
            final raw = jsonEncode({
              'at': _now().millisecondsSinceEpoch,
              'payload': value,
            });
            if (raw.length <= 512000) {
              await _box.put(key, raw);
              // Bound disk usage to approximately 8 MB of string data / 80 records.
              var size = _box.values.fold<int>(
                0,
                (sum, item) => sum + item.length,
              );
              for (final oldKey in _box.keys.toList()) {
                if (_box.length <= 80 && size <= 4000000) break;
                size -= _box.get(oldKey)?.length ?? 0;
                await _box.delete(oldKey);
              }
            }
          } catch (_) {
            // Saving is best effort; a valid network response is still usable.
          }
          if (usable && jsonEncode(cached) != jsonEncode(value)) {
            onUpdated?.call();
          }
          return value;
        })
        .whenComplete(() {
          _pending.remove(key);
        });
    _pending[key] = request;
    if (usable) {
      unawaited(request.then<void>((_) {}, onError: (Object _) {}));
      return cached;
    }
    return request;
  }
}
