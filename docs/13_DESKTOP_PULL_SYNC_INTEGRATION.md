# Desktop Pull Sync Integration

Pull-direction sync: the Flutter Desktop POS downloads changes from the NestJS backend via `GET /sync/pull` and applies them atomically to local SQLite.

---

## Files Changed

| File | Action |
|------|--------|
| `lib/config/api_config.dart` | Added `kEndpointSyncPull` constant |
| `lib/services/database_service.dart` | Added `getPullCursor()` + `setPullCursor()` |
| `lib/services/pull_sync_apply_service.dart` | Created — applies pull response to SQLite |
| `lib/services/background_sync_service.dart` | Added `pullSyncNow()`, `_isPulling` guard, `_parsePullResponse()`, `_SyncPullResult` |

---

## Endpoint

```
GET /sync/pull?since=[ISO-8601]&limit=[int]
Authorization: Bearer <access-token>
```

### Response

```json
{
  "serverTime": "2026-05-18T12:00:00.000Z",
  "cursor":     "2026-05-18T11:59:59.000Z",
  "entities": {
    "categories":       [...],
    "products":         [...],
    "shifts":           [...],
    "sales":            [...],
    "sale_lines":       [...],
    "sale_adjustments": [...],
    "expenses":         [...],
    "inventory_items":  [...],
    "stock_movements":  [...]
  }
}
```

`cursor` is the max `updatedAt` across all returned rows (or `since` if nothing returned). The client stores this value and sends it as `since` on the next pull to receive only changes newer than the previous batch.

---

## Pull Flow (`BackgroundSyncService.pullSyncNow`)

```
1. Guard checks:
   ├─ offline?        → return (no backoff; retry on next connectivity event)
   ├─ _isPulling?     → return (concurrent protection)
   └─ not activated?  → return

2. Read sync_pull_cursor from app_meta
   └─ null on first pull → omit since parameter (full initial sync)

3. GET /sync/pull?since=<cursor>&limit=200
   ├─ 401? → refreshActivationToken(), retry once
   └─ other network error → log, return (cursor unchanged)

4. Parse response → _SyncPullResult
   └─ malformed? → log, return (cursor unchanged)

5. db.transaction:
   └─ PullSyncApplyService.applyEntities(entities, txn, syncedAt)
       ├─ categories → products → shifts → sales → sale_lines
       │   → sale_adjustments → expenses → inventory_items → stock_movements
       └─ any exception → full rollback, cursor NOT updated

6. Persist cursor (only after successful transaction commit)
```

---

## Cursor Persistence

- Key: `sync_pull_cursor` in `app_meta` table
- Written only after the SQLite transaction commits
- On any failure (network, parse, DB error) the cursor stays at the previous value — the same batch is retried on the next pull

---

## `PullSyncApplyService`

Located at `lib/services/pull_sync_apply_service.dart`.

### Entity Apply Logic (per entity)

```
For each entity in the server list:
  1. Extract uuid — skip if null
  2. Query local row by uuid
  3. If local row found AND syncStatus == 'pending':
       → skip (log conflict)
  4. If local row found AND syncStatus != 'pending':
       → UPDATE server fields only (preserve local-only fields)
  5. If no local row:
       → INSERT with syncStatus = 'synced'
  6. If deletedAt != null → mark as soft-deleted
```

### Conflict v1 Rule

When a local row has `syncStatus = 'pending'`, it has unsent local changes. The server row is skipped rather than overwriting local work-in-progress. The pending row will be pushed on the next outbox upload; the server will then have the client's version and it will arrive on the subsequent pull with the correct data.

### Soft-Delete Handling

If the incoming server entity has `deletedAt != null`, the local row's `deletedAt` is set to that value. The row is NOT hard-deleted — the local UI reads `WHERE deletedAt IS NULL` to filter active records.

### FK Resolution for sale_lines / sale_adjustments

`sale_lines.saleId` and `sale_adjustments.saleId` are local integer FKs. For new rows from the server, the parent sale is located by `saleUuid`:

```dart
SELECT id FROM sales WHERE uuid = ? LIMIT 1
```

If the parent sale is not found locally (e.g., it hasn't arrived yet), the child row is skipped. It will be applied on the next pull once the parent arrives.

### Transaction Safety

All entity applies run inside a single SQLite transaction provided by the caller. Any uncaught exception propagates back to `pullSyncNow()`, which does not advance the cursor. The next pull will retry the full batch.

---

## Local-Only Fields

These fields exist in SQLite but have no server equivalent. They are NOT updated by pull sync — they preserve their local values:

| Table | Local-only fields |
|-------|-------------------|
| `categories` | `iconCodePoint` |
| `products` | `emoji`, `imagePath` |
| `shifts` | `openedBy`, `closedBy`, `closingCash`, `totalSales`, `totalExpenses`, `netProfit`, `snapshotJson` |
| `sales` | `waiterName`, `tableId`, `shiftId` |
| `sale_lines` | `productEmoji`, `productImagePath`, `categoryName`, `tableName`, `waiterName` |
| `sale_adjustments` | `saleLineId`, `productName`, `quantity`, `createdBy` |
| `expenses` | `shiftId` |

New rows inserted from server get sensible defaults for required NOT NULL local fields (e.g., `waiterName = ''`, `tableId = 0`, `iconCodePoint = 0`).

---

## Trigger Points

`pullSyncNow()` is called from:
- `BackgroundSyncService.start()` — immediately on activation (alongside push)
- `_onConnectivityChanged` — when device comes back online

---

## Manual Test Checklist

- [ ] On first activation: pull runs, `sync_pull_cursor` is set in `app_meta`
- [ ] Subsequent pull: sends `?since=<cursor>`, receives only newer records
- [ ] Server-created category appears in local `categories` table after pull
- [ ] Category with `deletedAt` has `deletedAt` populated locally after pull
- [ ] Local row with `syncStatus = 'pending'` is NOT overwritten by server version
- [ ] `sale_line` whose parent `sale` is missing locally → skipped (no crash)
- [ ] Network error during pull → cursor unchanged, retried on reconnect
- [ ] Malformed response → cursor unchanged, no partial apply
- [ ] DB error mid-transaction → full rollback, cursor unchanged

---

## curl Example

```bash
TOKEN="<access-jwt>"
CURSOR="2026-05-18T00:00:00.000Z"

curl -s "http://localhost:3000/api/sync/pull?since=$CURSOR&limit=200" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```
