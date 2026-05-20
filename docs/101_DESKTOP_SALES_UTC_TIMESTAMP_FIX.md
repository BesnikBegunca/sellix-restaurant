# Desktop Sales UTC Timestamp Fix

**Date:** 2026-05-20  
**Scope:** `pos_system` desktop — sync timestamp serialization only  
**Goal:** Align `soldAt` / sale `timestamp` with UTC (`Z`) so mobile dashboards do not lag 1–2 hours behind desktop.

---

## 1. Files changed

| File | Change |
|------|--------|
| `lib/services/database_schema.dart` | `toSyncUtcIso()`; `syncTimestampStamp()` uses UTC |
| `lib/services/database_service.dart` | `[TimezoneFix]` logs on sale insert/outbox; shift open/close UTC |
| `lib/services/sync_push_payload_mapper.dart` | `_applySoldAtUtc()` defensive normalization + log |
| `test/sync_push_payload_mapper_test.dart` | UTC conversion tests |

**Not changed:** UI, revenue math, dashboard filters, sync batching/retry, API, mobile app, migrations, historical rows.

---

## 2. Exact timestamp fixes

### Central stamp (all new sync-critical rows)

```dart
// database_schema.dart
static String toSyncUtcIso([DateTime? when]) =>
    (when ?? DateTime.now()).toUtc().toIso8601String();
```

Used by `syncTimestampStamp()` → `DatabaseService.syncTimestamps()` → sale `timestamp`, `createdAt`, `updatedAt`, sale_lines, expenses, products, outbox payloads (snapshot), etc.

### Sale payment path

- `insertSaleWithLines()` sets `sales.timestamp` from `syncTimestamps()['createdAt']` → **always ends with `Z`**
- Outbox payload is a row snapshot → inherits same UTC fields

### Push payload (defensive)

`_mapSalesPayload()` → `_applySoldAtUtc()`:

- If `soldAt` already ends with **`Z`** → **unchanged**
- If `soldAt` missing → derive from `timestamp` / `createdAt`, convert with `toUtc().toIso8601String()`
- If `soldAt` present but **no `Z`** (legacy local string in outbox) → convert to UTC on push only

### Shift sync (minor, same class of bug)

- `insertShiftRecord` / `closeShiftRecord` use `DatabaseSchema.toSyncUtcIso()` for `openedAt` / `closedAt`

---

## 3. Before vs after

| Scenario | Before (local, no `Z`) | After (UTC) |
|----------|------------------------|-------------|
| Payment at 14:35 in UTC+2 | `2026-05-20T14:35:00.000` stored & pushed | `2026-05-20T12:35:00.000Z` |
| Server interprets time | Often as **14:35 UTC** → +2h on mobile | **12:35 UTC** = correct instant |
| Mobile “today” filter | Sale appears hours later | Sale appears within seconds after sync |

**Example (UTC+2 operator):**

```
Before: timestamp=2026-05-20T14:35:00.000  → API thinks 14:35 UTC
After:  soldAt=2026-05-20T12:35:00.000Z    → API thinks 12:35 UTC (= 14:35 local)
```

---

## 4. Diagnostics (temporary)

Console tags when a sale is inserted, queued, and mapped:

```
[TimezoneFix] localNow=... utcNow=... soldAt=...
[TimezoneFix] queued to outbox uuid=... soldAt=...
[TimezoneFix] payloadSoldAt=... timestamp=... createdAt=...
```

Remove when validated in production.

---

## 5. Remaining risk areas

| Risk | Severity | Notes |
|------|----------|-------|
| **Historical sales** still local ISO without `Z` | Medium | Only **new** inserts use UTC; old rows unchanged by design |
| **Legacy outbox pending** with local `timestamp` | Low | `_applySoldAtUtc()` converts on push if no `Z` |
| **Desktop dashboard “today”** uses `DateTime.parse` on `timestamp` | Low | UTC instants compare correctly with local day bounds in Dart |
| **In-memory `SaleRow`** after payment still uses `DateTime.now()` local in `ManagerData` | Low | Display-only until reload from DB; reload reads UTC string from SQLite |
| **Non-sale tables** using `DateTime.now().toIso8601String()` outside `syncTimestamps` | Low | e.g. audit, app_meta — not sent as `soldAt` |

---

## 6. Historical sales

- **No migration** and **no bulk rewrite**
- Existing `sales.timestamp` values remain as stored
- Only **new payments** after this build get UTC `Z` in DB and push payload
- Operators may still see old mobile skew for pre-fix sales until manually reconciled (out of scope)

---

## 7. Verification checklist

1. Pay one table → logs show `soldAt=....000Z`
2. Sync push → `[TimezoneFix] payloadSoldAt=....000Z`
3. PostgreSQL `sales.sold_at` (or equivalent) matches UTC instant
4. Mobile dashboard shows sale within **&lt;10s** after sync (not 1–2h late)

---

*End of report.*
