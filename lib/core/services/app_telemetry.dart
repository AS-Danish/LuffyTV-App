import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'telemetry_reporter.dart';
import 'telemetry_sanitizer.dart';

class _CrashlyticsSink implements TelemetrySink {
  @override
  Future<void> record(TelemetryReport report) async {
    final crashlytics = FirebaseCrashlytics.instance;
    // The reporter serializes this block. Reset absent values to avoid leaking
    // context from a previous episode or a simultaneous download into an issue.
    await Future.wait([
      for (final key in ['category', 'host', 'server', 'requestId', 'stage'])
        crashlytics.setCustomKey(key, report.context[key] ?? 'unknown'),
    ]);
    await crashlytics.recordError(
      report.event,
      report.stack,
      reason: report.message,
      information: [jsonEncode(report.context)],
      fatal: report.fatal,
      printDetails: false,
    );
  }
}

class AppTelemetry {
  static final reporter = TelemetryReporter();
  static const enabled = bool.fromEnvironment(
    'ERROR_REPORTING',
    defaultValue: kReleaseMode,
  );
  static bool _ready = false;
  static bool _performanceReady = false;
  static bool _initializing = false;
  static int _metricsPending = 0;
  static int _breadcrumbsPending = 0;

  static Future<void> initialize() async {
    if (_initializing ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _initializing = true;
    try {
      await Firebase.initializeApp(); // Android google-services.json resources.
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        enabled,
      );
      if (!enabled) {
        try {
          await FirebasePerformance.instance.setPerformanceCollectionEnabled(
            false,
          );
        } catch (_) {}
        return;
      }
      _ready = true;
      reporter.attach(_CrashlyticsSink());
      try {
        await FirebasePerformance.instance.setPerformanceCollectionEnabled(
          true,
        );
        _performanceReady = true;
      } catch (_) {
        /* Crash reporting remains available without performance. */
      }
      if (const bool.fromEnvironment('TELEMETRY_SMOKE_TEST')) {
        report(
          'telemetry.smoke_test',
          'Deliberate non-fatal integration test',
          stack: StackTrace.current,
        );
      }
    } catch (_) {
      // Missing configuration / offline initialization must not prevent launch.
      if (kDebugMode) debugPrint('Telemetry initialization unavailable.');
    }
  }

  static void report(
    String event,
    Object? error, {
    StackTrace? stack,
    Map<String, Object?> context = const {},
    bool fatal = false,
  }) {
    if (!enabled) return;
    reporter.report(event, error, stack: stack, context: context, fatal: fatal);
  }

  static void event(
    String requestId,
    String event,
    Map<String, Object?> details,
  ) {
    final safe = TelemetrySanitizer.context({
      'requestId': requestId,
      ...details,
    });
    if (event.endsWith('_failed') ||
        event.endsWith('_error') ||
        event.endsWith('_exhausted')) {
      report(event, details['error'] ?? event, context: safe);
    }
    if (!_ready || _breadcrumbsPending >= 16) return;
    _breadcrumbsPending++;
    Timer.run(() async {
      try {
        await FirebaseCrashlytics.instance.log(
          jsonEncode({'event': event, ...safe}),
        );
      } catch (_) {
      } finally {
        _breadcrumbsPending--;
      }
    });
  }

  /// Measured locally with a Stopwatch; SDK trace duration is export time.
  /// Inspect the duration_ms custom metric, not the trace's default duration.
  static void duration(String name, int milliseconds, {String? server}) {
    if (!_performanceReady || _metricsPending >= 8) return;
    _metricsPending++;
    Timer.run(() async {
      Trace? trace;
      try {
        trace = FirebasePerformance.instance.newTrace(name);
        await trace.start();
        trace.setMetric('duration_ms', milliseconds);
        trace.setMetric('over_two_seconds', milliseconds > 2000 ? 1 : 0);
        if (server != null) {
          trace.putAttribute(
            'server',
            TelemetrySanitizer.text(server, limit: 80),
          );
        }
      } catch (_) {
      } finally {
        try {
          await trace?.stop();
        } catch (_) {}
        _metricsPending--;
      }
    });
  }
}
