# 10 — Add businessId / branchId / deviceId to Sync-Critical Tables

## Problem

Sync-critical SQLite tables had stable `uuid` columns (v17) but no tenant or device
scope. A future NestJS + PostgreSQL sync needs every row tagged with:

- **businessId** — which business owns the record
- **branchId** — which branch within the business
- **deviceId** — which POS terminal created or last touched the row

Without these columns, the backend cannot partition data, filter deltas per
device, or merge multi-terminal uploads safely.

## Risk

| Scenario | Problem without scope columns |
|---|---|
| Multi-branch deployment | All rows look identical; no way to route data to the correct branch |
| Two terminals on one branch | Cannot tell which device originated a sale or expense |
| Offline restore on another machine | Rows lack device provenance for conflict resolution |
| Premature sync API | Backend would have to infer tenant from headers only, not from row data |

Placeholder values (`local-business`, `main-branch`) are intentional: they keep
local-only installs working until real IDs are assigned at login/sync time.

## Files Changed

| File | Change type |
|---|---|
| `lib/services/database_schema.dart` | Constants, column migration in `ensureTables()`, `resolveDeviceId()`, backfill, seed update |
| `lib/services/database_service.dart` | Version bump 17 → 18, `syncScope()` / `syncDeviceId()`, scope on every sync insert |

## Database Changes

`businessId TEXT`, `branchId TEXT`, and `deviceId TEXT` added to all 16
sync-critical tables:

| Table | Notes |
|---|---|
| `sales` | Per completed sale |
| `sale_lines` | Per line item |
| `sale_adjustments` | Per refund/void/discount |
| `expenses` | Per expense entry |
| `shifts` | Per shift archive record |
| `products` | Per product |
| `categories` | Per category |
| `waiters` | Per waiter |
| `waiter_salaries` | Per salary row |
| `advances` | Per advance payment |
| `waiter_worked_days` | Per worked-day record |
| `audit_logs` | `deviceId` already existed (v10); `businessId` and `branchId` are new |
| `current_orders` | Per active order slot |
| `current_order_lines` | Per active order line |
| `kitchen_prints` | Per kitchen print batch |
| `kitchen_print_lines` | Per kitchen print line |

**Schema version bumped: 17 → 18.**

Columns are added via `ALTER TABLE … ADD COLUMN` inside `ensureTables()`, each
wrapped in `try/catch` for idempotency (safe no-op if the column already exists).

## Backfill Strategy

1. `upgrade()` calls `_backfillSyncScopeIds(db)` after `_backfillUuids(db)`.

2. `resolveDeviceId(db)` reads `app_meta` key `audit_device_id` (same key as
   `AuditContextService`). If missing, generates a UUID v4 and persists it.

3. For every sync table **except** `audit_logs`, a single bulk `UPDATE` sets:
   - `businessId = COALESCE(businessId, 'local-business')`
   - `branchId = COALESCE(branchId, 'main-branch')`
   - `deviceId = COALESCE(deviceId, <resolved device id>)`
   only where any of the three is still `NULL`.

4. **`audit_logs` backfill** drops immutability triggers (`trg_audit_no_update`,
   `trg_audit_no_delete`), runs the same `UPDATE`, then recreates the triggers.
   Existing forensic `deviceId` values are preserved via `COALESCE`; only `NULL`
   deviceIds receive the resolved value.

5. `seedDefaultMenu()` spreads the same scope stamp on seeded categories and
   products during first install.

## Insert Behavior After Fix

`DatabaseService.syncScope()` returns:

```dart
{
  'businessId': 'local-business',
  'branchId': 'main-branch',
  'deviceId': <stable UUID from app_meta>,
}
```

Every write method that targets a sync-critical table spreads `...scope` into
the insert map. Covered methods:

`upsertCurrentOrderMeta`, `replaceCurrentOrderLines`, `insertKitchenPrint`,
`insertCategory`, `insertProduct`, `insertWaiter`, `insertSale`,
`insertSaleWithLines`, `insertExpense`, `upsertWaiterSalary`, `insertAdvance`,
`setWorkedDay`, `insertShiftRecord`, `insertSaleAdjustment`, `insertAuditLog`.

`insertAuditLog` sets `businessId` / `branchId` from scope and uses the
caller-supplied `deviceId` when present, otherwise falls back to scope `deviceId`.

No existing query that reads by local `id` is changed.

## What Was Not Changed

- **UI** — no screen or widget files changed.
- **Backend / cloud / sync engine** — none added; columns are data-only.
- **Existing local integer / TEXT primary keys** — unchanged.
- **UUID logic** — unchanged from v17.
- **Hash-chaining in `audit_logs`** — unchanged; only scope columns added/backfilled.
- **Restore pipeline, backup encryption, PIN logic** — unchanged.
- **`createdAt` / `updatedAt` / `deletedAt`** — out of scope (next task).

## Manual Test Checklist

- [ ] Launch app on a device with an existing v17 database — confirm it opens
      without errors and all data loads.
- [ ] Open Sales, Waiters, Products — confirm existing records display correctly.
- [ ] Query SQLite: `SELECT businessId, branchId, deviceId FROM sales LIMIT 5`
      — all three must be non-null on pre-upgrade rows after migration.
- [ ] Create a new sale — confirm new `sales` and `sale_lines` rows have
      `businessId = 'local-business'`, `branchId = 'main-branch'`, and a
      non-null `deviceId` matching `app_meta.audit_device_id`.
- [ ] Add a product and category — confirm scope columns populated.
- [ ] Open and close a shift — confirm `shifts` scope columns populated.
- [ ] Write a new audit log entry — confirm `businessId`, `branchId`, and
      `deviceId` are set; historical rows should also be backfilled.
- [ ] Confirm local `id` columns and FK references still work (receipts, orders).
- [ ] Run `flutter analyze` — exactly 78 issues.

## Next Step

Add `createdAt`, `updatedAt`, and `deletedAt` fields to sync-critical tables for
soft-delete and incremental sync cursors.
