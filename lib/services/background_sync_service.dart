import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../repositories/sync_repository.dart';
import 'activation_service.dart';
import 'license_gate_service.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'database_service.dart';
import 'pull_sync_apply_service.dart';
import 'runtime_config_service.dart';
import 'sync_backoff_policy.dart';
import 'sync_status_service.dart';

/// Coordinates outbox → NestJS sync upload.
class BackgroundSyncService {
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  static const int _defaultBatchLimit = 100;

  final SyncRepository _sync = SyncRepository.instance;
  final SyncBackoffPolicy _backoff = SyncBackoffPolicy();

  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  Timer? _scheduledRetryTimer;
  bool _initialized = false;
  bool _isRunning = false;
  bool _isSyncing = false;
  bool _isPulling = false;
  int _pendingCount = 0;

  /// Backoff / retry visibility for Sync Diagnostics.
  int get backoffFailureCount => _backoff.failureCount;
  bool get backoffExhausted => _backoff.exhausted;
  DateTime? get nextRetryAt => _backoff.nextRetryAt;
  Duration? get retryBackoffRemaining => _backoff.remainingDelay;
  bool get backoffIsReady => _backoff.isReady;

  /// `true` after [start] until [stop] / [dispose].
  bool get isRunning => _isRunning;

  /// `true` while [triggerSyncNow] is executing.
  bool get isSyncing => _isSyncing;

  /// `true` while [pullSyncNow] is executing.
  bool get isPulling => _isPulling;

  /// Last known count of pending outbox rows (from [refreshPendingCount] / sync pass).
  int get pendingCount => _pendingCount;

  /// Placeholder retry policy for a future upload loop.
  SyncBackoffPolicy get backoff => _backoff;

  /// Wires connectivity listener; does **not** start automatic sync.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await ConnectivityService.instance.initialize();
    _connectivitySub = ConnectivityService.instance.onStatusChanged.listen(
      _onConnectivityChanged,
    );
    await refreshPendingCount();
  }

  /// Enables connectivity-triggered [triggerSyncNow] and [pullSyncNow] when online.
  void start() {
    if (_isApiConfigBlocked()) {
      unawaited(_markApiConfigBlocked());
      return;
    }
    _isRunning = true;
    if (ConnectivityService.instance.isOnline) {
      _requestSyncWhenReady();
    }
  }

  /// Disables automatic sync triggers; in-flight [triggerSyncNow] may still finish.
  void stop() {
    _isRunning = false;
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _cancelScheduledRetry();
    _isRunning = false;
    _initialized = false;
  }

  /// Refreshes [pendingCount] from SQLite (no network).
  Future<void> refreshPendingCount() async {
    final pending = await _sync.getPendingOutboxEvents(limit: 1000);
    _pendingCount = pending.length;
  }

  /// Uploads pending outbox events to POST /sync/push and marks each
  /// event synced, failed, or duplicate based on the server response.
  ///
  /// Skipped when: offline, already syncing, or device not activated.
  ///
  /// If the server response is malformed the entire batch is treated as
  /// failed — no events are partially marked synced.
  ///
  /// Set [force] to `true` to bypass backoff (manual retry from diagnostics).
  Future<void> triggerSyncNow({bool force = false}) async {
    if (_isApiConfigBlocked()) {
      await _markApiConfigBlocked();
      return;
    }
    if (!ConnectivityService.instance.isOnline) {
      if (kDebugMode) debugPrint('BackgroundSyncService: skip (offline)');
      return;
    }
    if (!force && !_backoff.isReady) {
      if (kDebugMode) {
        debugPrint(
          'BackgroundSyncService: skip (backoff until ${_backoff.nextRetryAt})',
        );
      }
      _ensureRetryScheduled();
      return;
    }
    if (_isSyncing) {
      if (kDebugMode)
        debugPrint('BackgroundSyncService: skip (already syncing)');
      return;
    }
    if (!ActivationService.instance.isActivated) {
      if (kDebugMode) debugPrint('BackgroundSyncService: skip (not activated)');
      return;
    }
    if (LicenseGateService.instance.isBlocked) {
      if (kDebugMode)
        debugPrint('BackgroundSyncService: skip (license blocked)');
      return;
    }

    _isSyncing = true;
    SyncStatusService.instance.setSyncingPush(true);
    try {
      final pending = await _sync.getPendingOutboxEvents(
        limit: _defaultBatchLimit,
      );
      _pendingCount = pending.length;

      if (pending.isEmpty) {
        _backoff.reset();
        _cancelScheduledRetry();
        if (kDebugMode) debugPrint('BackgroundSyncService: no pending events');
        return;
      }

      // Decode payloadJson strings → objects so the server receives proper JSON.
      final events = pending.map((row) {
        final raw = row['payloadJson'] as String?;
        return <String, dynamic>{
          ...row,
          'payloadJson': raw != null ? jsonDecode(raw) : null,
        };
      }).toList();

      final body = {'events': events};

      Response<Map<String, dynamic>> response;
      try {
        response = await ApiClient.instance.post<Map<String, dynamic>>(
          kEndpointSyncPush,
          data: body,
        );
      } on DioException catch (e) {
        if (_handleLicenseSuspended(e)) return;
        if (e.response?.statusCode == 401) {
          // Access token expired — attempt one token refresh then retry.
          await _handleSyncUnauthorized();
          response = await ApiClient.instance.post<Map<String, dynamic>>(
            kEndpointSyncPush,
            data: body,
          );
        } else {
          rethrow;
        }
      }

      // Strict parsing — returns null if any field is missing or wrong type.
      final parsed = _parseSyncPushResponse(response.data);
      if (parsed == null) {
        _recordFailureAndSchedule(
          'Push: malformed server response',
        );
        if (kDebugMode) {
          debugPrint(
            'BackgroundSyncService: malformed response — batch failed, no events marked',
          );
        }
        return;
      }

      // Apply outbox state changes only after full parse succeeds.
      for (final uuid in [...parsed.accepted, ...parsed.duplicates]) {
        await _sync.markOutboxEventSynced(uuid);
      }
      for (final item in parsed.rejected) {
        await _sync.markOutboxEventFailed(item.uuid, item.reason);
      }

      final settled = parsed.accepted.length + parsed.duplicates.length;
      _pendingCount = (_pendingCount - settled).clamp(0, _pendingCount);
      _backoff.reset();
      _cancelScheduledRetry();

      final nowIso = DateTime.now().toIso8601String();
      await DatabaseService.instance.setAppMeta('sync_last_push_at', nowIso);
      await DatabaseService.instance.setAppMeta('sync_last_success_at', nowIso);
      await DatabaseService.instance.setAppMeta('sync_last_error', '');

      if (kDebugMode) {
        debugPrint(
          'BackgroundSyncService: push complete — '
          'accepted=${parsed.accepted.length} '
          'duplicates=${parsed.duplicates.length} '
          'rejected=${parsed.rejected.length}',
        );
      }
    } on DioException catch (e) {
      if (_handleLicenseSuspended(e)) return;
      _recordFailureAndSchedule(
        'Push network error: ${e.message ?? e.type.name}',
      );
      if (kDebugMode) debugPrint('BackgroundSyncService: network error: $e');
    } catch (e, st) {
      _recordFailureAndSchedule('Push error: ${e.runtimeType}');
      if (kDebugMode) debugPrint('BackgroundSyncService: sync error: $e\n$st');
    } finally {
      _isSyncing = false;
      SyncStatusService.instance.setSyncingPush(false);
      unawaited(SyncStatusService.instance.refresh());
    }
  }

  /// Downloads server-side changes via GET /sync/pull and applies them to
  /// local SQLite inside a single transaction.
  ///
  /// Skipped when: offline, already pulling, or device not activated.
  ///
  /// The pull cursor is persisted only after a successful SQLite commit so
  /// any failure leaves the cursor unchanged and the same batch is retried.
  Future<void> pullSyncNow({bool force = false}) async {
    if (_isApiConfigBlocked()) {
      await _markApiConfigBlocked();
      return;
    }
    if (!ConnectivityService.instance.isOnline) {
      if (kDebugMode) debugPrint('BackgroundSyncService: pull skip (offline)');
      return;
    }
    if (!force && !_backoff.isReady) {
      if (kDebugMode) {
        debugPrint(
          'BackgroundSyncService: pull skip (backoff until ${_backoff.nextRetryAt})',
        );
      }
      return;
    }
    if (_isPulling) {
      if (kDebugMode)
        debugPrint('BackgroundSyncService: pull skip (already pulling)');
      return;
    }
    if (!ActivationService.instance.isActivated) {
      if (kDebugMode)
        debugPrint('BackgroundSyncService: pull skip (not activated)');
      return;
    }
    if (LicenseGateService.instance.isBlocked) {
      if (kDebugMode)
        debugPrint('BackgroundSyncService: pull skip (license blocked)');
      return;
    }

    _isPulling = true;
    SyncStatusService.instance.setSyncingPull(true);
    try {
      final db = DatabaseService.instance;
      final cursor = await db.getPullCursor();

      final queryParams = <String, dynamic>{'limit': '200'};
      if (cursor != null && cursor.isNotEmpty) {
        queryParams['since'] = cursor;
      }

      Response<Map<String, dynamic>> response;
      try {
        response = await ApiClient.instance.get<Map<String, dynamic>>(
          kEndpointSyncPull,
          queryParameters: queryParams,
        );
      } on DioException catch (e) {
        if (_handleLicenseSuspended(e)) return;
        if (e.response?.statusCode == 401) {
          await _handleSyncUnauthorized();
          response = await ApiClient.instance.get<Map<String, dynamic>>(
            kEndpointSyncPull,
            queryParameters: queryParams,
          );
        } else {
          rethrow;
        }
      }

      final parsed = _parsePullResponse(response.data);
      if (parsed == null) {
        _recordFailureAndSchedule('Pull: malformed server response');
        if (kDebugMode) {
          debugPrint(
            'BackgroundSyncService: pull — malformed response, skipping',
          );
        }
        return;
      }

      final syncedAt = DateTime.now().toIso8601String();
      final rawDb = await db.database;

      late PullSyncApplyResult applyResult;
      await rawDb.transaction((txn) async {
        applyResult = await PullSyncApplyService.instance.applyEntities(
          parsed.entities,
          txn,
          syncedAt,
        );
      });

      // Cursor + timestamps persisted only after successful transaction commit.
      await db.setPullCursor(parsed.cursor);

      final nowIso = DateTime.now().toIso8601String();
      await db.setAppMeta('sync_last_pull_at', nowIso);
      await db.setAppMeta('sync_last_success_at', nowIso);
      await db.setAppMeta('sync_last_error', '');

      SyncStatusService.instance.markConflictSkips(applyResult.skipped);

      _backoff.reset();
      _cancelScheduledRetry();

      if (kDebugMode) {
        final counts = parsed.entities.values.fold(
          0,
          (sum, list) => sum + (list is List ? list.length : 0),
        );
        debugPrint(
          'BackgroundSyncService: pull complete — '
          'entities=$counts upserted=${applyResult.upserted} '
          'skipped=${applyResult.skipped} cursor=${parsed.cursor}',
        );
      }
    } on DioException catch (e) {
      if (_handleLicenseSuspended(e)) return;
      _recordFailureAndSchedule(
        'Pull network error: ${e.message ?? e.type.name}',
      );
      if (kDebugMode)
        debugPrint('BackgroundSyncService: pull network error: $e');
    } catch (e, st) {
      _recordFailureAndSchedule('Pull error: ${e.runtimeType}');
      if (kDebugMode) debugPrint('BackgroundSyncService: pull error: $e\n$st');
    } finally {
      _isPulling = false;
      SyncStatusService.instance.setSyncingPull(false);
      unawaited(SyncStatusService.instance.refresh());
    }
  }

  // ── Token refresh ─────────────────────────────────────────────────────────

  /// Called when the sync POST returns 401 (access token expired).
  ///
  /// Tries [ActivationService.refreshActivationToken] once.
  /// - On success: [ApiClient] is updated; the caller retries the sync request.
  /// - On 4xx server response (invalid/expired refresh token): calls
  ///   [ActivationService.revokeActivation] and rethrows so the outer catch
  ///   records a backoff failure.
  /// - On network error: rethrows as-is — activation is NOT revoked (offline
  ///   grace).
  Future<void> _handleSyncUnauthorized() async {
    try {
      await ActivationService.instance.refreshActivationToken();
    } on DioException catch (e) {
      if (_handleLicenseSuspended(e)) return;
      final statusCode = e.response?.statusCode;
      if (statusCode != null && statusCode >= 400 && statusCode < 500) {
        stop();
        SyncStatusService.instance.stop();
        await ActivationService.instance.handleRevokedByServer(
          reason: ActivationService.messageForRevocation(e),
        );
        if (kDebugMode) {
          debugPrint(
            'BackgroundSyncService: refresh rejected ($statusCode) — '
            'activation revoked, sync stopped',
          );
        }
      }
      rethrow;
    }
  }

  /// Returns `true` when sync should stop because the tenant is suspended.
  bool _handleLicenseSuspended(DioException error) {
    if (!LicenseGateService.isLicenseSuspendedError(error)) return false;
    LicenseGateService.instance.block();
    stop();
    _recordFailureAndSchedule('License suspended — sync paused');
    if (kDebugMode) {
      debugPrint('BackgroundSyncService: license suspended — sync paused');
    }
    return true;
  }

  // ── Response parsing ───────────────────────────────────────────────────────

  /// Strictly validates the /sync/push grouped response.
  ///
  /// Returns [null] if any required field is absent or the wrong type so the
  /// caller can treat the entire batch as failed without partial state changes.
  static _SyncPushResult? _parseSyncPushResponse(dynamic data) {
    if (data is! Map<String, dynamic>) return null;

    final acceptedRaw = data['accepted'];
    final duplicatesRaw = data['duplicates'];
    final rejectedRaw = data['rejected'];

    if (acceptedRaw is! List ||
        duplicatesRaw is! List ||
        rejectedRaw is! List) {
      return null;
    }

    final accepted = <String>[];
    for (final item in acceptedRaw) {
      if (item is! String) return null;
      accepted.add(item);
    }

    final duplicates = <String>[];
    for (final item in duplicatesRaw) {
      if (item is! String) return null;
      duplicates.add(item);
    }

    final rejected = <_SyncRejectedItem>[];
    for (final item in rejectedRaw) {
      if (item is! Map) return null;
      final uuid = item['uuid'];
      if (uuid is! String) return null;
      final reason = item['reason'];
      rejected.add(
        _SyncRejectedItem(
          uuid: uuid,
          reason: reason is String ? reason : 'rejected',
        ),
      );
    }

    return _SyncPushResult(
      accepted: accepted,
      duplicates: duplicates,
      rejected: rejected,
    );
  }

  /// Strictly validates the /sync/pull response.
  ///
  /// Returns [null] if the envelope is missing or [cursor] / [entities] are
  /// absent so the caller can bail out without advancing the stored cursor.
  static _SyncPullResult? _parsePullResponse(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final cursor = data['cursor'];
    if (cursor is! String || cursor.isEmpty) return null;
    final entitiesRaw = data['entities'];
    if (entitiesRaw is! Map<String, dynamic>) return null;
    return _SyncPullResult(cursor: cursor, entities: entitiesRaw);
  }

  void _onConnectivityChanged(ConnectivityStatus status) {
    if (!_isRunning) return;
    if (LicenseGateService.instance.isBlocked) return;
    if (status == ConnectivityStatus.online) {
      _requestSyncWhenReady();
    } else {
      _cancelScheduledRetry();
    }
  }

  /// Schedules push+pull when backoff allows (avoids immediate retry storms).
  void _requestSyncWhenReady({bool force = false}) {
    if (!_isRunning) return;
    if (_isApiConfigBlocked()) return;
    if (!ConnectivityService.instance.isOnline) return;
    if (LicenseGateService.instance.isBlocked) return;

    if (force || _backoff.isReady) {
      unawaited(_runScheduledSync(force: force));
      return;
    }
    _ensureRetryScheduled();
  }

  Future<void> _runScheduledSync({bool force = false}) async {
    if (!_isRunning) return;
    if (!ConnectivityService.instance.isOnline) return;
    await triggerSyncNow(force: force);
    if (!_isRunning) return;
    await pullSyncNow(force: force);
    await refreshPendingCount();
    unawaited(SyncStatusService.instance.refresh());
  }

  void _recordFailureAndSchedule(String errorMessage) {
    _backoff.recordFailure();
    unawaited(
      DatabaseService.instance.setAppMeta('sync_last_error', errorMessage),
    );
    _ensureRetryScheduled();
    unawaited(SyncStatusService.instance.refresh());
    if (kDebugMode) {
      debugPrint(
        'BackgroundSyncService: failure #${_backoff.failureCount} — '
        'next retry at ${_backoff.nextRetryAt}',
      );
    }
  }

  bool _isApiConfigBlocked() =>
      RuntimeConfigService.instance.isBlockedInRelease;

  Future<void> _markApiConfigBlocked() async {
    _cancelScheduledRetry();
    _backoff.reset();
    await DatabaseService.instance.setAppMeta(
      'sync_last_error',
      RuntimeConfigService.syncConfigErrorMessage,
    );
    unawaited(SyncStatusService.instance.refresh());
    if (kDebugMode) {
      debugPrint(
        'BackgroundSyncService: blocked — invalid production API config',
      );
    }
  }

  void _ensureRetryScheduled() {
    if (!_isRunning) return;
    if (_isApiConfigBlocked()) return;
    if (!ConnectivityService.instance.isOnline) return;
    if (LicenseGateService.instance.isBlocked) return;
    if (_backoff.isReady) return;

    final wait = _backoff.remainingDelay ?? _backoff.delayWithJitter;
    if (wait <= Duration.zero) {
      unawaited(_runScheduledSync());
      return;
    }

    _scheduledRetryTimer?.cancel();
    _scheduledRetryTimer = Timer(wait, () {
      _scheduledRetryTimer = null;
      unawaited(_runScheduledSync());
    });
  }

  void _cancelScheduledRetry() {
    _scheduledRetryTimer?.cancel();
    _scheduledRetryTimer = null;
  }

  /// Clears backoff state after operator resets failed events (manual retry).
  void resetBackoff() {
    _backoff.reset();
    _cancelScheduledRetry();
  }
}

// ── Private parse result types ────────────────────────────────────────────────

class _SyncPullResult {
  const _SyncPullResult({required this.cursor, required this.entities});
  final String cursor;
  final Map<String, dynamic> entities;
}

class _SyncPushResult {
  const _SyncPushResult({
    required this.accepted,
    required this.duplicates,
    required this.rejected,
  });

  final List<String> accepted;
  final List<String> duplicates;
  final List<_SyncRejectedItem> rejected;
}

class _SyncRejectedItem {
  const _SyncRejectedItem({required this.uuid, required this.reason});
  final String uuid;
  final String reason;
}
