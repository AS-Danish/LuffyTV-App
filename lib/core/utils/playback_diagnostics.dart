import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';

class PlaybackDiagnostics {
  static const _explicitlyEnabled = bool.fromEnvironment(
    'PLAYBACK_DIAGNOSTICS',
  );

  static bool get enabled => kDebugMode || _explicitlyEnabled;

  static String newRequestId([String prefix = 'app']) {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    return '${prefix}_${time}_$random';
  }

  static String host(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.startsWith('/')) return 'luffytv-api';
    return Uri.tryParse(raw)?.host.toLowerCase() ?? '';
  }

  static String safeError(Object? error) {
    final redacted = error.toString().replaceAllMapped(
      RegExp("https?://[^\\s\"']+"),
      (match) {
        final mediaHost = host(match.group(0));
        return mediaHost.isEmpty
            ? '<url-redacted>'
            : 'https://$mediaHost/<redacted>';
      },
    );
    return redacted.length <= 500 ? redacted : redacted.substring(0, 500);
  }

  static void log(
    String requestId,
    String event, [
    Map<String, Object?> details = const {},
  ]) {
    if (!enabled) return;
    final message = jsonEncode({
      'scope': 'flutter-app',
      'requestId': requestId,
      'event': event,
      'at': DateTime.now().toUtc().toIso8601String(),
      ...details,
    });
    developer.log('[PlaybackDiag] $message', name: 'LuffyTV.Playback');
    if (kDebugMode) debugPrint('[PlaybackDiag] $message');
  }
}
