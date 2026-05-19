# Desktop Sync Retry & Failed Outbox Events

How the Flutter desktop POS schedules sync retries after API/network failures
and surfaces rejected outbox rows in Sync Diagnostics.

---

## Backoff policy

**File:** `lib/services/sync_backoff_policy.dart`

| Setting | Value |
|---------|-------|
| Base delay | 2 seconds |
| Max delay | 5 minutes |
| Max failure count | 8 (informational; manual retry still allowed) |
| Jitter | Random 50%–100% of exponential delay |

`BackgroundSyncService` uses:

- `currentDelay` / `delayWithJitter` after each push/pull failure
- `nextRetryAt` — automatic retry timer
- `isReady` — gates automatic `triggerSyncNow` / `pullSyncNow`

### Automatic retry (not immediate storms)

On connectivity **online**:

- Calls `_requestSyncWhenReady()` instead of immediate push+pull
- If backoff active → schedules **one** `Timer` for remaining delay

On push/pull **failure** (network, malformed response):

- `recordFailure()` + persist `sync_last_error`
- Schedules retry after jittered delay

On **success** (push batch OK or pull commit OK):

- `reset()` — clears backoff and cancels timer

**Offline:** sync skipped (no failure increment). Timer cancelled when going offline.

### Manual override

Diagnostics **Retry Sync Now** calls:

```dart
triggerSyncNow(force: true);
pullSyncNow(force: true);
```

**Riprovo të gjitha** / per-event **Riprovo** reset failed rows to `pending` and use `force: true`.

---

## Failed outbox events

Server `POST /sync/push` response:

| Bucket | Local action |
|--------|----------------|
| `accepted` | `markOutboxEventSynced` |
| `duplicates` | `markOutboxEventSynced` |
| `rejected` | `markOutboxEventFailed(uuid, reason)` — **kept** in SQLite |

Failed events are **never auto-deleted**.

### Database helpers

| Method | Purpose |
|--------|---------|
| `getAllFailedOutboxEvents()` | Full list for diagnostics |
| `retryFailedOutboxEvent(uuid)` | One row → `pending` |
| `retryFailedOutboxEvents()` | All failed → `pending` |

---

## Sync Diagnostics UI

**File:** `lib/screens/sync_diagnostics_screen.dart`

| Feature | Description |
|---------|-------------|
| Backoff status | Failure count, next auto retry countdown |
| Failed list | All failed rows (scrollable), not capped at 5 |
| Riprovo | Per-event retry |
| Riprovo të gjitha | Reset all failed + forced sync |
| Eksporto JSON | Clipboard via `SyncDiagnosticsExportService` |
| Retry Sync Now | Forced sync (bypasses backoff) |

Export includes: API URL, activation IDs, sync meta, backoff state, outbox counts, full failed event payloads (decoded JSON when possible).

---

## Files

| File | Role |
|------|------|
| `lib/services/sync_backoff_policy.dart` | Exponential backoff + jitter |
| `lib/services/background_sync_service.dart` | Scheduling, `force` flag |
| `lib/services/sync_diagnostics_export_service.dart` | Support JSON export |
| `lib/services/database_service.dart` | Outbox query/retry helpers |
| `lib/screens/sync_diagnostics_screen.dart` | UI |

---

## Manual test checklist

- [ ] Go offline → sync skips; no tight retry loop in debug console
- [ ] Go online after failures → sync waits for backoff, then retries once
- [ ] Force API error (bad URL) → `sync_last_error` set; backoff countdown visible in diagnostics
- [ ] Server rejects an outbox event → appears in failed list with `lastError`
- [ ] **Riprovo** on one event → row becomes pending; push retried
- [ ] **Riprovo të gjitha** → all failed pending; sync runs
- [ ] **Eksporto JSON** → clipboard contains failed events + meta
- [ ] **Retry Sync Now** works even when backoff active
- [ ] Successful sync resets backoff / shows "Ready now"

---

## Unchanged

- Offline-first: local SQLite remains source of truth
- API payload shape for `/sync/push` unchanged
- Pending outbox FIFO unchanged
- Pull cursor semantics unchanged
