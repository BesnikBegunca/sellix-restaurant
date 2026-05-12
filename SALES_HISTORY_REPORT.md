# POS System — Sales History & Analytics System Report

**Date:** 2026-05-12  
**Scope:** Additive production-grade sales history with per-product line snapshots,
analytics, filtering, and PDF export.  
No existing screens, navigation flow, state management, colors, layouts,
ordering logic, or payment UX were changed.

---

## 1. Problem Solved

The previous system stored only a sale header (`sales` table: waiterName,
tableId, total, timestamp). It captured **no line-level detail**.

Consequences of the old approach:
- No way to know which products were sold in any given transaction.
- Editing a product price retroactively made old sale totals unauditable.
- Deleting a product erased any trace that it was ever sold.
- Analytics (top products, category revenue) were impossible.

---

## 2. Database Changes

### 2.1 Version bump: 7 → 8

**File:** `lib/services/database_service.dart`

```dart
version: 8,
```

The existing `_onUpgrade` callback already calls `_ensureTables()` which uses
`CREATE TABLE IF NOT EXISTS`, so every existing user upgrades safely on next
launch with no data loss.

### 2.2 New table: `sale_lines`

```sql
CREATE TABLE IF NOT EXISTS sale_lines (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  saleId           INTEGER NOT NULL,
  productId        TEXT,               -- nullable: may have been deleted
  productName      TEXT    NOT NULL,   -- immutable snapshot at payment time
  productEmoji     TEXT    NOT NULL DEFAULT '☕',
  productImagePath TEXT,
  productPrice     REAL    NOT NULL,   -- immutable snapshot at payment time
  quantity         INTEGER NOT NULL,
  lineTotal        REAL    NOT NULL,
  categoryName     TEXT,               -- snapshot; null if uncategorised
  tableName        TEXT,               -- e.g. "Table 3"
  waiterName       TEXT,               -- denormalised for easy queries
  createdAt        TEXT    NOT NULL,   -- ISO-8601 timestamp
  FOREIGN KEY (saleId) REFERENCES sales(id) ON DELETE CASCADE
);
```

**ON DELETE CASCADE** — when a shift is closed and `clearSales()` runs, all
related `sale_lines` rows are automatically deleted with no orphan data.

### 2.3 Foreign key enforcement

```dart
onOpen: (db) async {
  await db.execute('PRAGMA foreign_keys = ON');
},
```

SQLite disables FK enforcement by default. This one-line change ensures the
CASCADE delete actually executes.

### 2.4 `clearSales()` updated

The existing method was a single `DELETE FROM sales`. Now it runs inside a
transaction that deletes `sale_lines` first, then `sales`, guaranteeing
consistency even if foreign key enforcement were off:

```dart
Future<void> clearSales() async {
  await db.transaction((txn) async {
    await txn.delete('sale_lines');
    await txn.delete('sales');
  });
}
```

---

## 3. New Database Methods

**File:** `lib/services/database_service.dart`

| Method | Description |
|--------|-------------|
| `insertSaleWithLines({waiterName, tableId, total, lines})` | Inserts sale header + all line rows in one atomic transaction. Returns the new sale `id`. If any insert fails the entire transaction is rolled back. |
| `fetchSaleLines(int saleId)` | Returns all `sale_lines` for a single sale, ordered by insertion. |
| `fetchSaleLinesForSales(List<int> saleIds)` | Batch-fetches lines for multiple sales in a single `WHERE saleId IN (…)` query. Avoids N+1 round-trips. Returns empty list if `saleIds` is empty. |
| `fetchFilteredSales({from, to, waiterName, tableId, saleId})` | Queries the `sales` table with any combination of date range, waiter, table, and exact-ID filters. |

---

## 4. New Model Class

**File:** `lib/manager/manager_data.dart`

```dart
class SaleLineRow {
  final int? dbId;
  final int saleId;
  final String? productId;   // nullable — survives product deletion
  final String productName;  // immutable snapshot
  final String productEmoji;
  final String? productImagePath;
  final double productPrice; // immutable snapshot
  final int quantity;
  final double lineTotal;
  final String? categoryName;
  final String? tableName;
  final String? waiterName;
  final DateTime createdAt;
}
```

---

## 5. New `ManagerData` Method

**File:** `lib/manager/manager_data.dart`

### `recordSaleWithLines()`

```dart
Future<void> recordSaleWithLines({
  required String waiterName,
  required double total,
  required int tableId,
  required String tableName,
  required List<CurrentOrderLine> lines,
}) async
```

**What it does:**

1. Builds a category name lookup map from the in-memory `_categories` list
   (same menu state visible to the waiter at payment time).
2. Maps each `CurrentOrderLine` to a `Map<String, dynamic>` containing the
   immutable snapshot fields.
3. Calls `DatabaseService.instance.insertSaleWithLines()` — the entire sale
   + all lines land in a single atomic transaction.
4. If the DB call succeeds: inserts the new `SaleRow` at the front of the
   in-memory `_salesHistory` cache and updates `waiterSales`.
5. Calls `notifyListeners()` to update any listening UI.

**Failure contract:** If `insertSaleWithLines` throws, the exception propagates
directly to the caller (`_payTable`). No in-memory state is mutated. The
payment UI shows an error snackbar and the table remains occupied.

---

## 6. Payment Flow Changes

**File:** `lib/screens/pos_order_screen.dart`

### 6.1 Duplicate-tap guard

```dart
bool _isPaying = false;
```

`_payTable()` now checks and sets `_isPaying` at entry. A second tap while
the first payment is in-flight returns immediately without doing anything.
Resets in a `finally` block so it always clears even on error.

### 6.2 Transactional sale recording

**Before:**
```dart
data.recordSale(widget.waiterName, tableTotal);  // unawaited
```

**After:**
```dart
await data.recordSaleWithLines(
  waiterName: widget.waiterName,
  total: tableTotal,
  tableId: widget.tableNumber,
  tableName: 'Table ${widget.tableNumber}',
  lines: combined,
);
```

The call is now **awaited**. If the transaction fails, an error snackbar is
shown and execution stops — `clearTable()` and navigation are never reached,
so the table stays occupied and the order is preserved for retry.

### 6.3 Error handling

```dart
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Pagesa dështoi: $e'), ...),
  );
}
```

No UI elements were changed. The existing success dialog, receipt printing,
and table-clearing flows are identical to before.

---

## 7. Historical Snapshot Architecture

### Why snapshots survive catalogue changes

`sale_lines` stores `productName`, `productPrice`, `productEmoji`,
`categoryName`, and `tableName` as plain text values copied at payment time.
These columns have **no foreign keys back to `products` or `categories`**.

| Event | Effect on historical lines |
|-------|--------------------------|
| Product price changed | None — `productPrice` is the price at sale time |
| Product renamed | None — `productName` is the name at sale time |
| Product deleted | None — `productId` becomes a dangling reference, but all snapshot fields remain intact |
| Category deleted | None — `categoryName` is a text copy, not a FK |
| Emoji changed | None — `productEmoji` is copied |
| Image changed | None — `productImagePath` is copied |

---

## 8. New Files

### 8.1 `lib/services/sales_history_pdf.dart`

Generates an A4 PDF report matching the existing `manager_summary_pdf.dart` style.

**Public API:**
```dart
Future<Uint8List> buildSalesHistoryPdfBytes(SalesHistoryReportData data)
```

**Report sections:**
1. Company name + date range + generation timestamp
2. Summary stats table (total sales, revenue, avg order, items, top waiter)
3. Top-selling products table (name, qty, revenue)
4. Revenue by category table
5. Full sale list — each sale has a grey header row followed by a 5-column
   line-items table (product, category, qty, unit price, line total)

**Data contract:** Receives a `SalesHistoryReportData` value object so the PDF
layer has zero dependency on Flutter widgets or live database connections.

### 8.2 `lib/screens/sales_history_screen.dart`

Self-contained `StatefulWidget` (`SalesHistoryPanel`) embedded in the manager
dashboard. The outer `SingleChildScrollView` in the dashboard handles scrolling.

**Key classes:**

| Class | Role |
|-------|------|
| `SaleWithLines` | Pairs a `SaleRow` with its `List<SaleLineRow>` |
| `SalesAnalytics` | Computed summary; has a static `compute(sales)` factory |
| `SalesHistoryPanel` | Root widget, manages filter state and data loading |
| `_SaleCard` | Single expandable sale row (header + animated line items) |
| `_LineRow` | One product line inside an expanded sale |

---

## 9. Manager Dashboard Changes

**File:** `lib/screens/manager_dashboard_screen.dart`

### 9.1 New section title (index 11)

```dart
const _kSectionTitles = [
  …,
  'Pagat & Avans',   // index 10 — unchanged
  'Historiku i Shitjeve',  // index 11 — NEW
];
```

### 9.2 New nav rail item

```dart
static const _items = [
  …,
  (icon: Icons.payments_outlined, sel: Icons.payments, label: 'Pagat'),
  (icon: Icons.history_outlined,  sel: Icons.history,  label: 'Historiku'), // NEW
];
```

### 9.3 New switch case

```dart
case 11:
  return const SalesHistoryPanel();
```

---

## 10. Sales History Screen Features

### 10.1 Date filters (chips)
- **Sot** — today only
- **Kjo javë** — Monday to now
- **Ky muaj** — 1st of month to now
- **Të gjitha** — no date restriction (default)
- **Personalizuar** — opens Flutter `showDateRangePicker`; stores `DateTimeRange`

### 10.2 Dropdown filters
- **Waiter** — populated from distinct waiters in the current sale history
- **Table** — populated from distinct table IDs in the current sale history

### 10.3 Search
- Numeric text field; filters by exact sale `id` (primary key)
- Non-numeric input matches nothing (no partial-text search to avoid confusion
  with numeric IDs)

### 10.4 Analytics KPI cards
Five cards displayed in a `Wrap` (responsive):
- Total sales count
- Total revenue (highlighted green)
- Average order value
- Total items sold
- Top waiter name + revenue

### 10.5 Top insights panels
- **Top products** — up to 5, ranked by line-level revenue; shows qty badge
- **Top categories** — up to 5, ranked by aggregated line revenue

Both are computed in Dart from the already-loaded `SaleWithLines` data with
no extra DB queries.

### 10.6 Sale list
- Each sale renders as an expandable card
- Header: sale ID badge, waiter name, table number, date, time, total
- "Hap të gjitha" / "Mbyll të gjitha" toggle button
- `AnimatedCrossFade` for smooth expand/collapse

### 10.7 Expanded line items
- Column headers: Product, Category, Qty, Unit Price, Line Total
- Each row shows the historical emoji alongside the snapshot name and price
- Footer row: line total sum (should always match `sale.total`)

### 10.8 PDF export
- FilledButton in the panel header triggers `Printing.layoutPdf`
- Generates via `buildSalesHistoryPdfBytes` with the current filtered data
- Loading spinner replaces the icon while generating
- Error shown as a snackbar if PDF generation fails

---

## 11. Data Loading Strategy

```
Filter in-memory _salesHistory (no DB round-trip)
    │
    ├─► extract matching sale IDs
    │
    └─► fetchSaleLinesForSales(saleIds)   ← single DB query
            │
            └─► group by saleId in Dart
                    │
                    └─► build SaleWithLines list
                            │
                            └─► SalesAnalytics.compute() ← pure Dart
```

**No N+1 queries.** All lines for N filtered sales are fetched in one
`WHERE saleId IN (…)` call. Analytics are computed from the in-memory list
with O(N × lines) passes.

---

## 12. Edge Cases Handled

| Scenario | Handling |
|----------|----------|
| Product deleted after sale | `productId` may not exist in `products`, but `productName` / `productPrice` snapshots are preserved |
| Category deleted | `categoryName` is a text copy; shows the original name, no FK breakage |
| `lines` is empty at payment (edge) | `insertSaleWithLines` inserts only the header; history card shows "no lines recorded" |
| DB transaction fails mid-insert | SQLite rolls back automatically; exception propagates to `_payTable`, error snackbar shown, table stays occupied |
| Duplicate payment tap | `_isPaying` guard returns immediately on second tap |
| Shift close (`clearSales`) | Transactional delete of `sale_lines` then `sales`; FK CASCADE also fires as a safety net |
| Restored backup from v7 (no `sale_lines`) | `_ensureTables` uses `CREATE TABLE IF NOT EXISTS`; new table is created on upgrade; old sales have no lines |
| Empty filter result | Empty-state card with icon and explanation |
| `saleIds` list empty | `fetchSaleLinesForSales` guards and returns `[]` immediately, avoiding malformed SQL |
| PDF export on empty data | Empty-state message rendered in PDF body |
| Custom date range cancelled | `_dateFilter` stays at `custom` but `_customRange` remains null; `_effectiveRange` returns null → shows all |

---

## 13. Files Changed

| File | Change type | Summary |
|------|-------------|---------|
| `lib/services/database_service.dart` | Modified | DB v8, `sale_lines` table, FK pragma, `clearSales` transaction, 4 new methods |
| `lib/manager/manager_data.dart` | Modified | `SaleLineRow` model, `recordSaleWithLines()` method |
| `lib/screens/pos_order_screen.dart` | Modified | `_isPaying` guard, `_payTable` awaits `recordSaleWithLines` |
| `lib/services/sales_history_pdf.dart` | **New** | A4 PDF report builder |
| `lib/screens/sales_history_screen.dart` | **New** | Full history panel with filters, analytics, expandable list |
| `lib/screens/manager_dashboard_screen.dart` | Modified | New section title (index 11), nav item, switch case, import |

---

## 14. Files NOT Changed

- `lib/main.dart`
- `lib/models/mock_data.dart`
- `lib/screens/login_screen.dart`
- `lib/screens/table_selection_screen.dart`
- `lib/screens/waiter_selection_screen.dart`
- `lib/screens/admin_settings_screen.dart`
- `lib/services/backup_service.dart`
- `lib/services/restore_service.dart`
- `lib/services/backup_crypto_service.dart`
- `lib/services/database_backup_manager.dart`
- `lib/services/expenses_pdf_export.dart`
- `lib/services/manager_summary_pdf.dart`
- `lib/services/receipt_printer.dart`
- `lib/services/receipt_text.dart`
- `lib/services/printer_settings_store.dart`
- `lib/services/windows_printers_service.dart`
- `lib/theme/`, `lib/widgets/`, `lib/utils/`
- `android/`, `windows/`, `macos/`, `ios/`
- `pubspec.yaml` (no new dependencies — `pdf` and `printing` already present)

---

## 15. How to Test

### 15.1 Sale line recording
1. Log in as waiter → open a table → add products → tap **PAGUAJ**.
2. Open Manager Dashboard → **Historiku i Shitjeve**.
3. The sale appears in the list. Expand it — all products, quantities,
   historical prices, and category names should be present.

### 15.2 Historical price integrity
1. Record a sale with Espresso at €2.50.
2. Go to Menu → edit Espresso → change price to €5.00.
3. Re-open the history card from step 1.  
   Expected: `productPrice` still shows €2.50 (snapshot).

### 15.3 Product deletion
1. Record a sale containing "Sprite".
2. Delete "Sprite" from the Menu section.
3. History card still shows "Sprite" at the original price.

### 15.4 Date filters
- **Sot:** only today's sales appear.
- **Kjo javë / Ky muaj:** verify boundary dates.
- **Personalizuar:** pick a range that includes known sales; verify counts.

### 15.5 Waiter filter
1. Record sales from two different waiters.
2. Select waiter A from the dropdown; only waiter A's sales appear.

### 15.6 Table filter
Select "Table 3" from the dropdown; only Table 3 sales appear.

### 15.7 Search by sale ID
Type the numeric ID of a known sale; only that sale appears.

### 15.8 Analytics accuracy
After filtering, verify:
- "Shitje gjithsej" matches the visible count.
- "Të ardhura" equals the sum of all visible sale totals.
- "Mesatare/porosi" = Të ardhura ÷ Shitje gjithsej.
- "Artikuj të shitur" equals the sum of all quantities across all line rows.

### 15.9 Transaction rollback simulation
In the SQLite database, temporarily add a UNIQUE constraint that would conflict
with a second insert. Attempt a payment — expect an error snackbar and the
table remaining occupied.

### 15.10 PDF export
Click "Eksporto PDF" → the system PDF preview/print dialog opens.  
Verify: date range label, company name, analytics table, product list,
and all sale line items appear correctly.

### 15.11 Shift close
Record several sales → close shift → reopen.  
Expected: History panel shows 0 sales (all cleared with the shift).

### 15.12 Backup restore from older DB (v7)
Restore a v7 backup → app reopens → DB upgrade runs → `sale_lines` table is
created → History panel shows 0 lines (old sales have no lines, which is
correct and expected).

### 15.13 Duplicate tap guard
During a payment (after the animated dialog appears), rapidly tap PAGUAJ
on the underlying screen. Only one sale should be recorded.

---

## 16. Architecture Decisions

**Why snapshots instead of JOINs to `products`?**  
Products can be deleted or renamed. A JOIN would return NULL or stale data.
Snapshots give a guaranteed accurate record regardless of future catalogue
changes.

**Why no separate `sale_lines` cache in `ManagerData`?**  
Lines are only needed in the history screen — not in the shift overview, profit
calculations, or any other panel. Caching them globally would waste memory.
Instead, they are loaded on demand per filtered query.

**Why compute analytics in Dart instead of SQL aggregates?**  
The in-memory filtered list is already available. Pure-Dart computation avoids
additional DB round-trips and keeps the analytics code readable and testable
without a database.

**Why use `fetchSaleLinesForSales` (batch) instead of per-sale queries?**  
N+1 queries against SQLite are fast locally but the pattern is fragile.
A single `WHERE saleId IN (…)` query scales to hundreds of sales without
performance degradation.
