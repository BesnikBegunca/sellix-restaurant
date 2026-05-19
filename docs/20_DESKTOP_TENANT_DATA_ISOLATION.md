# Desktop Tenant Data Isolation

How the Flutter desktop POS handles local SQLite data when linking to a
different business via activation.

---

## Concepts

| Concept | Meaning |
|---------|---------|
| **Business** | Created by SuperAdmin in `pos_api` / mobile — not by desktop activation |
| **Activation key** | Links this device to an existing `businessId` + `branchId` |
| **Local SQLite** | Offline source of truth until sync; can outlive activation resets |
| **Tenant reset** | Deletes local business tables only — never touches server data |

Activation **does not** create a business. It only stores tokens and tenant IDs
in `app_meta` and stamps new rows with the activated scope.

---

## Audit: tenant columns vs queries

### Tables **with** `businessId` / `branchId` (migration v18+)

All rows in `syncScopeTables` plus inventory:

`sales`, `sale_lines`, `sale_adjustments`, `expenses`, `shifts`, `products`,
`categories`, `waiters`, `waiter_salaries`, `advances`, `waiter_worked_days`,
`audit_logs`, `current_orders`, `current_order_lines`, `kitchen_prints`,
`kitchen_print_lines`, `inventory_items`, `stock_movements`, `outbox`

New inserts use `DatabaseSchema.syncScopeStamp()` with the activated tenant.

**Reads are not filtered** by tenant today — `DatabaseService` and repositories
use unscoped `SELECT *` queries. Old rows remain visible after re-activation
unless the user wipes local data.

### Tables **without** tenant columns

| Table | Risk |
|-------|------|
| `tables` | Layout/occupancy leaks between tenants |
| `company` | Printer/admin settings — **preserved** on purpose |
| `shift` | Legacy singleton — reset to closed on wipe |
| `app_meta` | Activation + sync keys |

### Screens reading unscoped data

All POS/manager UI goes through `ManagerData` → repositories → unscoped DB
queries: products, categories, waiters, sales, expenses, shifts, tables,
dashboard profits, staff payroll, sales history.

---

## Strategy (v1): safe reset prompt

Full per-query tenant filtering is deferred. On activation when the business
changes, the app asks:

> Ky terminal ka të dhëna lokale nga një biznes tjetër.  
> Dëshironi të filloni me të dhëna të pastra për biznesin e ri?

| Button | Behavior |
|--------|----------|
| **Ruaj të dhënat lokale** | Activates; old rows may still appear |
| **Pastro të dhënat lokale** | Wipes local business tables, then activates |
| **Anulo** | Stops activation |

Conflict is detected when:

- `activation_last_business_id` ≠ new `businessId`, or
- Rows exist with `businessId` ≠ new tenant (including placeholder `local-business`), or
- Meaningful local operational data exists

---

## Reset local business data

Implemented in `LocalTenantDataService` + `DatabaseService.clearLocalBusinessData()`.

### Cleared tables

`kitchen_print_lines`, `kitchen_prints`, `sale_lines`, `sale_adjustments`,
`sales`, `current_order_lines`, `current_orders`, `stock_movements`,
`inventory_items`, `outbox`, `expenses`, `advances`, `waiter_worked_days`,
`waiter_salaries`, `waiters`, `products`, `categories`, `shifts`, `audit_logs`,
`tables` (re-seeded as 15 empty tables)

### Preserved

| Item | Reason |
|------|--------|
| `company` row | Printer name, ESC/POS, admin PIN hash, receipt footer |
| `shift` id=1 | Reset to `closed` — not deleted |
| `app_meta.audit_device_id` | Stable device fingerprint |
| `app_meta` activation keys | Set by activation flow |
| Theme / runtime config | Not in SQLite business tables |

### Cleared `app_meta` keys

`sync_pull_cursor`, `sync_last_*`, `global_order_number`

### Kept for conflict detection

`activation_last_business_id`, `activation_last_business_name` (updated after each
successful activation; not cleared on activation-only reset)

---

## After activation

1. Persist `businessId`, `branchId`, tokens
2. If business changed → clear `sync_pull_cursor` and sync timestamps
3. `DatabaseSchema.setActivatedTenant(...)`
4. `ManagerData.reload()`
5. `BackgroundSyncService.start()` → push + **pull without cursor** (fresh server data)

---

## Diagnostics

Sync Diagnostics shows:

- Business name (from validate-key / activation)
- Business ID, Branch ID, Device ID
- Orange warning if scoped rows exist for a business other than the active one

---

## Manual test checklist

- [ ] Activate desktop with Business A; create products/sales/expenses
- [ ] Sync Diagnostics shows Business A name/IDs
- [ ] Reset local activation only (tokens cleared; SQLite data remains)
- [ ] Activate with Business B key → conflict dialog appears
- [ ] Choose **Pastro të dhënat lokale**
- [ ] Old products/sales/expenses gone; empty menu until pull
- [ ] Pull sync loads Business B catalog
- [ ] Printer settings still configured (`company.printerName`)
- [ ] `audit_device_id` unchanged in `app_meta`
- [ ] Choose **Ruaj të dhënat lokale** on another test → old data still visible (expected)

---

## Files

| File | Role |
|------|------|
| `lib/services/local_tenant_data_service.dart` | Conflict detection + wipe orchestration |
| `lib/services/database_service.dart` | `clearLocalBusinessData()`, scoped checks |
| `lib/services/database_schema.dart` | `tenantResetTables`, `seedEmptyTables` |
| `lib/widgets/tenant_data_conflict_dialog.dart` | Confirmation UI |
| `lib/screens/activation_screen.dart` | Prompt before `activateDesktop` |
| `lib/services/activation_service.dart` | Cursor reset on business change |

---

## Future (option 2)

- Filter all reads by `activation_business_id` / `activation_branch_id`
- Add `businessId` to `tables` or scope table layout per branch
- Server-driven table layout on pull
