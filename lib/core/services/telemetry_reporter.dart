import 'dart:async';
import 'dart:collection';
import 'telemetry_sanitizer.dart';

class TelemetryReport {
  final String event;
  final String message;
  final StackTrace? stack;
  final Map<String, Object> context;
  final bool fatal;
  const TelemetryReport(
    this.event,
    this.message,
    this.stack,
    this.context,
    this.fatal,
  );
}

abstract interface class TelemetrySink {
  Future<void> record(TelemetryReport report);
}

/// Bounded, deduplicated reporting. Callers never await the reporting SDK.
class TelemetryReporter {
  final int capacity;
  final DateTime Function() now;
  final Queue<TelemetryReport> _pending = Queue();
  final Map<String, DateTime> _recent = {};
  TelemetrySink? _sink;
  bool _draining = false;
  bool _scheduled = false;
  TelemetryReporter({this.capacity = 32, DateTime Function()? now})
    : now = now ?? DateTime.now;

  void attach(TelemetrySink sink) {
    _sink = sink;
    unawaited(flush());
  }

  void report(
    String event,
    Object? error, {
    StackTrace? stack,
    Map<String, Object?> context = const {},
    bool fatal = false,
  }) {
    final safeEvent = TelemetrySanitizer.text(event, limit: 80);
    final message = TelemetrySanitizer.text(error);
    final stamp = now();
    _recent.removeWhere(
      (_, time) => stamp.difference(time) >= const Duration(minutes: 5),
    );
    final key = '$safeEvent|$message';
    if (!fatal && _recent.containsKey(key)) return;
    if (_recent.length >= 128) _recent.remove(_recent.keys.first);
    _recent[key] = stamp;
    if (_pending.length >= capacity) _pending.removeFirst();
    final item = TelemetryReport(
      safeEvent,
      message,
      stack == null
          ? null
          : StackTrace.fromString(TelemetrySanitizer.text(stack, limit: 8000)),
      TelemetrySanitizer.context({
        'category': TelemetrySanitizer.category(error),
        ...context,
      }),
      fatal,
    );
    if (fatal) {
      _pending.addFirst(item);
    } else {
      _pending.addLast(item);
    }
    // Schedule on the event queue, avoiding SDK work in a player callback.
    if (!_scheduled) {
      _scheduled = true;
      Timer.run(() {
        _scheduled = false;
        unawaited(flush());
      });
    }
  }

  Future<void> flush() async {
    if (_draining || _sink == null) return;
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final report = _pending.removeFirst();
        try {
          await _sink!.record(report);
        } catch (_) {
          /* Reporting failures must never affect the app. */
        }
      }
    } finally {
      _draining = false;
    }
  }
}
