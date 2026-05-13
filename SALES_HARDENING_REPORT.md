# Sales History Hardening Report

**Date:** 2026-05-12  
**DB version:** 8 → 9  
**Branch:** backup_database

---

## Summary of Changes

Four structural weaknesses in the original Sales History system have been resolved:

| Problem | Before | After |
|---------|--------|-------|
| Sales deleted on shift close | `clearSales()` erased all DB rows | `closeShift()` never deletes; archives to `shifts` table |
| No permanent shift archive | Single-row `shift` singleton | Multi-row `shifts` table, one row per shift period |
| No refund/void tracking | No mechanism | `sale_adjustments` table + UI dialog + PDF |
| Reports not audit-safe | Gross revenue only, totals lost on close | Gross + net revenue, adjustments listed, shifts archived |

---

## Database Changes

### New table: `shifts`

```sql
CREATE TABLE IF NOT EXISTS shifts (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  openedAt       TEXT    NOT NULL,
  closedAt       TEXT,
  openedBy       TEXT,
  closedBy       TEXT,
  openingCash    REAL    NOT NULL DEFAULT 0,
  closingCash    REAL,
  totalSales     REAL    NOT NULL DEFAULT 0,
  totalExpenses  REAL    NOT NULL DEFAULT 0,
  netProfit      REAL    NOT NULL DEFAULT 0,
  status         TEXT    NOT NULL DEFAULT 'open'
)
```

One row per shift. Never deleted. `status` is `'open'` or `'closed'`.

### New table: `sale_adjustments`

```sql
CREATE TABLE IF NOT EXISTS sale_adjustments (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  saleId         INTEGER NOT NULL,
  saleLineId     INTEGER,
  adjustmentType TEXT    NOT NULL,   -- 'refund' | 'void' | 'discount'
  productName    TEXT,
  quantity       INTEGER,
  amount         REAL    NOT NULL,
  reason         TEXT,
  createdBy      TEXT,
  createdAt      TEXT    NOT NULL,
  FOREIGN KEY (saleId) REFERENCES sales(id)
)
```

### Column additions (safe ALTER TABLE, try-catch)

- `sales.shiftId INTEGER` — links each sale to its originating shift
- `expenses.shiftId INTEGER` — links each expense to its originating shift

### Migration strategy

- Version bumped 8 → 9
- `_onUpgrade()` calls `_ensureTables()` (idempotent `CREATE IF NOT EXISTS`) then applies `ALTER TABLE ... ADD COLUMN` in try-catch blocks
- Old databases (v8) gain the new columns with `NULL` shiftId values
- Old sales without shiftId display correctly in history (NULL-safe everywhere)
- No data deleted during migration

---

## Code Changes

### `lib/services/database_service.dart`

New methods:
- `insertShiftRecord(openedAt, openedBy?, openingCash)` → `Future<int>`
- `closeShiftRecord({shiftId, closedAt, closedBy?, closingCash?, totalSales, totalExpenses, netProfit})` → `Future<void>`
- `fetchOpenShift()` → `Future<Map?>` — queries `status='open'` newest-first
- `fetchAllShifts()` → `Future<List<Map>>`
- `insertSaleAdjustment({saleId, saleLineId?, adjustmentType, productName?, quantity?, amount, reason?, createdBy?})` → `Future<int>`
- `fetchAdjustmentsForSales(List<int>)` → `Future<List<Map>>` — single `WHERE IN` query

Updated signatures:
- `insertSaleWithLines(…, shiftId?)` — writes `shiftId` into `sales` row
- `insertExpense(…, shiftId?)` — writes `shiftId` into `expenses` row

### `lib/manager/manager_data.dart`

New model classes:
- `ShiftRecord` — mirrors `shifts` table row, `isOpen` getter
- `SaleAdjustmentRow` — mirrors `sale_adjustments` row

Updated model classes:
- `SaleRow` — added `shiftId` field + `fromMap`
- `ExpenseRow` — added `shiftId` field + `fromMap`

New fields:
- `int? _currentShiftId` (private) + `int? get currentShiftId`

New methods:
- `_ensureOpenShift(db)` — loads existing open shift or auto-creates one
- `recordAdjustment({saleId, saleLineId?, adjustmentType, productName?, quantity?, amount, reason?, createdBy?})` → `Future<SaleAdjustmentRow>`

Updated methods:
- `_init()` — calls `_ensureOpenShift()` before `_reloadSales()`
- `_reloadSales()` — `_salesHistory` loads all-time; `waiterSales` filtered to current `_currentShiftId`
- `openShift()` — inserts a new `shifts` row, resets `waiterSales` (no DB delete)
- `closeShift()` — computes shift totals, calls `closeShiftRecord()`, opens next shift, resets tables; **never calls `clearSales()`**
- `recordSaleWithLines()` — passes `shiftId: _currentShiftId`
- `addExpense()` — passes `shiftId: _currentShiftId`
- `clearWaiterSales()` — resets in-memory `waiterSales = {}` only; **no DB delete**

### `lib/screens/sales_history_screen.dart`

- `SaleWithLines` — added `adjustments` list, `totalAdjusted` and `netTotal` getters
- `SalesAnalytics` — replaced `totalRevenue` with `grossRevenue` + `totalRefunded`; added `netRevenue` computed getter
- `_loadData()` — batch-fetches adjustments via `fetchAdjustmentsForSales()`; populates `adjBySaleId` map
- `_buildAnalyticsGrid()` — shows gross revenue always; shows refunded / net revenue cards only when refunds exist
- `_kpiCard()` — added `negative` flag for red styling
- `_showRefundDialog()` — `AlertDialog` with `SegmentedButton` for type (refund/void/discount), amount field, reason field; validates amount ≤ sale total
- `_SaleCard` — added `onRefund` callback; `_buildLineItems()` now shows `_AdjustmentRow` widgets and gross/net footer
- New `_AdjustmentRow` widget — shows type badge, reason, timestamp, negative amount

### `lib/services/sales_history_pdf.dart`

- `SaleWithLinesData` — added `adjustments` list
- `SalesAnalyticsData` — replaced `totalRevenue` with `grossRevenue` + `totalRefunded`; added `netRevenue` getter
- Summary table — shows refunded and net rows when refunds exist
- Sale detail section — shows red-bordered adjustment table per sale

---

## Invariants Preserved

| Constraint | How enforced |
|------------|-------------|
| Historical sales never deleted | `clearSales()` retained for reference but **no longer called** anywhere |
| `sale_lines` never mutated | Adjustments go to separate `sale_adjustments` table only |
| Payment flow UI unchanged | No changes to `pos_order_screen.dart` |
| Ordering flow unchanged | No changes to cashier/order screens |
| Dashboard layout unchanged | No structural changes to `manager_dashboard_screen.dart` |
| Fully offline + SQLite-only | All new tables are SQLite; no network calls |
| Backward compatible | Old sales with `shiftId = NULL` display correctly everywhere |

---

## Audit Trail

Every financial event is now permanently recorded:

1. **Sale created** → `sales` row (immutable) + `sale_lines` rows (immutable snapshots)
2. **Refund/void/discount** → `sale_adjustments` row (additive, never mutates sale)
3. **Shift closed** → `shifts` row with totals (permanent archive)

The PDF report includes all three layers for any date range.
