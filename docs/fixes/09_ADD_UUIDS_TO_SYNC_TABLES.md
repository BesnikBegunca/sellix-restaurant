# 09 — Add UUIDs to Sync-Critical Tables

## Problem

Every table that will eventually be synced to a NestJS + PostgreSQL backend used
`INTEGER PRIMARY KEY AUTOINCREMENT` as its only identifier.  Autoincrement
integers are device-local and unstable across devices: the same row from two
different POS terminals, two different database restores, or two different branch
databases would all receive `id = 1`.  There is no safe way to merge these
records into a shared backend without a stable, globally unique key.

## Risk

| Scenario | Problem without UUIDs |
|---|---|
| Two POS terminals sync to the same backend | `sales.id = 5` from terminal A collides with `sales.id = 5` from terminal B |
| Database restore on another device | IDs restart from 1 on the restored DB |
| Multi-branch / multi-business deployment | Every branch has its own sequence starting at 1 |
| Offline-first merge | No way to deduplicate records during a sync merge |

UUID v4 keys are statistically unique across all devices, databases, and time —
making them safe for any future sync or merge strategy.

## Files Changed

| File | Change type |
|---|---|
| `lib/services/database_schema.dart` | UUID generator, column migration in `ensureTables()`, backfill, seed update |
| `lib/services/database_service.dart` | Version bump 16 → 17, uuid added to every insert method |

## Database Changes

`uuid TEXT` column added to all 16 sync-critical tables:

| Table | Notes |
|---|---|
| `sales` | One UUID per completed sale |
| `sale_lines` | One UUID per line item |
| `sale_adjustments` | One UUID per refund/void/discount |
| `expenses` | One UUID per expense entry |
| `shifts` | One UUID per shift archive record |
| `products` | One UUID per product (in addition to existing TEXT PK) |
| `categories` | One UUID per category (in addition to existing TEXT PK) |
| `waiters` | One UUID per waiter |
| `waiter_salaries` | One UUID per salary row |
| `advances` | One UUID per advance payment |
| `waiter_worked_days` | One UUID per worked-day record |
| `audit_logs` | One UUID per log entry (new rows only — see Backfill) |
| `current_orders` | One UUID per active order slot |
| `current_order_lines` | One UUID per active order line |
| `kitchen_prints` | One UUID per kitchen print batch |
| `kitchen_print_lines` | One UUID per kitchen print line |

A `UNIQUE INDEX` on `uuid WHERE uuid IS NOT NULL` (partial index) is created for
every table.  Partial index syntax requires SQLite 3.8.9+ (2015) which is met by
all supported platforms.

## Migration Strategy

**Schema version bumped: 16 → 17.**

All changes are applied via the existing `upgrade()` / `ensureTables()` pipeline:

1. `ensureTables()` runs `ALTER TABLE "<table>" ADD COLUMN uuid TEXT` for every
   sync table, wrapped in `try-catch` for idempotency (safe no-op if the column
   already exists).

2. `ensureTables()` creates a `UNIQUE INDEX … WHERE uuid IS NOT NULL` per table,
   also wrapped in `try-catch`.

3. `upgrade()` calls `_backfillUuids(db)` after `ensureTables()`.

4. `_backfillUuids(db)` iterates every backfillable table, queries
   `SELECT rowid FROM "<table>" WHERE uuid IS NULL`, and updates each row with a
   freshly generated UUID v4.  Using SQLite's implicit `rowid` makes this work
   uniformly for all PK types (INTEGER AUTOINCREMENT, TEXT, and tables with no
   explicit PK such as `current_orders`).

5. **`audit_logs` is excluded from backfill.**  Immutability triggers
   (`trg_audit_no_update`) block `UPDATE` on that table at the database level.
   Historical audit entries retain `uuid = NULL`; all new entries receive a UUID
   at insert time.

Seed data inserted by `seedDefaultMenu()` (categories and products) also receives
UUIDs via `{...map, 'uuid': generateUuid()}` spread syntax.

## UUID Generator

`DatabaseSchema.generateUuid()` — no external package required:

```dart
static String generateUuid() {
  final rng = Random.secure();       // cryptographically secure RNG (dart:math)
  final b = List<int>.generate(16, (_) => rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;     // version 4
  b[8] = (b[8] & 0x3f) | 0x80;     // variant 10xx (RFC 4122)
  // format as xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  ...
}
```

## Insert Behavior After Fix

Every write method in `DatabaseService` that targets a sync-critical table now
includes `'uuid': DatabaseSchema.generateUuid()` in the insert map.  Covered
methods:

`upsertCurrentOrderMeta`, `replaceCurrentOrderLines`, `insertKitchenPrint`,
`insertCategory`, `insertProduct`, `insertWaiter`, `insertSale`,
`insertSaleWithLines`, `insertExpense`, `upsertWaiterSalary`, `insertAdvance`,
`setWorkedDay`, `insertShiftRecord`, `insertSaleAdjustment`, `insertAuditLog`.

No existing query that reads by local `id` is changed.  All `where: 'id = ?'`
clauses and FK references remain intact.

## What Was Not Changed

- **UI** — no screen or widget files changed.
- **Backend / cloud / sync engine** — none added; uuid columns are data-only.
- **businessId / branchId / deviceId** — out of scope (next task).
- **Existing local integer IDs** — all `INTEGER PRIMARY KEY AUTOINCREMENT`
  columns remain as-is; uuid is an additive column.
- **Hash-chaining in `audit_logs`** — unchanged; uuid is appended to the insert
  alongside existing `prevHash` / `rowHash` logic.
- **Restore pipeline, backup encryption, PIN logic** — unchanged.

## Manual Test Checklist

- [ ] Launch app on a device with an existing database — confirm it opens without
      errors and all data loads.
- [ ] Open Sales, Waiters, Products sections — confirm existing records display
      correctly.
- [ ] Create a new sale — then query SQLite directly or check via debug prints:
      `sales.uuid` and `sale_lines.uuid` must be non-null RFC 4122 strings.
- [ ] Add a new product and category — confirm `uuid` is populated.
- [ ] Add a new waiter — confirm `waiters.uuid` is populated.
- [ ] Open a shift — confirm `shifts.uuid` is populated on close.
- [ ] Verify existing records (before upgrade) also have non-null UUIDs (backfill
      succeeded).
- [ ] Confirm `audit_logs` new entries have uuid; historical entries may have
      `null` (expected — immutability trigger prevents backfill).
- [ ] Confirm no duplicate UUIDs in any table (each is a freshly generated v4).
- [ ] Confirm local IDs (`id` column) still work: existing FK queries, receipt
      numbers, and order references unchanged.
- [ ] Run `flutter analyze` — exactly 78 issues.

## Next Step

Next task: Add businessId / branchId / deviceId to sync-critical tables.
