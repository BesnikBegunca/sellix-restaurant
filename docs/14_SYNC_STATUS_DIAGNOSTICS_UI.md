# Sync Status + Diagnostics UI

Makes sync health operationally visible to managers without changing any POS
sales, payment, or product behavior.

---

## Problem

Push sync, pull sync, and token refresh all work silently. Operators have no
way to know whether the device is online, whether outbox events are backed up,
or whether something failed. Silent failures can accumulate unnoticed.

---

## Files Changed

| File | Action |
|------|--------|
| `lib/services/database_service.dart` | Added 5 diagnostic helpers |
| `lib/services/sync_status_service.dart` | Created — `ChangeNotifier` aggregating sync health |
| `lib/services/background_sync_service.dart` | Writes `app_meta` timestamps; calls `SyncStatusService` setters |
| `lib/screens/sync_diagnostics_screen.dart` | Created — diagnostics dialog + `showSyncDiagnosticsDialog()` |
| `lib/features/dashboard/widgets/manager_top_bar.dart` | Added `_SyncStatusChip` via `ListenableBuilder` |
| `lib/main.dart` | Calls `SyncStatusService.instance.start()` at startup |

---

## Metadata Persisted in `app_meta`

| Key | Written by | Content |
|-----|-----------|---------|
| `sync_last_push_at` | `BackgroundSyncService.triggerSyncNow()` on success | ISO-8601 timestamp |
| `sync_last_pull_at` | `BackgroundSyncService.pullSyncNow()` on success | ISO-8601 timestamp |
| `sync_last_success_at` | Either push or pull on success | ISO-8601 timestamp |
| `sync_last_error` | Push or pull on any error; cleared on next success | Human-readable message |

These persist across restarts. The diagnostics screen reads them via
`DatabaseService.getAppMeta()`.

---

## `SyncStatusService`

Located at `lib/services/sync_status_service.dart`. Singleton `ChangeNotifier`.

### State exposed

| Field | Source | Type |
|-------|--------|------|
| `isOnline` | `ConnectivityService` stream | `bool` |
| `isSyncingPush` | Set by `BackgroundSyncService` via `setSyncingPush()` | `bool` |
| `isSyncingPull` | Set by `BackgroundSyncService` via `setSyncingPull()` | `bool` |
| `pendingOutboxCount` | DB query every 10s | `int` |
| `failedOutboxCount` | DB query every 10s | `int` |
| `lastPushAt` | `app_meta['sync_last_push_at']` | `String?` |
| `lastPullAt` | `app_meta['sync_last_pull_at']` | `String?` |
| `lastSuccessAt` | `app_meta['sync_last_success_at']` | `String?` |
| `lastSyncError` | `app_meta['sync_last_error']` (null if empty) | `String?` |
| `pullCursor` | `app_meta['sync_pull_cursor']` | `String?` |
| `isActivated` | `ActivationService.instance.isActivated` | `bool` |
| `businessId` | `ActivationService.instance.businessId` | `String?` |
| `branchId` | `ActivationService.instance.branchId` | `String?` |
| `deviceId` | `ActivationService.instance.serverDeviceId` | `String?` |
| `sessionConflictSkips` | Accumulated via `markConflictSkips()` | `int` |

### Lifecycle

```dart
SyncStatusService.instance.start();  // main.dart — once at startup
SyncStatusService.instance.stop();   // not called yet; available for logout
```

`start()` wires a `ConnectivityService` subscription and a 10-second poll
timer. `refresh()` can be called on demand (e.g., after dialog opens).

### No circular imports

`SyncStatusService` does NOT import `BackgroundSyncService`.
`BackgroundSyncService` imports `SyncStatusService` and drives it via:

```dart
SyncStatusService.instance.setSyncingPush(true);   // before push
SyncStatusService.instance.setSyncingPush(false);  // in finally
SyncStatusService.instance.setSyncingPull(true);   // before pull
SyncStatusService.instance.setSyncingPull(false);  // in finally
SyncStatusService.instance.markConflictSkips(n);   // after pull apply
unawaited(SyncStatusService.instance.refresh());   // in finally
```

---

## Database Helpers Added to `DatabaseService`

| Method | SQL |
|--------|-----|
| `getPendingOutboxCount()` | `SELECT COUNT(*) FROM outbox WHERE syncStatus = 'pending'` |
| `getFailedOutboxCount()` | `SELECT COUNT(*) FROM outbox WHERE syncStatus = 'failed'` |
| `getRecentFailedOutboxEvents({limit})` | `SELECT * FROM outbox WHERE syncStatus = 'failed' ORDER BY updatedAt DESC LIMIT n` |
| `retryFailedOutboxEvents()` | `UPDATE outbox SET syncStatus = 'pending', retryCount = 0 WHERE syncStatus = 'failed'` |
| `clearResolvedSyncErrors()` | `DELETE FROM outbox WHERE syncStatus = 'synced'` + clears `sync_last_error` |

---

## Small UI Indicator (`_SyncStatusChip`)

Added to `ManagerTopBar` between the shift status chip and the clock chip.
Rendered via `ListenableBuilder` — rebuilds automatically when
`SyncStatusService` notifies.

### States (priority order)

| Condition | Color | Label |
|-----------|-------|-------|
| Not activated | Gray | Jo aktivizuar |
| Offline | Red | Jo online |
| Syncing (push or pull) | Amber | Sinkronizim… |
| Failed outbox events | Red | N gabime |
| Pending outbox events | Amber | N pritje |
| All good | Green | Sinkronizuar |

Tapping the chip opens `showSyncDiagnosticsDialog(context)`.

---

## Sync Diagnostics Dialog

Located at `lib/screens/sync_diagnostics_screen.dart`.
Opened via `showSyncDiagnosticsDialog(context)`.

### Sections

1. **Activation** — Status, Business ID, Branch ID, Device ID
2. **Connectivity** — Online / Offline
3. **Outbox** — Pending count, Failed count, Session conflict skips
4. **Timestamps** — Last push, Last pull, Last success (relative time), Pull cursor (copyable)
5. **Error banner** — Shown when `lastSyncError` is non-null
6. **Recent Failed Events** — Up to 5 most recent failed outbox rows with entity type, operation, error message

### Actions

| Button | Behavior |
|--------|----------|
| **Retry Sync Now** | Calls `retryFailedOutboxEvents()` then `triggerSyncNow()` + `pullSyncNow()` |
| **Clear Resolved** | Calls `clearResolvedSyncErrors()` (deletes synced rows, clears error flag) |

---

## Conflict Visibility v1

When `PullSyncApplyService` skips a row because the local `syncStatus = 'pending'`
(and for other skip reasons like missing parent FK), the count is included in
`PullSyncApplyResult.skipped`. `BackgroundSyncService.pullSyncNow()` passes this
to `SyncStatusService.instance.markConflictSkips(n)`, which accumulates it in
`sessionConflictSkips` (resets to 0 on app restart).

The diagnostics dialog shows "Session conflict skips" so operators can see
whether local uncommitted rows are blocking server updates.

No merge UI is implemented — the pending row takes precedence and will be
pushed on the next outbox upload, after which the server version will arrive
on the next pull.

---

## What Was Not Changed

- Sales, payment, product, shift, or expense workflows
- Activation logic (`ActivationService`, `ActivationScreen`)
- Push sync logic (outbox, event encoding, server response parsing)
- Pull sync logic (cursor, entity apply, transaction safety)
- Any backend endpoint
- `login_screen.dart`, `pos_order_screen.dart`, `table_selection_screen.dart`

---

## Manual Test Checklist

- [ ] Offline indicator (red "Jo online") appears when network is disconnected
- [ ] Online indicator (green "Sinkronizuar") appears when network is restored
- [ ] "N pritje" chip appears after adding a sale (pending outbox events)
- [ ] Chip turns green after successful push clears the outbox
- [ ] Failed count appears after injecting a rejected event (manual DB edit)
- [ ] Tapping chip opens diagnostics dialog
- [ ] Business ID / Branch ID / Device ID shown correctly after activation
- [ ] Last push time updates after a successful push sync
- [ ] Last pull time updates after a successful pull sync
- [ ] "Retry Sync Now" button triggers push + pull and updates timestamps
- [ ] "Clear Resolved" removes synced rows from outbox (verify via DB)
- [ ] Session conflict skips increments when a pending row is skipped during pull
- [ ] Error banner appears with message after a failed sync (force offline mid-push)
- [ ] No existing POS flow is changed or broken

---

## Next Step

Production API config + Windows packaging:
- Replace `kApiBaseUrl = 'http://localhost:3000/api'` with runtime config
  (environment variable, config file, or settings screen)
- Configure Windows installer to bundle the API base URL
- Add `SyncStatusService.instance.stop()` on logout / deactivation
