import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:luffytv/core/utils/api_constants.dart';

typedef InternetProbe = Future<bool> Function();

class NetworkMonitor extends ChangeNotifier {
  final Connectivity _connectivity;
  final InternetProbe _probe;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _offlineRetry;
  bool _started = false;
  bool _checking = false;
  bool? _online;
  int _checkGeneration = 0;

  NetworkMonitor({Connectivity? connectivity, InternetProbe? probe})
    : _connectivity = connectivity ?? Connectivity(),
      _probe = probe ?? _probeApiHost;

  bool get hasChecked => _online != null;
  bool get isOffline => _online == false;
  bool get isOnline => _online == true;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) => unawaited(_evaluate(results)),
    );
    await refresh();
  }

  Future<void> refresh() async {
    if (_checking) return;
    _checking = true;
    try {
      await _evaluate(await _connectivity.checkConnectivity());
    } catch (_) {
      _setOnline(false);
    } finally {
      _checking = false;
    }
  }

  Future<void> _evaluate(List<ConnectivityResult> results) async {
    final generation = ++_checkGeneration;
    if (results.isEmpty ||
        results.every((item) => item == ConnectivityResult.none)) {
      _setOnline(false);
      return;
    }
    final reachable = await _probe();
    if (generation == _checkGeneration) _setOnline(reachable);
  }

  void _setOnline(bool online) {
    final changed = _online != online;
    _online = online;
    if (online) {
      _offlineRetry?.cancel();
      _offlineRetry = null;
    } else {
      _offlineRetry ??= Timer(const Duration(seconds: 15), () {
        _offlineRetry = null;
        unawaited(refresh());
      });
    }
    if (changed) notifyListeners();
  }

  static Future<bool> _probeApiHost() async {
    Socket? socket;
    try {
      final uri = Uri.parse(ApiConstants.baseUrl);
      socket = await Socket.connect(
        uri.host,
        uri.hasPort ? uri.port : (uri.scheme == 'http' ? 80 : 443),
        timeout: const Duration(seconds: 4),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  @override
  void dispose() {
    _offlineRetry?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
