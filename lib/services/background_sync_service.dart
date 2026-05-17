import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../repositories/sync_repository.dart';
import 'connectivity_service.dart';

/// Coordinates future outbox → NestJS upload (dry-run skeleton only).
class BackgroundSyncService {
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  static const int _defaultBatchLimit = 100;

  final SyncRepository _sync = SyncRepository.instance;
  final SyncBackoffPolicy _backoff = SyncBackoffPolicy();

  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  bool _initialized = false;
  bool _isRunning = false;
  bool _isSyncing = false;
  int _pendingCount = 0;

  /// `true` after [start] until [stop] / [dispose].
  bool get isRunning => _isRunning;

  /// `true` while [triggerSyncNow] is executing.
  bool get isSyncing => _isSyncing;

  /// Last known count of pending outbox rows (from [refreshPendingCount] / sync pass).
  int get pendingCount => _pendingCount;

  /// Placeholder retry policy for a future upload loop.
  SyncBackoffPolicy get backoff => _backoff;

  /// Wires connectivity listener; does **not** start automatic sync.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await ConnectivityService.instance.initialize();
    _connectivitySub =
        ConnectivityService.instance.onStatusChanged.listen(
      _onConnectivityChanged,
    );
    await refreshPendingCount();
  }

  /// Enables connectivity-triggered [triggerSyncNow] when online.
  void start() {
    _isRunning = true;
    if (ConnectivityService.instance.isOnline) {
      unawaited(triggerSyncNow());
    }
  }

  /// Disables automatic sync triggers; in-flight [triggerSyncNow] may still finish.
  void stop() {
    _isRunning = false;
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _isRunning = false;
    _initialized = false;
  }

  /// Refreshes [pendingCount] from SQLite (no network).
  Future<void> refreshPendingCount() async {
    final pending = await _sync.getPendingOutboxEvents(limit: 1000);
    _pendingCount = pending.length;
  }

  /// Dry-run sync pass: reads pending outbox rows only (no API, no mark synced).
  Future<void> triggerSyncNow() async {
    if (!ConnectivityService.instance.isOnline) {
      if (kDebugMode) {
        debugPrint('BackgroundSyncService: skip sync (offline)');
      }
      return;
    }
    if (_isSyncing) {
      if (kDebugMode) {
        debugPrint('BackgroundSyncService: skip sync (already syncing)');
      }
      return;
    }

    _isSyncing = true;
    try {
      final pending =
          await _sync.getPendingOutboxEvents(limit: _defaultBatchLimit);
      _pendingCount = pending.length;

      if (pending.isEmpty) {
        _backoff.reset();
        if (kDebugMode) {
          debugPrint('BackgroundSyncService: no pending outbox events');
        }
        return;
      }

      // Placeholder: real upload would iterate [pending] with [_backoff] delays.
      if (kDebugMode) {
        debugPrint(
          'BackgroundSyncService: would sync $_pendingCount outbox event(s) '
          '(upload disabled; next retry delay ${_backoff.currentDelay})',
        );
      }
    } catch (e, st) {
      _backoff.recordFailure();
      if (kDebugMode) {
        debugPrint('BackgroundSyncService: sync pass error: $e\n$st');
      }
    } finally {
      _isSyncing = false;
    }
  }

  void _onConnectivityChanged(ConnectivityStatus status) {
    if (!_isRunning) return;
    if (status == ConnectivityStatus.online) {
      unawaited(triggerSyncNow());
    }
  }
}

/// Exponential backoff placeholder — not used for real uploads yet.
class SyncBackoffPolicy {
  static const int maxAttempts = 5;
  static const Duration baseDelay = Duration(seconds: 2);

  int _failureCount = 0;

  int get failureCount => _failureCount;

  Duration get currentDelay {
    if (_failureCount <= 0) return Duration.zero;
    final exponent = math.min(_failureCount - 1, 8);
    return baseDelay * (1 << exponent);
  }

  void reset() => _failureCount = 0;

  void recordFailure() {
    if (_failureCount < maxAttempts) {
      _failureCount++;
    }
  }

  bool get exhausted => _failureCount >= maxAttempts;
}
