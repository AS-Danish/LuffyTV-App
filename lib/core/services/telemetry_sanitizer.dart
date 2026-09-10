/// Only safe diagnostic context is exported. Request bodies, headers and media
/// credentials are deliberately not accepted as context fields.
class TelemetrySanitizer {
  static String category(Object? error) {
    final message = error.toString().toLowerCase();
    if (RegExp(
      r'decrypt|cipher|nonce|encryption|invalid key',
    ).hasMatch(message)) {
      return 'decryption';
    }
    if (RegExp(r'expired|expiry|signature').hasMatch(message)) {
      return 'signed_url';
    }
    if (RegExp(
      r'\b40[13]\b|unauthori[sz]ed|forbidden|token',
    ).hasMatch(message)) {
      return 'authorization';
    }
    if (RegExp(r'timeout|timed out|socket|network').hasMatch(message)) {
      return 'network';
    }
    return 'application';
  }

  static const _allowed = {
    'requestId',
    'server',
    'type',
    'host',
    'status',
    'attempt',
    'elapsedMs',
    'positionSeconds',
    'episode',
    'local',
    'proxied',
    'sourceCount',
    'playableCount',
    'captionCount',
    'bytes',
    'forceRefresh',
    'stage',
    'returnCode',
    'failedCount',
    'durationMs',
    'recovery',
    'category',
  };

  static Map<String, Object> context(Map<String, Object?> values) => {
    for (final entry in values.entries)
      if (_allowed.contains(entry.key) && entry.value != null)
        entry.key: entry.value is num || entry.value is bool
            ? entry.value!
            : text(entry.value, limit: 160),
  };

  static String text(Object? value, {int limit = 1000}) {
    var result = value.toString();
    // Handle encoded URLs and credentials embedded in plugin error messages.
    for (var i = 0; i < 2 && result.contains('%'); i++) {
      try {
        result = Uri.decodeComponent(result);
      } catch (_) {
        break;
      }
    }
    result = result.replaceAll(
      RegExp(r'https?://[^\s"\x27<>]+', caseSensitive: false),
      '<url-redacted>',
    );
    result = result.replaceAll(
      RegExp(r'\b(?:Bearer|Basic)\s+[^\s,;]+', caseSensitive: false),
      '<auth-redacted>',
    );
    result = result.replaceAll(
      RegExp(r'\b(?:cookie|set-cookie)\s*[:=][^\r\n]*', caseSensitive: false),
      '<cookie-redacted>',
    );
    result = result.replaceAllMapped(
      RegExp(
        r'''["']?\b(?:authorization|cookie|set-cookie|access[_-]?token|refresh[_-]?token|token|api[_-]?key|decryption[ _-]?key|key|secret|nonce|iv|encrypted[_-]?data|signature|sig)["']?\s*[:=]\s*(?:"[^"\n]*"|'[^'\n]*'|[^\s,;}]+)''',
        caseSensitive: false,
      ),
      (_) => '<credential-redacted>',
    );
    result = result.replaceAll(
      RegExp(r'\b[a-fA-F0-9]{32,}\b'),
      '<hex-value-redacted>',
    );
    result = result.replaceAll(
      RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'),
      '<jwt-redacted>',
    );
    result = result.replaceAll(
      RegExp(r'\b[A-Za-z0-9_+/=-]{40,}\b'),
      '<opaque-value-redacted>',
    );
    result = result.replaceAll(
      RegExp(r'\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b'),
      '<email-redacted>',
    );
    return result.length > limit ? result.substring(0, limit) : result;
  }
}
