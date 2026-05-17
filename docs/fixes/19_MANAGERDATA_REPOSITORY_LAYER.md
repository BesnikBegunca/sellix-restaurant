# 19 — ManagerData Repository Layer

## Problem

`ManagerData` remained a **God Object**: it held UI-facing state, business rules,
audit calls, and direct `DatabaseService` access across sales, menu, shifts,
expenses, salaries, and more. That coupling makes sync integration, unit testing,
and feature ownership harder — every change risks touching a 700+ line singleton.

## Risk

| Scenario | Problem with God Object |
|---|---|
| Future sync | No clear boundary for “data access vs presentation state” |
| Testing | Cannot mock sales DB without replacing entire `ManagerData` |
| Parallel work | Menu and sales changes conflict in one file |
| Background upload | Outbox and entity writes scattered without feature modules |

## Files Changed

| File | Change type |
|---|---|
| `lib/repositories/sales_repository.dart` | New |
| `lib/repositories/product_repository.dart` | New |
| `lib/repositories/expense_repository.dart` | New |
| `lib/repositories/shift_repository.dart` | New |
| `lib/repositories/salary_repository.dart` | New |
| `lib/repositories/inventory_repository.dart` | New |
| `lib/repositories/sync_repository.dart` | New |
| `lib/manager/manager_data.dart` | Routes init, shift, expenses, salaries through repositories |
| `lib/manager/manager_data_sales.dart` | Routes sales writes through `SalesRepository` |
| `lib/manager/manager_data_menu.dart` | Routes menu writes through `ProductRepository` |
| `lib/services/background_sync_service.dart` | Uses `SyncRepository` for pending outbox reads |

## Repositories Added

| Repository | Responsibility |
|---|---|
| `SalesRepository` | Sales, sale lines, adjustments, history reads |
| `ProductRepository` | Categories and products CRUD |
| `ExpenseRepository` | Expenses list / insert / delete |
| `ShiftRepository` | Shift open/close archive, legacy `shift` row |
| `SalaryRepository` | Salaries, advances, worked days |
| `InventoryRepository` | Inventory items and stock movements (foundation) |
| `SyncRepository` | Outbox insert, pending fetch, mark synced/failed |

Each repository is a **thin wrapper** over `DatabaseService` — no UI, no
`BuildContext`, no Navigator.

## What Was Wired Now

**ManagerData (safe subset):**

- `_reloadSales`, `_reloadMenu`, `_ensureOpenShift` → sales / product / shift repos
- `openShift`, `closeShift` → `ShiftRepository`
- `computeShiftStatusReport` adjustments → `SalesRepository`
- `addExpense`, `removeExpenseAt` → `ExpenseRepository`
- `setSalary`, `addAdvance`, `deleteAdvance`, `toggleWorkedDay` → `SalaryRepository`
- Init load for expenses, salaries, advances, worked days → respective repos

**Part extensions:**

- `manager_data_sales.dart` → all sale DB writes via `SalesRepository`
- `manager_data_menu.dart` → all category/product DB writes via `ProductRepository`

**BackgroundSyncService:**

- Pending outbox queries via `SyncRepository` (behavior unchanged)

## What Was Intentionally Not Moved

| Area | Still uses `DatabaseService` directly | Why |
|---|---|---|
| `manager_data_tables.dart` | Tables, current orders, kitchen prints | Higher coupling to cashier flow; separate PR |
| Waiters CRUD | `insertWaiter`, PIN, delete | Not in repository scope this step |
| Company / ESC/POS / admin PIN | Settings rows | Different domain |
| Audit logging | `AuditLogService` | Stays in ManagerData orchestration |
| `consumeNextGlobalOrderNumber` | App meta | Low priority |
| Inventory UI | None yet | `InventoryRepository` ready but unused |
| Full ManagerData split | Class still exists | Incremental migration only |

## Migration Plan

Suggested order for future PRs (lowest risk first):

1. **TablesRepository** — current orders, kitchen prints, restaurant tables
2. **WaiterRepository** — waiters + PIN (or fold into `SalaryRepository`)
3. **CompanyRepository** — company row and settings
4. **ManagerData slim-down** — move cache rebuild helpers out; keep `ChangeNotifier` facade
5. **Wire `InventoryRepository`** when stock UI or sale-deduction lands
6. **Sync engine** — `BackgroundSyncService` uses `SyncRepository` + `ApiClient` only

## What Was Not Changed

- **UI** — no import or widget changes.
- **Backend / cloud** — no API calls.
- **Sync processing** — still dry-run only.
- **Database schema** — unchanged.
- **ManagerData public API** — same methods and getters for screens.
- **App behavior** — repositories delegate 1:1 to existing `DatabaseService` methods.

## Manual Test Checklist

- [ ] App launches
- [ ] Sales / payment flow still records sales and lines
- [ ] Products and categories add/edit/delete/move still work
- [ ] Expenses add/remove still work
- [ ] Shift open/close still works
- [ ] Salaries, advances, worked days still work
- [ ] `InventoryRepository` / `SyncRepository` compile (no UI required)
- [ ] Outbox still populated on entity changes
- [ ] `ManagerData.instance` API unchanged for existing screens
- [ ] Run `flutter analyze`

## Next Step

Next phase: Start NestJS + PostgreSQL backend planning.
