import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Online/offline state for future sync (no upload logic yet).
enum ConnectivityStatus {
  online,
  offline,
}

/// Lightweight network presence via [connectivity_plus].
///
/// Reports **link-level** connectivity (Wi‑Fi / Ethernet / mobile), not whether
/// a specific API host is reachable.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  ConnectivityStatus _status = ConnectivityStatus.offline;
  bool _initialized = false;

  /// Current link status (defaults to [ConnectivityStatus.offline] until [initialize]).
  ConnectivityStatus get status => _status;

  /// `true` when Wi‑Fi, Ethernet, or mobile is available.
  bool get isOnline => _status == ConnectivityStatus.online;

  /// Emits only when [status] changes.
  Stream<ConnectivityStatus> get onStatusChanged => _statusController.stream;

  /// Idempotent — call once during app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final results = await _connectivity.checkConnectivity();
      _applyResults(results);
    } catch (_) {
      _applyResults([ConnectivityResult.none]);
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      _applyResults,
      onError: (_) => _applyResults([ConnectivityResult.none]),
    );
  }

  /// Cancels platform listener. Safe if [initialize] was never called.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }

  static bool _resultsIndicateOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    for (final r in results) {
      if (r == ConnectivityResult.none) continue;
      if (r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.mobile) {
        return true;
      }
    }
    return false;
  }

  void _applyResults(List<ConnectivityResult> results) {
    final next = _resultsIndicateOnline(results)
        ? ConnectivityStatus.online
        : ConnectivityStatus.offline;
    if (next == _status) return;

    _status = next;
    if (kDebugMode) {
      debugPrint('ConnectivityService: ${next.name}');
    }
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }
}
