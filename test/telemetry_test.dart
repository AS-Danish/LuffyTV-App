import 'package:flutter_test/flutter_test.dart';
import 'package:luffytv/core/services/telemetry_reporter.dart';
import 'package:luffytv/core/services/telemetry_sanitizer.dart';

class MemorySink implements TelemetrySink {
  final reports = <TelemetryReport>[];
  bool fail = false;
  @override
  Future<void> record(TelemetryReport report) async {
    if (fail) throw StateError('Reporting unavailable');
    reports.add(report);
  }
}

void main() {
  test('categorizes sensitive failures without retaining their values', () {
    expect(
      TelemetrySanitizer.category('Decryption failed: secret=hidden'),
      'decryption',
    );
    expect(TelemetrySanitizer.category('URL signature expired'), 'signed_url');
    expect(TelemetrySanitizer.category('HTTP 403'), 'authorization');
    expect(TelemetrySanitizer.category('Socket timeout'), 'network');
    expect(
      TelemetrySanitizer.text('Cookie: a=SECRET123; b=SECRET456'),
      isNot(contains('SECRET')),
    );
  });
  test('redacts URLs, encoded URLs, auth, keys, nonce and tokens', () {
    for (final input in [
      '403 https://cdn.example/secret/path?sig=SECRET123',
      '403 https%3A%2F%2Fcdn.example%2Fsecret%3Fsig%3DSECRET123',
      'Authorization: Bearer SECRET123',
      'token=SECRET123',
      'decryption_key: SECRET123',
      '{"secret":"SECRET123", "nonce":"SECRET123"}',
      'encrypted_data=SECRET123',
      'Cookie: SECRET123',
    ]) {
      final safe = TelemetrySanitizer.text(input);
      expect(safe, isNot(contains('SECRET123')), reason: input);
      expect(safe, isNot(contains('/secret/path')));
    }
  });

  test('unknown context and nested request data cannot escape', () {
    final safe = TelemetrySanitizer.context({
      'host': 'cdn.example',
      'status': 403,
      'token': 'SECRET',
      'headers': {'Authorization': 'SECRET'},
      'url': 'SECRET',
      'decryptionKey': 'SECRET',
      'requestId': 'player_123',
    });
    expect(safe, {
      'host': 'cdn.example',
      'status': 403,
      'requestId': 'player_123',
    });
  });

  test(
    'buffers early failures, bounds queue and deduplicates repeated errors',
    () async {
      final reporter = TelemetryReporter(capacity: 2);
      reporter.report('old', 'one');
      reporter.report('download.failed', 'token=SECRET');
      reporter.report('download.failed', 'token=SECRET');
      reporter.report('new', 'three');
      final sink = MemorySink();
      reporter.attach(sink);
      await Future<void>.delayed(Duration.zero);
      await reporter.flush();
      expect(sink.reports.map((e) => e.event), ['download.failed', 'new']);
      expect(sink.reports.first.message, isNot(contains('SECRET')));
    },
  );

  test('reporting errors are isolated and future reports still work', () async {
    final reporter = TelemetryReporter();
    final sink = MemorySink()..fail = true;
    reporter.attach(sink);
    reporter.report('failed', 'first');
    await reporter.flush();
    sink.fail = false;
    reporter.report('recovered', 'second');
    await reporter.flush();
    expect(sink.reports.single.event, 'recovered');
  });

  test('preserves sanitized stack and fatal status', () async {
    final reporter = TelemetryReporter();
    reporter.report(
      'uncaught',
      'secret=SECRET',
      fatal: true,
      stack: StackTrace.fromString('#0 foo (package:luffytv/main.dart:12:3)'),
    );
    final sink = MemorySink();
    reporter.attach(sink);
    await Future<void>.delayed(Duration.zero);
    expect(sink.reports.single.fatal, true);
    expect(sink.reports.single.stack.toString(), contains('main.dart:12:3'));
  });
}
