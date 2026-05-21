# 37 — Desktop ↔ Mobile Real Data Parity Fix

**Date:** 2026-05-21  
**Projects:** `pos_system` · `pos_api` · `mobile_dashboard` (verification only)  
**Related:** [101_DESKTOP_SALES_UTC_TIMESTAMP_FIX.md](./101_DESKTOP_SALES_UTC_TIMESTAMP_FIX.md) · [mobile_dashboard/docs/36_DESKTOP_MOBILE_SALES_PARITY_AUDIT.md](../mobile_dashboard/docs/36_DESKTOP_MOBILE_SALES_PARITY_AUDIT.md)

---

## 1. Problem

Desktop admin dashboard shows real local POS data (e.g. 10 completed sales).  
Mobile dashboard showed stale data — last order around 02:30 AM, not the latest sales.

**Goal:** Mobile reflects the same completed sales/revenue/orders as desktop, compared by **sale UUID**, not count alone.

---

## 2. Root cause (confirmed by static analysis)

| Priority | Cause | Effect |
|----------|-------|--------|
| **Primary** | **UTC / timezone on `soldAt`** | Desktop stored `DateTime.now().toIso8601String()` (local, no `Z`). Node `new Date()` treated it as UTC → `soldAt` in PostgreSQL **N hours ahead** (e.g. +2h in UTC+2). Mobile queries `soldAt <= to` with correct UTC `to` → new sales **hidden until UTC clock catches up** (~1–2h lag). |
| **Secondary** | **API default window 30 days** | Clients without `from`/`to` only saw 30 days of sales. Mobile already sends 365d; other clients could diverge. |
| **Tertiary** | **Pre-activation `businessId=local-business`** | Sales created before activation never match mobile JWT `businessId`. |
| **Low** | **Outbox pending/failed** | Sale in SQLite but not in PostgreSQL. |
| **N/A** | **Metric mismatch** | Desktop `fetchSales()` = all SQLite rows; mobile = filtered PostgreSQL — compare **UUIDs**, not raw counts. |

**Sync transaction:** `accepted` SyncEvent and `Sale` upsert run in the **same** Prisma transaction — no separate “accepted but no Sale row” path unless the whole transaction fails (then `rejected`).

---

## 3. Fixes applied

### 3.1 Timestamp UTC (pos_system) — already in tree

All new sales use UTC ISO with `Z`:

```dart
// database_schema.dart
static String toSyncUtcIso([DateTime? when]) =>
    (when ?? DateTime.now()).toUtc().toIso8601String();
```

- `insertSaleWithLines` → `timestamp` / outbox snapshot via `syncTimestamps()`
- `sync_push_payload_mapper.dart` → `_applySoldAtUtc()` on push (legacy rows without `Z` normalized)

### 3.2 Outbox + immediate sync (unchanged, verified)

Payment path: `insertSaleWithLines` → outbox `sales` + `sale_lines` → `_scheduleSyncAfterLocalMutation()` → `BackgroundSyncService.triggerImmediateSync()`.

### 3.3 API dashboard default range (pos_api)

```typescript
// dashboard.service.ts resolveQuery()
: new Date(to.getTime() - 365 * 24 * 60 * 60 * 1000);  // was 30 days
```

`saleWhere()` unchanged: `businessId`, `deletedAt: null`, `status != cancelled`, `soldAt` in range, optional `branchId`.

### 3.4 Mobile date range (already correct)

`mobile_dashboard/lib/features/manager_mobile/utils/dashboard_date_params.dart`:

- `from` = now − 365 days (UTC ISO)
- `to` = now (UTC ISO)

### 3.5 Diagnostics (temporary)

| Layer | Tag | Trigger |
|-------|-----|---------|
| Desktop SQLite + outbox | `[DesktopReality]` | Manager dashboard open (debug mode, once per run) |
| PostgreSQL + SyncEvent | `[ApiReality]` | `GET /dashboard/debug/sales-parity?businessId=<uuid>` (superadmin) |
| Mobile `/dashboard/orders` | `[MobileReality]` | Each `getOrders()` fetch |

---

## 4. UUID parity table

> **Fill at runtime** after one desktop sale + sync + mobile refresh.  
> Compare **latest 20** from each layer.

| UUID | Desktop SQLite | Outbox | PostgreSQL | Mobile API | Reason missing |
|------|:---:|:---:|:---:|:---:|---|
| *(paste from logs)* | ✓/✗ | pending/synced/failed/NOT_QUEUED | ✓/✗ | ✓/✗ | e.g. `soldAt` future vs mobile `to`, wrong `businessId`, not synced |

### How to collect

1. **Desktop:** Run app in debug → open Manager Dashboard → console:
   ```
   [DesktopReality] salesCount=...
   [DesktopReality] sale uuid=... total=... soldAt=... syncStatus=...
   [DesktopReality] outbox uuid=... status=...
   ```
2. **API:** `curl -H "Authorization: Bearer <superadmin>" \
   "https://<api>/dashboard/debug/sales-parity?businessId=<id>"`
3. **Mobile:** Xcode/Android logcat after opening orders:
   ```
   [MobileReality] order uuid=... soldAt=... total=...
   ```

### Missing UUID decision tree

| Desktop | Outbox | PostgreSQL | Mobile | Likely reason |
|:---:|:---:|:---:|:---:|---|
| ✓ | NOT_QUEUED | ✗ | ✗ | Outbox never created |
| ✓ | pending/failed | ✗ | ✗ | Sync not completed / rejected |
| ✓ | synced | ✗ | ✗ | API rejected or wrong `businessId` on push |
| ✓ | synced | ✓ | ✗ | `soldAt` > mobile `to` (timezone) or wrong `businessId` in JWT |
| ✓ | synced | ✓ | ✓ | OK |

---

## 5. Files changed

| Project | File | Change |
|---------|------|--------|
| pos_system | `lib/services/database_schema.dart` | `toSyncUtcIso()` — UTC timestamps (prior commit) |
| pos_system | `lib/services/sync_push_payload_mapper.dart` | `_applySoldAtUtc()` + `status: completed` |
| pos_system | `lib/services/database_service.dart` | `[DesktopReality]` diagnostic; sale insert logs |
| pos_system | `lib/screens/manager_dashboard_screen.dart` | Auto-run diagnostic in `kDebugMode` |
| pos_api | `src/dashboard/dashboard.service.ts` | Default range 365d; `[ApiReality]` `getSalesParity()` |
| pos_api | `src/dashboard/dashboard.controller.ts` | `GET /dashboard/debug/sales-parity` |
| mobile_dashboard | `lib/features/manager_mobile/utils/dashboard_date_params.dart` | 365d window (prior) |
| mobile_dashboard | `lib/features/manager_mobile/services/dashboard_service.dart` | `[MobileReality]` logs |

---

## 6. Before / after

| Scenario | Before | After |
|----------|--------|-------|
| Sale at 14:35 local (UTC+2) | `soldAt` ≈ `14:35Z` in PG (wrong) | `soldAt` = `12:35Z` (correct) |
| Mobile poll at 13:00 local | Sale hidden (`soldAt` > `to`) | Sale visible within ~10s after sync |
| API client without `from` | Last 30 days only | Last 365 days |
| Desktop `soldAt` in SQLite | Local ISO, no `Z` | UTC ISO with `Z` for new rows |
| Parity diagnosis | Ad-hoc / manual | Structured `[DesktopReality]` / `[ApiReality]` / `[MobileReality]` |

---

## 7. Verification checklist

After deploying **pos_system** + **pos_api**:

1. [ ] Create **one new sale** on desktop (pay a table).
2. [ ] Desktop dashboard shows it immediately.
3. [ ] Console: `[DesktopReality] sale uuid=... soldAt=....000Z` and `outbox ... status=synced` (or pending then synced within 10s).
4. [ ] Sync push log: `accepted > 0`, `rejected = 0`.
5. [ ] `GET /dashboard/debug/sales-parity?businessId=<id>` — same UUID in `latestSales[0]`, `soldAt` ends with `Z`.
6. [ ] `GET /dashboard/orders?from=<365d-ago>&to=<now>` — same UUID in response.
7. [ ] Mobile: `[MobileReality] order uuid=<same>` within **10 seconds** of sync.
8. [ ] Fill §4 UUID table — **no missing UUIDs** among latest 20.

### Sample verification logs (template)

```
[DesktopReality] salesCount=10
[DesktopReality] sale uuid=<NEW> total=42.0 soldAt=2026-05-21T10:15:00.000Z status=completed syncStatus=synced
[DesktopReality] outbox uuid=<NEW> status=synced retryCount=0 lastError=null

[ApiReality] dbSalesCount=10
[ApiReality] sale uuid=<NEW> total=42.0 soldAt=2026-05-21T10:15:00.000Z status=completed branchId=...

[MobileReality] rawOrdersCount=10
[MobileReality] order uuid=<NEW> soldAt=2026-05-21T10:15:00.000Z total=42.0 status=completed
```

---

## 8. Cleanup (after parity confirmed in production)

Remove temporary code:

- `runSalesParityDiagnostic()` + manager dashboard trigger
- `GET /dashboard/debug/sales-parity`
- `[TimezoneFix]` / `[DesktopReality]` / `[ApiReality]` / `[MobileReality]` console logs
- `diagSales()` in dashboard service (if still present)

Keep: UTC `toSyncUtcIso()`, `_applySoldAtUtc()`, 365-day default in `resolveQuery()`, mobile `DashboardDateParams`.

---

*End of report.*
