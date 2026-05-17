# 14 — Queue Changes to Outbox

## Problem

The `outbox` table existed (v21) with helper methods to insert and mark events,
but **no application code enqueued local mutations**. Entity rows carried
`syncStatus = 'pending'`, yet the durable change log stayed empty. A future sync
worker would have no ordered record of creates, updates, or deletes to upload.

## Risk

| Scenario | Problem without outbox wiring |
|---|---|
| First sync run | Nothing to send despite thousands of pending entity rows |
| Crash recovery | Cannot replay unsent mutations independent of entity table scans |
| Ordering | Sale header and lines might be uploaded out of order without explicit events |
| Deletes | Hard-deleted rows leave no tombstone event for the server |

## Files Changed

| File | Change type |
|---|---|
| `lib/services/database_service.dart` | `_enqueueOutbox`, `_queueOutboxRow`, `_queueOutboxById`, outbox wiring on all listed write paths |

## Queued Operations

| Entity | Operation | Trigger |
|---|---|---|
| `sales` | create | `insertSale`, `insertSaleWithLines` |
| `sale_lines` | create | `insertSaleWithLines` (per line) |
| `expenses` | create | `insertExpense` |
| `products` | create | `insertProduct` |
| `products` | update | `updateProduct`, `moveProductCategory` |
| `products` | delete | `deleteProduct` |
| `categories` | create | `insertCategory` |
| `categories` | delete | `deleteCategory` |
| `waiters` | create | `insertWaiter` |
| `waiters` | update | `updateWaiterPin` |
| `waiters` | delete | `deleteWaiterById` |
| `waiter_salaries` | create / update | `upsertWaiterSalary` |
| `advances` | create | `insertAdvance` |
| `waiter_worked_days` | create | `setWorkedDay` (worked = true, new row only) |
| `waiter_worked_days` | delete | `setWorkedDay` (worked = false) |
| `shifts` | update | `closeShiftRecord` (shift archived/closed) |
| `sale_adjustments` | create | `insertSaleAdjustment` |
| `current_orders` | create / update | `upsertCurrentOrderMeta` |
| `current_order_lines` | create / delete | `replaceCurrentOrderLines` (delete old, create new) |
| `current_orders` | delete | `clearCurrentOrder` |
| `current_order_lines` | delete | `clearCurrentOrder` |
| `kitchen_prints` | create | `insertKitchenPrint` |
| `kitchen_print_lines` | create | `insertKitchenPrint` (per line) |

Not queued: schema migration, seed data, `clearSales`, `insertShiftRecord` (open only),
audit logs, app meta, company/settings, restaurant `tables` layout.

## Payload Strategy

`payloadJson` is `jsonEncode` of the **full SQLite row** after the write (or
immediately before delete), including:

- Local integer `id` (where applicable)
- `uuid`, `businessId`, `branchId`, `deviceId`
- Sync timestamps and `syncStatus`
- All domain columns (`timestamp`, `openedAt`, `printedAt`, etc.)

This gives the future NestJS worker enough context to upsert or tombstone without
re-querying every table during upload.

## Transaction Strategy

- **`insertSaleWithLines`**: single `db.transaction` — sale insert, each line
  insert, and matching outbox rows all commit or roll back together via optional
  `Transaction? txn` on `_enqueueOutbox`.
- **`replaceCurrentOrderLines`**, **`clearCurrentOrder`**, **`insertKitchenPrint`**:
  outbox events written inside the same transaction as entity changes.
- **Simple inserts** (product, expense, etc.): entity write then outbox enqueue
  immediately after (same logical flow; outbox follows successful insert).

No duplicate event is emitted for a single user action (e.g. one sale header
event + one event per line, not double sale events).

## What Was Not Changed

- **UI** — unchanged.
- **Backend / cloud / API** — no network calls.
- **Sync processing** — `getPendingOutboxEvents` is not polled automatically.
- **Connectivity** — not added.
- **Entity `syncStatus` on upload** — rows stay `pending`; nothing marked `synced`.
- **Migrations / seed** — no outbox events during backfill.

## Manual Test Checklist

- [ ] Existing database opens successfully
- [ ] Create sale → `outbox` rows for `sales` + each `sale_lines` (`operation = create`)
- [ ] Create expense → one `expenses` outbox event
- [ ] Add / update / delete product → matching outbox events
- [ ] Add / delete category → matching outbox events
- [ ] Add / update PIN / delete waiter → matching outbox events
- [ ] Upsert salary, insert advance, toggle worked day → matching events
- [ ] Close shift → `shifts` `update` event with closed snapshot fields
- [ ] Kitchen print → `kitchen_prints` + `kitchen_print_lines` events
- [ ] Confirm no backend calls are made
- [ ] Run `flutter analyze`

## Next Step

Next task: Add inventory / stock tables.
