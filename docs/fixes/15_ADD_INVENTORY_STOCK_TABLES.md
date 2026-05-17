# 15 — Add Inventory / Stock Tables

## Problem

The POS had **products** (menu items with price and category) but no database layer
for **inventory**: on-hand quantity, units, cost, low-stock thresholds, or an
audit trail of stock changes. A future mobile dashboard cannot show “in stock /
low / out” without `inventory_items` and `stock_movements` tables.

## Risk

| Scenario | Problem without inventory tables |
|---|---|
| Mobile stock dashboard | No queryable source for quantity or alerts |
| Purchase / waste tracking | No immutable movement log |
| Multi-device sync | Stock changes cannot be queued in outbox like other entities |
| Sale-paid deduction (later) | No item to decrement when linking sales to stock |

## Files Changed

| File | Change type |
|---|---|
| `lib/services/database_schema.dart` | `stockMovementTypes`, `stockQuantityDelta()`, `ensureInventoryTables()`, v22 migration |
| `lib/services/database_service.dart` | Version bump 21 → 22, six inventory/stock helpers + outbox wiring |

## Database Changes

**Schema version bumped: 21 → 22.**

### `inventory_items`

Tracks a stock SKU (optionally linked to a product via `productUuid`).

| Column | Purpose |
|---|---|
| `uuid` | Stable sync key (UNIQUE) |
| `productUuid` | Optional link to `products.uuid` |
| `name`, `unit` | Display / measurement |
| `currentQuantity` | On-hand amount |
| `lowStockThreshold` | Alert when `currentQuantity <= threshold` |
| `costPerUnit` | Cost basis |
| `isActive` | 1 = active, 0 = archived |
| Scope + sync columns | Same pattern as other sync-critical tables |

### `stock_movements`

Append-only style log of quantity changes per `inventoryItemUuid`.

| Column | Purpose |
|---|---|
| `movementType` | `purchase` \| `sale` \| `adjustment` \| `waste` \| `return` |
| `quantity` | Amount (see movement rules) |
| `reason`, `referenceType`, `referenceUuid` | Optional provenance |
| Scope + sync columns | Same pattern as other sync-critical tables |

### Indexes

| Index | Column(s) |
|---|---|
| `idx_inventory_items_uuid` | `uuid` |
| `idx_inventory_items_product_uuid` | `productUuid` |
| `idx_inventory_items_is_active` | `isActive` |
| `idx_stock_movements_item_uuid` | `inventoryItemUuid` |
| `idx_stock_movements_type` | `movementType` |
| `idx_stock_movements_created_at` | `createdAt` |

## New Database Helpers

| Method | Purpose |
|---|---|
| `insertInventoryItem(...)` | Creates item with sync stamps; outbox `create` |
| `updateInventoryItem(id, fields)` | Patches item; outbox `update` or `delete` if soft-deleted |
| `getInventoryItems({includeInactive})` | Lists non-deleted items (active by default) |
| `getLowStockItems()` | `currentQuantity <= lowStockThreshold`, active |
| `insertStockMovement(...)` | Inserts movement, updates quantity in one transaction; outbox movement `create` + item `update` |
| `getStockMovementsForItem(uuid)` | History for one item, newest first |

## Stock Movement Rules

| `movementType` | Effect on `currentQuantity` |
|---|---|
| `purchase` | `+ abs(quantity)` |
| `return` | `+ abs(quantity)` |
| `sale` | `- abs(quantity)` |
| `waste` | `- abs(quantity)` |
| `adjustment` | `+ quantity` (signed delta; may increase or decrease) |

All applied inside a **single SQLite transaction** with the movement insert.
Invalid `movementType` throws `ArgumentError`. Missing inventory item throws
`StateError`.

**Not implemented:** automatic stock deduction when a POS sale is paid (separate
future task).

## Outbox Behavior

| Action | Outbox events |
|---|---|
| `insertInventoryItem` | `inventory_items` → `create` |
| `updateInventoryItem` | `inventory_items` → `update` or `delete` (if `deletedAt` set or `isActive = 0`) |
| `insertStockMovement` | `stock_movements` → `create`; `inventory_items` → `update` (quantity changed) |

Payloads are full row snapshots (`jsonEncode`), consistent with fix 14.

## What Was Not Changed

- **UI** — no inventory screens.
- **Backend / cloud / API** — none.
- **Automatic sale stock deduction** — paying a sale does not touch inventory.
- **Sync processing** — outbox is written but not uploaded.
- **Products / menu flow** — unchanged.

## Manual Test Checklist

- [ ] Existing database opens successfully
- [ ] `inventory_items` and `stock_movements` tables exist
- [ ] Add inventory item via `insertInventoryItem`
- [ ] `purchase` movement increases `currentQuantity`
- [ ] `sale` / `waste` movement decreases `currentQuantity`
- [ ] `getLowStockItems()` returns items at or below threshold
- [ ] Outbox rows created for item create and movement create
- [ ] Existing POS product/menu flow still works
- [ ] Run `flutter analyze`

## Next Step

Next task: Add `connectivity_plus`.
