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

## Production policy: mandatory wipe on business change

Full per-query tenant filtering is deferred. Until reads are scoped, **release
builds must not allow “keep local data”** when activating a different business.

| Mode | Conflict dialog |
|------|-----------------|
| **Release** (`kReleaseMode`) | **Anulo** · **Pastro dhe vazhdo** only |
| **Debug** | Same + **Ruaj vetëm për testim** (strong warning) |

Why **Ruaj të dhënat lokale** is disabled in release:

- All UI reads are still unscoped `SELECT *` queries.
- Keeping old rows would show Business A products/sales under Business B activation.

Implementation:

- `LocalTenantDataService.isMandatoryWipeEnforced` → `kReleaseMode`
- `LocalTenantDataService.prepareForActivation()` — returns `TenantActivationGateResult`; activation continues only when `canProceedToActivation` is true.
- `activation_last_business_id` ≠ new `businessId` always triggers the gate (even if tables look empty).

### What gets cleared on wipe

See [Reset local business data](#reset-local-business-data) below.

### What is preserved

- `company` (printer, admin PIN hash, receipt footer)
- `shift` singleton (reset to closed)
- **`audit_logs`** — immutable audit trail (SQLite triggers forbid DELETE/UPDATE)
- `app_meta.audit_device_id`
- Theme / runtime config (not in SQLite business tables)
- Server data (never touched by desktop wipe)

Prior-tenant rows in `audit_logs` may remain after wipe; they are **not** used for
“data from another business” conflict checks or Sync Diagnostics foreign-data warnings.

### How to test keep-local (debug only)

1. Run a **debug** build (`flutter run`, not `flutter run --release`).
2. Activate Business A, add data, reset local activation only.
3. Activate Business B — dialog shows **Ruaj vetëm për testim**.
4. Expect old data to remain visible (known risk).

---

## Strategy (v1): conflict gate before activation

On activation when a conflict is detected, `prepareForActivation` runs **before**
`activateDesktop`:

| Button (release) | Behavior |
|------------------|----------|
| **Pastro dhe vazhdo** | Wipes local business tables, then activates |
| **Anulo** | Stops activation |

Conflict is detected when:

- `activation_last_business_id` ≠ new `businessId` (**always** gates in release), or
- Rows exist with `businessId` ≠ new tenant (including placeholder `local-business`), or
- Meaningful local operational data exists

---

## Reset local business data

Implemented in `LocalTenantDataService` + `DatabaseService.clearLocalBusinessData()`.

### Cleared tables

`kitchen_print_lines`, `kitchen_prints`, `sale_lines`, `sale_adjustments`,
`sales`, `current_order_lines`, `current_orders`, `stock_movements`,
`inventory_items`, `outbox`, `expenses`, `advances`, `waiter_worked_days`,
`waiter_salaries`, `waiters`, `products`, `categories`, `shifts`,
`tables` (re-seeded as 15 empty tables)

**Not cleared:** `audit_logs` (immutable — DELETE raises SQLite error 1811)

### Preserved

| Item | Reason |
|------|--------|
| `company` row | Printer name, ESC/POS, admin PIN hash, receipt footer |
| `shift` id=1 | Reset to `closed` — not deleted |
| `audit_logs` | Immutable forensic trail; triggers block DELETE/UPDATE |
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
- Orange warning if **operational** scoped rows exist for a business other than the active one (`audit_logs` excluded)

---

## Manual test checklist

### Release / production profile

- [ ] Activate desktop with Business A; create products/sales/waiters
- [ ] Sync Diagnostics shows Business A name/IDs
- [ ] Reset local activation only (tokens cleared; SQLite data remains)
- [ ] Activate with Business B key → dialog **Biznes tjetër u zbulua**
- [ ] Only **Anulo** and **Pastro dhe vazhdo** (no keep-local)
- [ ] Choose **Anulo** → activation does not complete
- [ ] Repeat; choose **Pastro dhe vazhdo**
- [ ] Old products/sales/waiters gone; empty menu until pull
- [ ] Pull sync loads Business B catalog
- [ ] Printer settings still configured (`company.printerName`)
- [ ] `audit_device_id` unchanged in `app_meta`
- [ ] `audit_logs` rows still present after wipe (immutable; not deleted)
- [ ] **Pastro dhe vazhdo** completes without SQLite error 1811

### Debug-only

- [ ] `flutter run` (debug) → third button **Ruaj vetëm për testim** visible with warning
- [ ] Choosing keep-local → old data may still appear (expected risk)

---

## Files

| File | Role |
|------|------|
| `lib/services/local_tenant_data_service.dart` | Conflict detection + wipe orchestration |
| `lib/services/database_service.dart` | `clearLocalBusinessData()`, scoped checks |
| `lib/services/database_schema.dart` | `tenantResetTables`, `seedEmptyTables` |
| `lib/widgets/tenant_data_conflict_dialog.dart` | Release vs debug dialog |
| `lib/models/tenant_activation_gate_result.dart` | Gate result / proceed flag |
| `lib/screens/activation_screen.dart` | `prepareForActivation` before `activateDesktop` |
| `lib/services/activation_service.dart` | Cursor reset on business change |

---

## Future (option 2)

- Filter all reads by `activation_business_id` / `activation_branch_id`
- Add `businessId` to `tables` or scope table layout per branch
- Server-driven table layout on pull
