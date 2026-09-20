import 'dart:async';

import 'package:flutter/foundation.dart';

import 'activation_service.dart';
import 'connectivity_service.dart';
import 'database_service.dart';

/// Aggregates sync health state and broadcasts it to UI via [ChangeNotifier].
///
/// [BackgroundSyncService] drives this via [setSyncingPush], [setSyncingPull],
/// and [markConflictSkips] rather than the other direction — avoiding circular
/// imports. DB counts and persisted timestamps are refreshed every 10 seconds
/// and on demand via [refresh].
class SyncStatusService extends ChangeNotifier {
  SyncStatusService._();
  static final SyncStatusService instance = SyncStatusService._();

  Timer? _pollTimer;
  StreamSubscription<ConnectivityStatus>? _connectivitySub;

  // ── Live flags (set directly by BackgroundSyncService) ────────────────────
  bool isSyncingPush = false;
  bool isSyncingPull = false;

  // ── Polled state ──────────────────────────────────────────────────────────
  bool isOnline = false;
  int pendingOutboxCount = 0;
  int failedOutboxCount = 0;

  // ── Persisted timestamps (from app_meta) ──────────────────────────────────
  String? lastPushAt;
  String? lastPullAt;
  String? lastSuccessAt;
  String? lastSyncError;
  String? pullCursor;

  // ── Activation state ──────────────────────────────────────────────────────
  bool isActivated = false;
  String? businessId;
  String? branchId;
  String? deviceId;

  // ── Session-level conflict tracking ───────────────────────────────────────
  int sessionConflictSkips = 0;

  // ── Computed helpers ──────────────────────────────────────────────────────
  bool get isSyncing  => isSyncingPush || isSyncingPull;
  bool get hasFailed  => failedOutboxCount > 0;
  bool get hasPending => pendingOutboxCount > 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void start() {
    isOnline = ConnectivityService.instance.isOnline;
    _connectivitySub =
        ConnectivityService.instance.onStatusChanged.listen((s) {
      isOnline = s == ConnectivityStatus.online;
      notifyListeners();
    });
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(refresh()),
    );
    unawaited(refresh());
  }

  void stop() {
    _pollTimer?.cancel();
    _connectivitySub?.cancel();
    _pollTimer = null;
    _connectivitySub = null;
  }

  // ── Setters called by BackgroundSyncService ───────────────────────────────

  void setSyncingPush(bool value) {
    if (isSyncingPush == value) return;
    isSyncingPush = value;
    notifyListeners();
  }

  void setSyncingPull(bool value) {
    if (isSyncingPull == value) return;
    isSyncingPull = value;
    notifyListeners();
  }

  void markConflictSkips(int count) {
    if (count <= 0) return;
    sessionConflictSkips += count;
    notifyListeners();
  }

  // ── Refresh (reads DB + activation state) ─────────────────────────────────

  Future<void> refresh() async {
    isOnline = ConnectivityService.instance.isOnline;

    final act = ActivationService.instance;
    isActivated = act.isActivated;
    businessId  = act.businessId;
    branchId    = act.branchId;
    deviceId    = act.serverDeviceId;

    final db = DatabaseService.instance;
    pendingOutboxCount = await db.countUnsyncedPortalSales();
    failedOutboxCount = 0;

    lastPushAt    = await db.getAppMeta('sync_last_push_at');
    lastPullAt    = await db.getAppMeta('sync_last_pull_at');
    lastSuccessAt = await db.getAppMeta('sync_last_success_at');
    pullCursor    = await db.getPullCursor();

    final rawErr = await db.getAppMeta('sync_last_error');
    lastSyncError = (rawErr != null && rawErr.isNotEmpty) ? rawErr : null;

    notifyListeners();
  }
}
