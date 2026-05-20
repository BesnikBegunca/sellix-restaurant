# 28 — Desktop → PostgreSQL Sync Pipeline Audit

**Status:** Investigation complete. Diagnostics instrumented. Awaiting log run.  
**Symptom:** `totalSalesInDB=0` in dashboard despite sales being recorded locally and API returning 200 on other endpoints.  
**Scope:** Desktop Flutter app (pos_system) → NestJS API (pos_api) → PostgreSQL only. Mobile app and UI untouched.

---

## Pipeline Chain Overview

```
User taps "Pay"
  └─ pos_order_screen.dart  _payTable()
       ├─ resolvePaymentSaleUuid()        deduplicate / create sale UUID
       └─ recordSaleWithLines()
            └─ database_service.dart  insertSaleWithLines()
                 ├─ INSERT INTO sales (uuid, total, businessId, …)
                 ├─ _queueOutboxByIdIfAbsent('sales', saleId)
                 │    └─ INSERT INTO outbox (entityType='sales', entityUuid, payloadJson)
                 ├─ for each line:
                 │    ├─ INSERT INTO sale_lines (uuid, saleId, …)
                 │    └─ _queueOutboxByIdIfAbsent('sale_lines', lineId, payloadExtras={saleUuid})
                 │         └─ INSERT INTO outbox (entityType='sale_lines', entityUuid, payloadJson)
                 └─ _scheduleSyncAfterLocalMutation()

background_sync_service.dart  triggerSyncNow()
  ├─ GATE: isApiConfigBlocked?   → block if RuntimeConfig is localhost in release
  ├─ GATE: isOnline?             → skip if offline
  ├─ GATE: backoff.isReady?      → skip if in retry backoff
  ├─ GATE: isActivated?          → skip if not activated
  ├─ GATE: isBlocked (license)?  → skip if license suspended
  ├─ getPendingOutboxEvents(limit=100)
  ├─ for each outbox row:
  │    └─ _buildSyncPushEvent(row)
  │         └─ sync_push_payload_mapper.dart  mapPayload(entityType, payloadJson)
  │              ├─ sales      → _mapSalesPayload()    copies all fields + soldAt/status
  │              └─ sale_lines → _mapSaleLinePayload() strips to 5 fields only
  └─ POST /sync/push  { events: [...] }

pos_api  sync.service.ts  processBatch()
  ├─ Sort events by ENTITY_PROCESS_ORDER (sales=5, sale_lines=6)
  ├─ For each event (own Prisma $transaction):
  │    ├─ validateSaleLine(payload)  OR  validateSale(payload, batchLines)
  │    └─ upsertSale() / upsertSaleLine()  → INSERT INTO PostgreSQL
  └─ Return { accepted:[], duplicates:[], rejected:[{uuid, reason}] }
```

---

## File:Line Reference Map

| Step | File | Key Location |
|------|------|-------------|
| Payment trigger | `lib/screens/pos_order_screen.dart` | `_payTable()` |
| Sale insert | `lib/services/database_service.dart` | `insertSaleWithLines()` L809 |
| Outbox queue | `lib/services/database_service.dart` | `_queueOutboxByIdIfAbsent()` L2233 |
| Sync gate checks | `lib/services/background_sync_service.dart` | `triggerSyncNow()` L111 |
| Outbox fetch | `lib/repositories/sync_repository.dart` | `getPendingOutboxEvents()` |
| Event builder | `lib/services/background_sync_service.dart` | `_buildSyncPushEvent()` L621 |
| Payload mapping | `lib/services/sync_push_payload_mapper.dart` | `_mapSaleLinePayload()` L53 |
| HTTP post | `lib/services/background_sync_service.dart` | `ApiClient.instance.post(kEndpointSyncPush)` L207 |
| API receive | `pos_api/src/sync/sync.service.ts` | `processBatch()` |
| Sale validation | `pos_api/src/sync/validation/sales-validation.service.ts` | `validateSale()` L76 |
| Line validation | `pos_api/src/sync/validation/sales-validation.service.ts` | `validateSaleLine()` L45 |
| Sale upsert | `pos_api/src/sync/processors/sync-entity.processor.ts` | `upsertSale()` |
| Line upsert | `pos_api/src/sync/processors/sync-entity.processor.ts` | `upsertSaleLine()` L281 |

---

## Identified Failure Points — Ranked by Likelihood

### #1 — CRITICAL: Total vs LineTotal Floating-Point Tolerance Bug

**Location:** `validateSale()` in `pos_api/src/sync/validation/sales-validation.service.ts:93`  
**Tolerance:** `LINE_TOTAL_TOLERANCE = 0.02`

**Root cause:**  
Flutter stores each `lineTotal` rounded to 2 decimal places (`toStringAsFixed(2)`) in `sale_lines`.  
Flutter stores `tableTotal` (the sale's `total`) as the raw floating-point sum of `price * qty` for each line — **not** re-rounded after summing.

For orders with 5+ items, per-item rounding discards tiny fractions that accumulate:
```
Example: 3 items at 1.005 each
  lineTotal each = 1.01  (rounded)
  sum(lineTotals) = 3.03
  tableTotal      = 3.015 (raw IEEE 754 double)
  delta           = |3.015 - 3.03| = 0.015  → passes

Example: 20 items at 1.005 each  
  sum(lineTotals) = 20 * 1.01 = 20.20
  tableTotal      = 20.10
  delta           = 0.10  → REJECTED (> 0.02)
```

The diagnostic in `_payTable()` will print `[SyncDiag] totalVsLineTotals ... wouldFailValidation=true` when this is about to cause a rejection.

**Fix (not applied yet):** Round `tableTotal` to 2dp before persisting to `sales.total`:
```dart
final total = double.parse(tableTotal.toStringAsFixed(2));
```

---

### #2 — HIGH: Sync Gate Silently Blocks All Push Attempts

**Location:** `background_sync_service.dart triggerSyncNow()` L112-148

Gates checked in order:
1. `_isApiConfigBlocked()` — RuntimeConfig resolved to localhost in release mode
2. `isOnline` — ConnectivityService reports offline
3. `backoff.isReady` — Exponential backoff after a prior failure
4. `isActivated` — ActivationService has not activated yet
5. `isBlocked` (license) — LicenseGateService suspended

**Any one of these silently returns.** Previously only logged in `kDebugMode` with `debugPrint` — not visible in release logs. Now instrumented with `print('[SyncDiag] triggerSyncNow GATED: ...')`.

**Most likely sub-cause:** If any prior sync attempt resulted in a 400 or network error, `_backoff` enters exponential retry delay. After `backoff.exhausted` (max failures reached), `isReady` stays false forever until explicit reset. No UI notification.

**What to look for in logs:**
```
[SyncDiag] triggerSyncNow GATED: offline
[SyncDiag] triggerSyncNow GATED: backoff nextRetryAt=... failures=5
[SyncDiag] triggerSyncNow GATED: not activated
[SyncDiag] triggerSyncNow GATED: license blocked
```

---

### #3 — HIGH: businessId='local-business' Stamp on Early Sales

**Location:** `lib/services/database_schema.dart` — `_activatedBusinessId` defaults to `'local-business'`  
**Set by:** `ActivationService` after a successful device activation

Sales recorded before the device completes activation are stamped with:
```
businessId = 'local-business'
branchId   = 'local-branch'
deviceId   = '<uuid>'  (stable)
```

The API reads `businessId` from the JWT Bearer token, NOT from the event payload — so the upsert itself is not blocked. However, if any API-side filter or uniqueness constraint compares the payload's `businessId` against the token's `businessId`, those rows would be silently dropped or cause a mismatch.

**What to look for in logs:**
```
[SyncDiag] insertSaleWithLines scope: businessId=local-business branchId=local-branch deviceId=...
```
If this appears, sales recorded before activation carry incorrect tenant IDs in the SQLite payload. These may succeed sync (API ignores payload businessId) or may not (if API validates payload vs token businessId).

---

### #4 — HIGH: sale_lines Payload Missing saleUuid (UUID Format Required)

**Location:** `_mapSaleLinePayload()` in `sync_push_payload_mapper.dart:53`  
**Validated by:** `requireUuidAlias(payload, 'saleUuid', 'saleId')` in `sales-validation.service.ts:50`

`_mapSaleLinePayload()` copies `saleUuid` only if it is a non-empty `String`. The `payloadExtras: {'saleUuid': saleUuid}` injected in `insertSaleWithLines()` passes the UUID string of the parent sale — which should be a valid UUID.

**However, `requireUuidAlias` enforces UUID format:**
```typescript
export function requireUuidAlias(payload, canonical, ...aliases): string {
  for (const field of [canonical, ...aliases]) {
    const value = payload[field];
    if (typeof value === 'string' && UUID_RE.test(value.trim())) {
      return value.trim();
    }
  }
  throw new PayloadError(`Missing or invalid "saleUuid"`);
}
```

If `saleUuid` in the outbox payload is `null`, empty, or not UUID-format, the line is **rejected** with reason `Missing or invalid "saleUuid"`.

**What to look for in logs:**
```
[SyncDiag] _mapSaleLinePayload input: ... saleUuid=null ...
[SyncDiag] _mapSaleLinePayload output: saleUuidPresent=false saleUuidIsUuid=false
[SyncDiag] REJECTED uuid=... reason=Missing or invalid "saleUuid"
```

---

### #5 — MEDIUM: Silent Outbox Drop When UUID is Null

**Location:** `_queueOutboxByIdIfAbsent()` in `database_service.dart:2248-2250`

```dart
if (entityUuid == null || entityUuid.isEmpty) return;  // silent drop
```

If a row is inserted without a `uuid` column (schema bug, migration miss, or code path that doesn't generate UUID), the outbox entry is skipped entirely. The sale or line exists in SQLite but will **never** be synced.

Now instrumented — logs:
```
[SyncDiag] WARN _queueOutboxByIdIfAbsent: uuid is null/empty entityType=sales id=42 — outbox entry skipped
```

---

### #6 — MEDIUM: Outbox Already Exists Deduplication May Skip Retry

**Location:** `_hasOutboxEventForEntity()` check inside `_queueOutboxByIdIfAbsent()` — `database_service.dart:2252`

If an outbox entry for the same `(entityType, entityUuid, operation)` already exists (e.g., from a prior failed sync that was never cleaned up), the new entry is silently skipped. This prevents duplicate-event spam but also means a `failed` outbox event blocks re-queueing.

The retry mechanism marks failed events with `syncStatus='failed'` — and `getPendingOutboxEvents()` presumably returns only `syncStatus='pending'` rows. Once a row is `failed`, it may need manual reset or a dedicated retry queue.

---

### #7 — LOW: RuntimeConfig Fallback to Localhost

**Location:** `lib/services/runtime_config_service.dart` — `_executableConfigPaths()`

If `app_config.json` is missing or `POS_API_BASE_URL` env var is unset, RuntimeConfig falls back to `http://localhost:3000`. In release mode this is blocked (`isBlockedInRelease = true`), causing `_isApiConfigBlocked()` to return true and silently gate all sync.

**Log to watch for:**
```
[RuntimeConfig] source=fallback_localhost
[RuntimeConfig] ERROR: No production API configuration found.
```

---

## Where Diagnostics Were Added

### `lib/screens/pos_order_screen.dart` — `_payTable()`
- Logs `tableTotal`, item count, waiter, tableId at payment time
- Logs `sumRoundedLineTotals`, `delta`, `wouldFailValidation` — directly shows if #1 will occur
- Logs `resolvedSaleUuid` and `recordSaleWithLines saleId`

### `lib/services/database_service.dart` — `insertSaleWithLines()`
- Logs `scope: businessId branchId deviceId` — catch #3
- Logs `sale inserted saleId uuid total` — confirms sale row exists
- Logs `outbox queued entityType=sales` — confirms outbox entry created
- Logs per-line: `line inserted lineId uuid saleId saleUuid productName qty lineTotal`
- Logs per-line: `outbox queued entityType=sale_lines`

### `lib/services/database_service.dart` — `_queueOutboxByIdIfAbsent()`
- Logs WARN when row not found — catch #5
- Logs WARN when uuid is null/empty — catch #5

### `lib/services/background_sync_service.dart` — `triggerSyncNow()`
- Logs each GATE that blocks sync — catch #2
- Logs `outbox is empty — nothing to push` when no pending events
- Logs each event: `entityType entityUuid payloadKeys` — verify payload shape
- Logs full `payload` map for `sales` and `sale_lines` events
- Logs `syncPushResponse: accepted= duplicates= rejected=` — complete API response
- Logs each `REJECTED uuid reason` — catch all API rejections
- Logs `PUSH FAILED status body` and `PUSH EXCEPTION` on errors

### `lib/services/sync_push_payload_mapper.dart` — `_mapSaleLinePayload()`
- Logs all input fields before stripping — catch #4
- Logs output fields and whether `saleUuidIsUuid` — catch #4

---

## Test Procedure

1. **Attach a terminal to the running app** (or check macOS Console / Windows DebugView for `print()` output).

2. **Run one test sale** with 2–3 items.

3. **Expected log sequence (happy path):**
```
[RuntimeConfig] source=app_config.json
[SyncDiag] _payTable tableId=... items=3 tableTotal=X.XX
[SyncDiag] totalVsLineTotals tableTotal=X.XX sumRoundedLineTotals=X.XX delta=0.000000 wouldFailValidation=false
[SyncDiag] resolvedSaleUuid=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[SyncDiag] insertSaleWithLines scope: businessId=<real-id> branchId=<real-id> deviceId=<uuid>
[SyncDiag] sale inserted SQLite saleId=42 uuid=xxxxxxxx-... total=X.XX
[SyncDiag] outbox queued entityType=sales saleId=42
[SyncDiag] line inserted lineId=1 uuid=... saleId=42 saleUuid=...
[SyncDiag] outbox queued entityType=sale_lines lineId=1 uuid=...
[SyncDiag] line inserted lineId=2 ...
[SyncDiag] outbox queued entityType=sale_lines lineId=2 ...
[SyncDiag] triggerSyncNow: pushing 3 event(s)
[SyncDiag] event entityType=sales entityUuid=... payloadKeys=[uuid, total, ...]
[SyncDiag] event entityType=sale_lines entityUuid=... payloadKeys=[saleUuid, price, quantity, lineTotal, name]
[SyncDiag] _mapSaleLinePayload input: ... saleUuid=<uuid> price=X qty=Y lineTotal=Z ...
[SyncDiag] _mapSaleLinePayload output: keys=[saleUuid, price, quantity, lineTotal, name] saleUuidPresent=true saleUuidIsUuid=true
[SyncDiag] syncPushResponse: accepted=3 duplicates=0 rejected=0
```

4. **Diagnose from deviations:**

| Symptom in logs | Root cause | Fix |
|-----------------|-----------|-----|
| `[SyncDiag] triggerSyncNow GATED: offline` | Network not detected | Check ConnectivityService / Dio reachability |
| `[SyncDiag] triggerSyncNow GATED: backoff failures=N` | Prior failure put sync in retry delay | Find first `PUSH FAILED` / `REJECTED` log above it |
| `[SyncDiag] triggerSyncNow GATED: not activated` | Device not activated | Complete activation flow |
| `[RuntimeConfig] source=fallback_localhost` + `ERROR: No production API configuration found.` | Missing `app_config.json` | Copy `app_config.json` beside exe / into `Contents/Resources/` |
| `[SyncDiag] insertSaleWithLines scope: businessId=local-business` | Sale recorded before activation | Activate first; or investigate if API rejects payload businessId |
| `wouldFailValidation=true` | Total/lineTotal rounding bug | Round `tableTotal` to 2dp before `recordSaleWithLines()` |
| `[SyncDiag] REJECTED uuid=... reason=sale total does not match...` | Rounding bug confirmed | Fix #1 |
| `[SyncDiag] REJECTED uuid=... reason=Missing or invalid "saleUuid"` | `saleUuid` not UUID format in outbox | Check `payloadExtras` injection; check if sale UUID was null |
| `[SyncDiag] WARN _queueOutboxByIdIfAbsent: uuid is null/empty` | UUID not generated for entity | Check schema migration; check `DatabaseSchema.generateUuid()` path |
| `[SyncDiag] triggerSyncNow: outbox is empty` but sales exist in SQLite | Outbox rows not created | Check for WARN logs above; check `syncStatus` column |
| `[SyncDiag] PUSH FAILED status=400 body=...` | Invalid payload shape | Read error body; check `_mapSalesPayload` output |
| `[SyncDiag] PUSH FAILED status=401` | Token expired, refresh failed | Check refresh flow in `_handleSyncUnauthorized()` |

---

## Suspected Primary Cause (Before Log Confirmation)

Based on static analysis, the **most likely** cause of `totalSalesInDB=0` is one of:

1. **Sync gate never passes** — either `isApiConfigBlocked` (wrong/missing `app_config.json`) or `backoff.exhausted` after a prior 400 failure. These are silent in release mode without the new `[SyncDiag]` prints.

2. **Rounding tolerance rejection** — if the app has already reached the API, sales are being rejected server-side with `"sale total does not match sum of sale_lines in the same batch"`.

Run the diagnostics, share the log output, and the specific cause will be immediately visible.

---

*Diagnostics added: 2026-05-20. Remove all `[SyncDiag]` prints after the root cause is confirmed and fixed.*
