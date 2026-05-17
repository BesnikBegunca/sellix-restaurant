# 11 — Add Sync Timestamps

## Problem

Sync-critical SQLite rows had stable `uuid` keys and tenant/device scope columns
(v17–v18) but lacked **consistent** `createdAt`, `updatedAt`, and `deletedAt`
fields across all tables. Some tables already used domain-specific names
(`timestamp`, `openedAt`, `printedAt`) or partial overlap (`sale_lines.createdAt`,
`current_orders.updatedAt`, `audit_logs.createdAt`). A future NestJS +
PostgreSQL sync needs uniform sync timestamps on every row for incremental
cursors, conflict detection, and soft-delete support.

## Risk

| Scenario | Problem without sync timestamps |
|---|---|
| Incremental sync | Backend cannot query “rows changed since T” reliably |
| Multi-device merge | No `updatedAt` to resolve last-write-wins or ordering |
| Soft delete | No `deletedAt` column to tombstone rows without hard DELETE |
| Inconsistent schema | Some tables use `timestamp`, others `createdAt` — sync layer must special-case every table |

## Files Changed

| File | Change type |
|---|---|
| `lib/services/database_schema.dart` | Column migration (v19), `syncTimestampStamp()`, backfill SQL, seed update, `_withAuditLogsUnlocked` refactor |
| `lib/services/database_service.dart` | Version bump 18 → 19, `syncTimestamps()` helper, timestamps on every sync insert |

## Database Changes

**Schema version bumped: 18 → 19.**

Missing columns added via `ALTER TABLE` (idempotent `try/catch`). Tables that
already had a column name are skipped in the add map:

| Table | Columns added | Existing column reused |
|---|---|---|
| `sales` | createdAt, updatedAt, deletedAt | `timestamp` → createdAt |
| `sale_lines` | updatedAt, deletedAt | `createdAt` (domain) kept |
| `sale_adjustments` | updatedAt, deletedAt | `createdAt` (domain) kept |
| `expenses` | createdAt, updatedAt, deletedAt | `timestamp` → createdAt |
| `shifts` | createdAt, updatedAt, deletedAt | `openedAt` / `closedAt` |
| `products` | createdAt, updatedAt, deletedAt | — |
| `categories` | createdAt, updatedAt, deletedAt | — |
| `waiters` | createdAt, updatedAt, deletedAt | `pinUpdatedAt` fallback |
| `waiter_salaries` | createdAt, updatedAt, deletedAt | — |
| `advances` | createdAt, updatedAt, deletedAt | `timestamp` → createdAt |
| `waiter_worked_days` | createdAt, updatedAt, deletedAt | `workDate` → createdAt |
| `audit_logs` | updatedAt, deletedAt | `createdAt` (forensic) kept |
| `current_orders` | createdAt, deletedAt | `updatedAt` (domain) kept |
| `current_order_lines` | createdAt, updatedAt, deletedAt | — |
| `kitchen_prints` | createdAt, updatedAt, deletedAt | `printedAt` → createdAt |
| `kitchen_print_lines` | createdAt, updatedAt, deletedAt | parent `printedAt` via subquery |

All types are `TEXT` (ISO-8601 strings), matching existing date storage.

## Backfill Strategy

`upgrade()` calls `_backfillSyncTimestamps(db)` after scope backfill.

Per-table rules (`COALESCE` preserves any value already set):

| Table | createdAt source | updatedAt source | deletedAt |
|---|---|---|---|
| `sales` | `timestamp` | same as createdAt | `NULL` |
| `sale_lines` | *(existing)* | `createdAt` | `NULL` |
| `sale_adjustments` | *(existing)* | `createdAt` | `NULL` |
| `expenses` | `timestamp` | same as createdAt | `NULL` |
| `shifts` | `openedAt` | `COALESCE(closedAt, openedAt)` | `NULL` |
| `products`, `categories`, `waiter_salaries` | migration `now` | same as createdAt | `NULL` |
| `waiters` | `pinUpdatedAt` or `now` | same as createdAt | `NULL` |
| `advances` | `timestamp` | same as createdAt | `NULL` |
| `waiter_worked_days` | `workDate` | same as createdAt | `NULL` |
| `current_orders` | `updatedAt` | *(existing)* | `NULL` |
| `current_order_lines` | migration `now` | same as createdAt | `NULL` |
| `kitchen_prints` | `printedAt` | same as createdAt | `NULL` |
| `kitchen_print_lines` | parent `printedAt` or `now` | same as createdAt | `NULL` |
| `audit_logs` | *(existing)* | `createdAt` | `NULL` |

`audit_logs` backfill runs inside `_withAuditLogsUnlocked()` (triggers dropped
temporarily, then recreated). Hash-chain fields are untouched.

Legacy columns (`timestamp`, `openedAt`, `printedAt`, etc.) are **not** removed.

## Insert Behavior After Fix

`DatabaseSchema.syncTimestampStamp()` / `DatabaseService.syncTimestamps()` return:

```dart
{'createdAt': iso, 'updatedAt': iso}  // or updatedAt only when createdAt exists
```

Every sync-critical insert spreads timestamps alongside scope/uuid:

- Full stamp: `sales`, `expenses`, `products`, `categories`, `waiters`,
  `waiter_salaries`, `advances`, `current_order_lines`, `kitchen_print_lines`, etc.
- `createdAt` only + explicit `updatedAt`: `sale_lines`, `sale_adjustments`,
  `shifts`, `waiter_worked_days`, `kitchen_prints`
- `createdAt` + existing `updatedAt`: `current_orders`
- `createdAt` + `updatedAt` on audit: `audit_logs` (hash input unchanged)

`deletedAt` is never set on insert (remains `NULL`).

## What Was Not Changed

- **UI** — no screen or widget files changed.
- **Backend / cloud / sync engine** — none added.
- **syncStatus / outbox** — not added (next task).
- **Soft-delete behavior** — `deletedAt` column only; hard DELETE paths unchanged.
- **Audit hash-chain** — `prevHash` / `rowHash` computation unchanged.
- **Existing local IDs and UUID logic** — unchanged.
- **Domain timestamp columns** — preserved (`timestamp`, `openedAt`, `printedAt`, etc.).

## Manual Test Checklist

- [ ] Existing database opens successfully
- [ ] Existing sales still load
- [ ] Existing waiters/products/categories still load
- [ ] Existing rows have `createdAt` and `updatedAt` populated after migration
- [ ] `deletedAt` is `NULL` by default on all rows
- [ ] New sale receives `createdAt` and `updatedAt` (and legacy `timestamp`)
- [ ] New product/category/waiter receives `createdAt` and `updatedAt`
- [ ] Existing timestamp fields (`timestamp`, `openedAt`, `printedAt`) still work
- [ ] Run `flutter analyze`

## Next Step

Next task: Add `syncStatus` and `lastSyncedAt`.
