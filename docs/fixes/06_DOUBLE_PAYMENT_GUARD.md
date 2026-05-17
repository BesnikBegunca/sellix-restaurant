# 06 — Double-Payment Guard

## Problem

The PAGUAJ (Pay) button in the POS order screen could be tapped multiple times in rapid succession while the payment was being processed. Each tap fired the same async `_payTable()` method. Without a visual indicator that payment was in progress, a waiter could double-click (or click again during the success animation delay) and trigger a second execution of the payment flow before the first had completed.

---

## Risk

- **Duplicate sale records** — A second `recordSaleWithLines()` call creates a second row in the `sales` and `sale_lines` tables for the same table and order. Reports and shift totals would count the revenue twice.
- **Duplicate receipts** — The thermal printer receipt would print twice. The customer receives two receipts for one payment, causing confusion and wasted paper.
- **Duplicate cash drawer kick** — The cash drawer would open twice, triggering double hardware events.
- **Incorrect audit trail** — Two `sale_created` audit entries for the same transaction distort compliance records and shift reports.
- **Double table clear** — `clearTable()` called twice on an already-cleared table, a harmless no-op in practice but semantically wrong.

---

## Files Changed

| File | What changed |
|------|-------------|
| `lib/screens/pos_order_screen.dart` | Added `audit_log_service.dart` import; `_payTable()` guard now calls `logDuplicatePaymentBlocked()` on blocked attempts; `OrderPanel` receives `isPaying: _isPaying` |
| `lib/features/pos_order/widgets/order_panel.dart` | Added `isPaying` field (default `false`); threads it to `PayButton` |
| `lib/features/pos_order/widgets/pay_button.dart` | Added `isPaying` prop (default `false`); shows spinner + muted appearance during payment; all interaction blocked while paying |
| `lib/services/audit_log_service.dart` | Added `AuditAction.duplicatePaymentBlocked` constant; added display label; added `logDuplicatePaymentBlocked()` typed helper |

---

## Exact Changes

### Guard flag — `pos_order_screen.dart`

`_isPaying` was already declared as a `bool` field and already guarded the entry of `_payTable()`:

```dart
if (_isPaying) return;          // existing guard
setState(() => _isPaying = true); // existing: marks payment started
try {
  // ... receipt print, sale insert, success modal, table clear, navigate
} catch (e) {
  // ... snackbar
} finally {
  if (mounted) setState(() => _isPaying = false);  // always resets
}
```

The `try/finally` ensures the flag resets even on exceptions — a failed payment never permanently locks the table.

**What was added:**

1. When the guard fires (a second call while `_isPaying` is already true), the blocked attempt is now audited before returning:
   ```dart
   if (_isPaying) {
     AuditLogService.instance.logDuplicatePaymentBlocked(tableId: widget.tableNumber);
     return;
   }
   ```

2. `isPaying: _isPaying` is now passed to `OrderPanel`, which threads it to `PayButton`.

### `OrderPanel` threading

`isPaying` is added as an optional named parameter (default `false`) and forwarded to `PayButton`:

```dart
PayButton(onPay: onPay, isPaying: isPaying)
```

### `PayButton` visual guard

`isPaying` is added as an optional prop (default `false`). When true, the entire normal button subtree is replaced with a muted spinner state:

- `CircularProgressIndicator` (18×18, stroke width 2, `mediumGreenText` color) replaces the payments icon.
- Label changes to `'PAGUAJ...'`.
- Background: `lightGreenBg` at 50% opacity; border: `borderVisible(0.12)`.
- `MouseRegion` and `GestureDetector` are not rendered — all pointer events are inert.

When `isPaying` is false, the button renders exactly as before (unchanged appearance, hover/press animations, `onPay` callback).

### Audit logging — `audit_log_service.dart`

```dart
// AuditAction constant:
static const String duplicatePaymentBlocked = 'duplicate_payment_blocked';

// Typed helper:
void logDuplicatePaymentBlocked({required int tableId}) => log(
  actionType: AuditAction.duplicatePaymentBlocked,
  entityType: 'sale',
  tableId:    tableId,
  details:    {'reason': 'payment_in_progress'},
);
```

Each blocked duplicate attempt is recorded with the table ID. This is fire-and-forget (matches the existing audit service pattern) and never throws.

---

## Payment Behavior After Fix

### Normal payment (single tap)

1. `_payTable()` is called.
2. `_isPaying` is false → guard passes.
3. `setState(() => _isPaying = true)` — button immediately shows spinner + `'PAGUAJ...'` text.
4. Receipt prints (non-fatal), sale is created in an atomic DB transaction, success modal is shown for 1.8 seconds, table is cleared, screen navigates back to table selection.
5. `finally` block resets `_isPaying = false` (widget is already disposed at this point since navigation occurred; the `if (mounted)` check prevents the setState from firing on a dead widget).

### Duplicate tap while payment is in progress

1. A second tap fires `_payTable()`.
2. `_isPaying` is true → `logDuplicatePaymentBlocked()` fires, method returns immediately.
3. No sale is created, no receipt is printed, no table is cleared a second time.
4. The button is already showing the spinner state — no additional visual response to the tap.

### Payment failure

If any exception is thrown (DB error, unexpected state), the `catch` block shows an error snackbar (`'Pagesa dështoi: ...'`). The `finally` block then resets `_isPaying = false`, which causes a rebuild that restores the button to its normal interactive state. The waiter can retry the payment immediately.

---

## What Was Not Changed

- **PIN / auth logic** — untouched.
- **Database schema** — no new tables or columns.
- **Backend / Firebase / cloud** — nothing added.
- **UI redesign** — the spinner uses the same `AppColors` tokens (`mediumGreenText`, `lightGreenBg`, `borderVisible`) already present in the button. Layout, sizing, and container shape are unchanged.
- **`_sendOrder()` (PRINTO) flow** — untouched; it does not need this guard since it does not create a sale record.
- **Sync and backup logic** — untouched.
- **Receipt printing logic** — the `ReceiptPrinter` call site is unchanged; the guard prevents a second call from ever reaching it.

---

## Manual Test Checklist

- [ ] Open a table, add items, tap PAGUAJ once — payment completes normally, success modal appears, table clears, screen returns to table selection
- [ ] Confirm exactly one row exists in the `sales` table for that transaction
- [ ] Confirm receipt printed exactly once (check printer output or printer log)
- [ ] Double-tap PAGUAJ quickly — second tap is blocked; only one sale row is created; receipt prints once
- [ ] Confirm the blocked second tap appears as `duplicate_payment_blocked` in the audit log
- [ ] While PAGUAJ spinner is visible, confirm the button does not animate or respond to hover/click
- [ ] Simulate payment failure (e.g., disconnect DB file access during payment if testable) — confirm error snackbar appears and PAGUAJ button returns to normal interactive state
- [ ] Retry payment after failure — confirm it succeeds and creates exactly one sale
- [ ] Check shift report totals — confirm they match the actual number of sales (no phantom duplicates)
- [ ] Run `flutter analyze` — confirm exactly 78 issues (no new errors)

---

## Next Step

**Next task:** Make backup encryption mandatory.
