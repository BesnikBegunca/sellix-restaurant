# 18 — BackgroundSyncService Skeleton

## Problem

The app had an **outbox** queue, **ConnectivityService**, and **ApiClient**, but no
single component to coordinate “when to sync” and “how to batch uploads.” Without a
central service, future NestJS integration would scatter sync triggers across
screens and managers.

## Risk

| Scenario | Problem without a sync coordinator |
|---|---|
| Duplicate uploads | Multiple callers drain outbox concurrently |
| Offline storms | Retries with no shared backoff policy |
| Connectivity flaps | No single listener to debounce online → sync |
| Observability | No `isSyncing` / `pendingCount` for UI or logs later |

## Files Changed

| File | Change type |
|---|---|
| `lib/services/background_sync_service.dart` | New singleton sync coordinator (dry-run) |
| `lib/main.dart` | `BackgroundSyncService.instance.initialize()` after connectivity |

## Service Behavior

**Singleton:** `BackgroundSyncService.instance`

| API | Behavior |
|---|---|
| `initialize()` | Idempotent; ensures connectivity is ready, subscribes to `onStatusChanged`, refreshes `pendingCount`. Does **not** call `start()`. |
| `start()` | Sets `isRunning = true`; if online, runs one `triggerSyncNow()` |
| `stop()` | Sets `isRunning = false`; blocks connectivity-auto sync |
| `dispose()` | Cancels subscription, clears running state |
| `refreshPendingCount()` | Queries up to 1000 pending outbox rows, updates `pendingCount` |
| `triggerSyncNow()` | See guards below |
| `isRunning` / `isSyncing` / `pendingCount` | Exposed state |
| `backoff` | `SyncBackoffPolicy` placeholder (exponential delay, max 5 failures) |

### `triggerSyncNow()` guards

1. **Offline** → return immediately (debug log in debug mode).
2. **Already syncing** → return immediately.
3. **Online** → `getPendingOutboxEvents(limit: 100)`, update `pendingCount`, `debugPrint` how many events **would** sync.
4. No `ApiClient` calls; no `markOutboxEventSynced`.

### Connectivity listener

When `isRunning` and status becomes **online**, calls `triggerSyncNow()` (fire-and-forget).

### Startup

`main.dart` calls **`initialize()` only** — not `start()`. Automatic sync stays
disabled until something calls `start()` (future task). Manual `triggerSyncNow()`
still works for testing.

## What It Does Not Do Yet

- Upload payloads to NestJS / Dio
- Mark outbox rows `synced` or `failed`
- Auth / Bearer token setup
- Conflict resolution or pull sync
- Apply real backoff waits between uploads

## What Was Not Changed

- **UI** — no sync indicators or buttons.
- **Backend** — no HTTP requests.
- **Payments / products** — unchanged.
- **Outbox wiring** — still written only from `DatabaseService` entity methods.
- **Database schema** — unchanged.

## Manual Test Checklist

- [ ] App starts successfully
- [ ] `BackgroundSyncService.instance.initialize()` completes without error
- [ ] Offline: `triggerSyncNow()` returns immediately (debug: “skip sync (offline)”)
- [ ] Online: `triggerSyncNow()` logs pending outbox count (debug: “would sync N…”)
- [ ] No API calls in debug network/log output
- [ ] Outbox `syncStatus` remains `pending` after dry-run
- [ ] POS works offline as before
- [ ] Run `flutter analyze`

## Next Step

Next task: Gradually split ManagerData and create repositories.
