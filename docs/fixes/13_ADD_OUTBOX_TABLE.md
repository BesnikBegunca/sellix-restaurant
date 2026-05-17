# 13 — Add Outbox Table

## Problem

Sync-critical entity rows gained per-row `syncStatus` and `lastSyncedAt` fields
(v20), but there was still **no durable queue** of local mutations. Row-level
status alone cannot represent ordered create/update/delete events, retry history,
or JSON payloads ready for the API. A future NestJS sync worker needs an append-only
**outbox** that survives app restarts and records exactly what must be uploaded.

## Risk

| Scenario | Problem without an outbox |
|---|---|
| App crash mid-upload | In-flight change may be lost with no replay record |
| Ordering | Multiple operations on one entity need FIFO ordering independent of table scans |
| Retries | Failed uploads need `retryCount`, `lastError`, and `lastAttemptAt` per event |
| Payload versioning | Server needs structured `payloadJson` per operation, not full table dumps |
| Offline edits | Local creates/updates/deletes must queue before any network is available |

## Files Changed

| File | Change type |
|---|---|
| `lib/services/database_schema.dart` | `ensureOutboxTable()`, v21 migration, outbox constants |
| `lib/services/database_service.dart` | Version bump 20 → 21, four outbox helper methods |

## Database Changes

**Schema version bumped: 20 → 21.**

New table `outbox` (created via `CREATE TABLE IF NOT EXISTS` in
`ensureOutboxTable()`, called from `ensureTables()`):

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | Local queue row id |
| `uuid` | TEXT NOT NULL UNIQUE | Stable event id for idempotent sync |
| `businessId` | TEXT NOT NULL | Tenant scope |
| `branchId` | TEXT NOT NULL | Branch scope |
| `deviceId` | TEXT NOT NULL | Originating device |
| `entityType` | TEXT NOT NULL | e.g. `sales`, `products` |
| `entityUuid` | TEXT NOT NULL | Target row's `uuid` |
| `operation` | TEXT NOT NULL | `create` \| `update` \| `delete` |
| `payloadJson` | TEXT NOT NULL | Serialized change payload |
| `syncStatus` | TEXT NOT NULL DEFAULT `pending` | Queue state |
| `retryCount` | INTEGER NOT NULL DEFAULT 0 | Failed attempt counter |
| `lastError` | TEXT | Last failure message |
| `createdAt` | TEXT NOT NULL | Event enqueue time |
| `updatedAt` | TEXT NOT NULL | Last state change |
| `lastAttemptAt` | TEXT | Last upload attempt |
| `lastSyncedAt` | TEXT | Set when marked synced |

**Indexes:**

| Index | Column |
|---|---|
| `idx_outbox_sync_status` | `syncStatus` |
| `idx_outbox_entity_type` | `entityType` |
| `idx_outbox_entity_uuid` | `entityUuid` |
| `idx_outbox_created_at` | `createdAt` |

No backfill required — table starts empty on upgrade.

## New Database Helpers

| Method | Purpose |
|---|---|
| `insertOutboxEvent(...)` | Inserts a pending event with generated `uuid`, scope from `syncScope()` unless overridden, validates `operation`, returns event `uuid` |
| `getPendingOutboxEvents({limit})` | Returns rows where `syncStatus = 'pending'`, ordered by `createdAt ASC` (FIFO) |
| `markOutboxEventSynced(uuid)` | Sets `syncStatus = 'synced'`, `lastSyncedAt` and `updatedAt` to now, clears `lastError` |
| `markOutboxEventFailed(uuid, error)` | Sets `syncStatus = 'failed'`, stores `lastError`, increments `retryCount`, sets `lastAttemptAt` |

Constants in `DatabaseSchema`: `outboxOperations`, `kOutboxSyncSynced`, `kOutboxSyncFailed`.

## What Was Not Changed

- **UI** — no screen or widget files changed.
- **Backend / cloud / API** — no network code added.
- **Sync engine** — no worker processes pending events.
- **Wiring** — sales, products, expenses, and other entities do **not** enqueue outbox rows yet.
- **Existing table schemas and app behavior** — unchanged.

## Manual Test Checklist

- [ ] Existing database opens successfully
- [ ] `outbox` table exists (`SELECT name FROM sqlite_master WHERE name='outbox'`)
- [ ] Indexes exist (`idx_outbox_sync_status`, etc.)
- [ ] `insertOutboxEvent` returns a uuid and row is readable
- [ ] `getPendingOutboxEvents` returns pending rows in `createdAt` order
- [ ] `markOutboxEventSynced` sets `syncStatus = 'synced'` and `lastSyncedAt`
- [ ] `markOutboxEventFailed` sets `syncStatus = 'failed'`, `lastError`, and increments `retryCount`
- [ ] No existing app behavior changed (sales, menu, shifts work as before)
- [ ] Run `flutter analyze`

## Next Step

Next task: Queue sync-critical changes into outbox.
