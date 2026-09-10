import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../services/app_telemetry.dart';
import '../services/telemetry_sanitizer.dart';

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
    return TelemetrySanitizer.text(error, limit: 500);
  }

  static void log(
    String requestId,
    String event, [
    Map<String, Object?> details = const {},
  ]) {
    AppTelemetry.event(requestId, event, details);
    if (event == 'player.first_frame' ||
        event == 'player.first_progress' ||
        event == 'api.response_received') {
      final elapsed = details['elapsedMs'];
      if (elapsed is int) {
        AppTelemetry.duration(
          event.replaceAll('.', '_'),
          elapsed,
          server: details['server'] as String?,
        );
      }
    }
    if (!enabled) return;
    final message = jsonEncode({
      'scope': 'flutter-app',
      'requestId': requestId,
      'event': event,
      'at': DateTime.now().toUtc().toIso8601String(),
      ...TelemetrySanitizer.context(details),
      if (details['error'] != null) 'error': safeError(details['error']),
    });
    developer.log('[PlaybackDiag] $message', name: 'LuffyTV.Playback');
    if (kDebugMode) debugPrint('[PlaybackDiag] $message');
  }
}
