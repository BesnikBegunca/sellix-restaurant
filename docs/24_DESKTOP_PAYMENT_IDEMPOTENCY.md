# Desktop Payment Idempotency & Print Safety

Hardening the POS payment flow so duplicate taps, retries, and printer
failures cannot create duplicate sales or lose committed transactions.

---

## Previous risk

| Issue | Impact |
|-------|--------|
| `_isPaying` UI guard only | Double-tap / retry could race past UI |
| New `sales.uuid` per insert | No stable idempotency key |
| Print **before** DB commit | Receipt without sale, or sale without receipt on partial failure |
| Print errors swallowed | Operator unaware |
| No reprint in Sales History | Could not recover after print failure |

---

## New payment sequence

```
User taps PAGUAJ
  → resolve stable saleUuid (app_meta pending + sales.uuid UNIQUE)
  → SQLite transaction: insert sale + lines OR return existing
  → outbox enqueue once per entity uuid
  → print payment receipt (after commit)
  → success dialog
  → clearTable + clear pending uuid
  → if print failed: snackbar warning (sale kept)
```

**Policy: commit-first, print-after.** Printer failure never rolls back the sale.

---

## Idempotency key

- **`sales.uuid`** — client-generated UUID v4 before save (`DatabaseSchema.generateUuid()`).
- **UNIQUE index** on `sales(uuid)` (existing migration).
- **Pending meta** `payment_pending_{tableId}_{waiterName}` in `app_meta` survives retry/crash until `clearTable`.

`insertSaleWithLines(saleUuid: …)`:

1. If sale with uuid exists → return `SaleInsertResult(wasExisting: true)` — no new lines, no duplicate outbox.
2. Else insert sale + lines + outbox (with duplicate outbox guard).
3. On UNIQUE race → treat as existing.

---

## Outbox idempotency

`_queueOutboxByIdIfAbsent` skips enqueue when an outbox row already exists for the same `(entityType, entityUuid, operation)`.

Sale push uses entity uuid from the sale row — one create event per sale on the server.

---

## Failure scenarios

| Case | Behavior |
|------|----------|
| A. DB OK, print fails | Sale saved; warning snackbar; reprint from history |
| B. DB fails | Error snackbar; no print; order kept |
| C. Double tap | One sale row (uuid + transaction) |
| D. Crash after commit | Sale in DB; pending uuid until clear; retry returns existing |
| E. Crash before commit | No sale; order lines remain |

---

## Reprint

**Sales History** → expanded sale → **Ridërgo kuponin**  
Uses `SaleReceiptService.reprintPaymentReceipt` with snapshotted `sale_lines` data.

---

## Files

| File | Change |
|------|--------|
| `lib/models/sale_insert_result.dart` | Idempotent insert result |
| `lib/services/database_service.dart` | Transaction guard, pending meta, outbox dedup |
| `lib/manager/manager_data_sales.dart` | `saleUuid`, `resolvePaymentSaleUuid` |
| `lib/screens/pos_order_screen.dart` | Save-first, print-after |
| `lib/services/sale_receipt_service.dart` | History reprint |
| `lib/features/sales_history/widgets/sale_card.dart` | Reprint button |
| `lib/screens/sales_history_screen.dart` | Reprint handler |

---

## Manual test checklist

- [ ] Double-click **PAGUAJ** rapidly → one `sales` row, one outbox sale event
- [ ] Disconnect printer → sale saved, warning shown, **Ridërgo kuponin** works
- [ ] Kill app after payment commit → sale visible after restart; paying again does not duplicate (same pending uuid)
- [ ] UI freeze + retry → existing sale returned (`wasExisting`)
- [ ] Sync push → one sale on server per uuid

---

## Unchanged

- Offline-first SQLite
- No pos_api / mobile changes
- No automatic sale deletion
- Minimal UI change (one reprint button)
