# 12 — Add Sync Status

## Problem

Sync-critical SQLite rows had stable identifiers (`uuid`), tenant/device scope
(`businessId`, `branchId`, `deviceId`), and lifecycle timestamps
(`createdAt`, `updatedAt`, `deletedAt`), but no field recording **sync state**.
The backend (future NestJS + PostgreSQL) would have no way to know whether a row
is waiting to upload, already replicated, or failed — without scanning every
column or maintaining a separate shadow table.

## Risk

| Scenario | Problem without sync status |
|---|---|
| Incremental upload | Cannot query “all pending rows since last sync” |
| Retry after failure | No `failed` marker to distinguish from never-tried rows |
| Idempotent replay | Cannot skip rows already acknowledged by the server |
| Multi-table sync jobs | Worker must guess state from absence of `lastSyncedAt` alone |

## Files Changed

| File | Change type |
|---|---|
| `lib/services/database_schema.dart` | `kSyncStatusPending`, `syncStatusStamp()`, v20 column migration, backfill, seed update |
| `lib/services/database_service.dart` | Version bump 19 → 20, `syncStatus()` helper, status on every sync insert |

## Database Changes

**Schema version bumped: 19 → 20.**

`syncStatus TEXT` and `lastSyncedAt TEXT` added to all 16 sync-critical tables:

| Table |
|---|
| `sales` |
| `sale_lines` |
| `sale_adjustments` |
| `expenses` |
| `shifts` |
| `products` |
| `categories` |
| `waiters` |
| `waiter_salaries` |
| `advances` |
| `waiter_worked_days` |
| `audit_logs` |
| `current_orders` |
| `current_order_lines` |
| `kitchen_prints` |
| `kitchen_print_lines` |

Columns are added via `ALTER TABLE … ADD COLUMN` inside `ensureTables()`, each
wrapped in `try/catch` for idempotency.

## Backfill Strategy

`upgrade()` calls `_backfillSyncStatus(db)` after timestamp backfill.

For every sync table (15 tables via bulk `UPDATE`; `audit_logs` inside
`_withAuditLogsUnlocked()` because immutability triggers block `UPDATE`):

```sql
UPDATE "<table>" SET
  syncStatus = COALESCE(syncStatus, 'pending'),
  lastSyncedAt = NULL
WHERE syncStatus IS NULL
```

**Why mark existing rows `pending`?**  
All local data predates any sync engine. Treating every historical row as pending
ensures the first future sync pass uploads the full dataset once, then flips rows
to `synced` only when the engine explicitly does so. Nothing is marked `synced`
during this migration.

`lastSyncedAt` is explicitly set to `NULL` — no row has ever been uploaded.

## Insert Behavior After Fix

`DatabaseSchema.syncStatusStamp()` / `DatabaseService.syncStatus()` return:

```dart
{'syncStatus': 'pending', 'lastSyncedAt': null}
```

Every sync-critical insert spreads this map alongside `uuid`, scope, and
timestamps. No insert sets `synced` or `failed`; no code writes
`lastSyncedAt` yet.

## What Was Not Changed

- **UI** — no screen or widget files changed.
- **Backend / cloud** — no API calls or network code added.
- **Outbox table** — not added (next task).
- **Sync engine** — no upload, download, or conflict resolution logic.
- **Soft-delete behavior** — `deletedAt` column unchanged; hard DELETE paths unchanged.
- **Existing local IDs, UUIDs, timestamps, scope columns** — unchanged.

## Manual Test Checklist

- [ ] Existing database opens successfully
- [ ] Existing rows have `syncStatus = 'pending'` after migration
- [ ] Existing rows have `lastSyncedAt = NULL`
- [ ] New sale gets `syncStatus = 'pending'` and `lastSyncedAt = NULL`
- [ ] New product/category/waiter gets `syncStatus = 'pending'`
- [ ] No backend calls are made
- [ ] Run `flutter analyze`

## Next Step

Next task: Add outbox table.
