# POS System — Remaining Work Audit

**Project:** `pos_system` (Flutter desktop POS)  
**Audit date:** 2026-05-19  
**Scope:** Read-only inspection of `lib/`, `pubspec.yaml`, `windows/`, `macos/`, `release/`, `docs/`, SQLite schema/migrations, and operational modules. **No application code was modified.**

> **Note:** Older reports (`PROJECT_AUDIT.md`, `TODO.md`, `docs/fixes/18_*`) describe a pre-backend, pre-hardening state. This document reflects the **current** codebase only.

---

## A. Executive Summary

| Metric | Value |
|--------|-------|
| **Readiness score** | **5 / 10** |
| **Production verdict** | **Not production-ready** for multi-tenant, multi-device, or regulated retail. **Acceptable for a controlled single-site Windows pilot** with trusted staff, correct `app_config.json`, and explicit acceptance of tenant/sync/security gaps below. |
| **Platform target today** | Windows desktop (printer + Inno Setup). macOS builds exist but lack packaging parity for API config. |

### Top 5 blockers (P0)

1. **Tenant data isolation is write-only** — inserts are stamped with `businessId`/`branchId`, but **all UI reads are unscoped**; re-activation without wipe can show another business’s products/sales. See [§E](#e-data-isolation-risk-section).
2. **No session-level re-routing after server revoke** — `revokeActivation()` during sync clears tokens but **`PosSystemApp` home is fixed at startup**; user can keep using local POS while believing they are “activated”. See `lib/main.dart`, `lib/services/background_sync_service.dart` (`_handleSyncUnauthorized`).
3. **Automated test coverage is effectively zero** — one widget smoke test; no sync/activation/tenant/migration tests. See `test/widget_test.dart`.
4. **Multi-device sync is asymmetric** — push outbox includes waiters, kitchen prints, current orders; **pull does not apply them**. Second device will not converge on staff, open tables, or kitchen state. See `lib/services/pull_sync_apply_service.dart`.
5. **Operational release gaps** — no code signing, no auto-update, tokens stored in **plaintext SQLite** `app_meta`, production observability (crash reporting, support bundle export) missing.

---

## B. Completed Features

| Feature | Status | Evidence / file paths |
|---------|--------|------------------------|
| Runtime API base URL resolution | Complete | `lib/services/runtime_config_service.dart` — `app_config.json` → `POS_API_BASE_URL` → `http://127.0.0.1:3000` |
| `app_config.json` beside executable | Complete | `release/app_config.example.json`, consumed in `RuntimeConfigService._loadFromFile()` |
| Activation key pre-validation | Complete | `POST /activation/validate-key` — `lib/services/activation_service.dart`, `lib/screens/activation_screen.dart` |
| Desktop activation request body | Complete | `activationKey`, `branchCode`, `deviceUuid`, `deviceName`, `platform` — `activation_service.dart` L126–132 |
| `branchCode` auto-fill from validate-key | Complete | `lib/screens/activation_screen.dart` (controller pre-fill from `ActivationValidateResponse.branchCode`) |
| Token persistence in `app_meta` | Complete | Keys in `activation_service.dart` L29–36; `DatabaseService.setAppMeta` |
| Token refresh on 401 | Complete | `refreshActivationToken()` — `activation_service.dart` L194–241; retry in `background_sync_service.dart` L149–158, L271–276 |
| License suspended (403) overlay | Complete | `lib/services/license_gate_service.dart`, `lib/widgets/license_blocked_overlay.dart`, `lib/screens/license_suspended_screen.dart` |
| Revoked token (401) local clear | Complete | `verifyActivation` + sync refresh 4xx → `revokeActivation()` — `activation_service.dart` L180–186, `background_sync_service.dart` L367–369 |
| Local activation reset (tokens only) | Complete | `resetLocalActivation()` / diagnostics UI — does **not** wipe business SQLite |
| Tenant conflict dialog on business change | Complete | `lib/widgets/tenant_data_conflict_dialog.dart`, `lib/services/local_tenant_data_service.dart`, `activation_screen.dart` |
| Local business data wipe (optional) | Complete | `DatabaseService.clearLocalBusinessData()` — `lib/services/database_service.dart` L1388–1412 |
| SQLite schema v22 + migrations | Complete | `database_service.dart` `version: 22`; inventory v22 in `database_schema.dart` |
| Outbox table + enqueue on writes | Complete | v21 `ensureOutboxTable`; `_queueOutboxRow` / `_queueOutboxById` in `database_service.dart` |
| Push sync `POST /sync/push` | Complete | `lib/services/background_sync_service.dart` `triggerSyncNow()` |
| Pull sync `GET /sync/pull` + cursor | Complete | `pullSyncNow()`; cursor only after txn commit |
| Server duplicate idempotency (push) | Complete | `accepted` + `duplicates` → `markOutboxEventSynced` — L178–180 |
| Pull conflict skip for `syncStatus=pending` | Complete | `lib/services/pull_sync_apply_service.dart` per-entity |
| Sync diagnostics UI | Complete | `lib/screens/sync_diagnostics_screen.dart`; opened from `lib/features/dashboard/widgets/manager_top_bar.dart` |
| Connectivity-triggered sync | Complete | `lib/services/connectivity_service.dart` + `_onConnectivityChanged` |
| Offline-first local DB (sqflite FFI) | Complete | `lib/main.dart` L22–26; `sqflite_common_ffi` in `pubspec.yaml` |
| Encrypted backup export | Complete | `lib/services/backup_crypto_service.dart`, `lib/services/backup_service.dart` |
| Restore + integrity check + rollback | Complete | `lib/services/restore_service.dart` — `PRAGMA integrity_check`, `.pre_restore_backup` |
| Admin PIN hashed (SHA-256 + salt) | Complete | `company.adminPinHash` / `adminPinSalt`; `ManagerData.verifyAdminPin` |
| Waiter PIN hashed + migration | Complete | `database_schema.dart` v15–16; `ManagerData` migrates legacy plaintext |
| PIN rate limiting (in-memory) | Complete | `lib/services/pin_rate_limiter.dart` |
| Admin session timeout (10 min) | Complete | `lib/services/admin_session_service.dart` |
| Double-tap payment guard (UI) | Complete | `_isPaying` + audit — `lib/screens/pos_order_screen.dart` L128–135 |
| Atomic sale + line snapshots | Complete | `manager_data_sales.dart` `recordSaleWithLines`; `SalesRepository.insertSaleWithLines` |
| Sales history + adjustments (refund/void/discount) | Complete | `lib/screens/sales_history_screen.dart`, `sh_refund_dialog.dart`, `sale_adjustments` table |
| ESC/POS printing + cash drawer (Windows) | Complete | `lib/services/escpos/`, `lib/services/windows_printers_service.dart`, `ReceiptPrinter` |
| Audit log + hash chain | Complete | `lib/services/audit_log_service.dart`, `DatabaseService.insertAuditLog` |
| Windows Inno Setup + `app_config.json` bundle | Complete | `windows/installer/pos_system.iss` L43–45 |
| Dashboard / manager modules (feature-rich) | Complete | `lib/features/dashboard/`, `lib/screens/manager_dashboard_screen.dart` |

---

## C. Partially Complete Features

| Feature | What exists | What is missing | Risk |
|---------|-------------|-----------------|------|
| Tenant data isolation | Columns + insert stamps + wipe-on-activation option | **All SELECTs unscoped**; `tables` / `company` not tenant-keyed | **Critical** — cross-business data visible on same disk |
| Activation lifecycle UX | Startup gate; diagnostics deactivate → `ActivationScreen` | **No navigator** to activation when revoked mid-session; `PosSystemApp.activated` immutable after launch | User continues offline with stale “activated” mental model |
| Sync retry / backoff | `SyncBackoffPolicy` records failures | **`currentDelay` never used** to delay retries; only connectivity/manual trigger | Thundering retries on flaky network; failed events linger |
| Pull sync coverage | 9 entity types applied | **No pull** for waiters, tables, `current_orders`, kitchen prints, advances, salaries, audit | Multi-device divergence |
| Push sync coverage | Many tables enqueued | Server must accept all entity types; rejected events need operator action | Failed outbox blocks trust in cloud copy |
| Payment flow | Print → record sale → clear table | Print **before** DB commit; print errors swallowed (`catch (_) {}`); no payment method / split | Receipt without sale or sale without receipt |
| Refunds / voids | `recordAdjustment` in sales history; `voidSale()` in code | `voidSale()` **not wired to UI**; “Refund” panel voids **kitchen prints** only | Financial vs operational confusion |
| Inventory | DB tables + pull apply + `getLowStockItems` | **No dashboard UI**; **no stock decrement on sale** | Schema-only feature |
| Waiter authentication | PIN mode on `LoginScreen` | `WaiterSelectionScreen` still allows name-only tap; NAMEMODE UI remnants (auto-migrated to PINMODE) | Latent bypass if NAMEMODE reintroduced |
| License enforcement | Server 403 → overlay; refresh unblocks | **No proactive expiry** check; client can ignore overlay by patching binary | Commercial control weak |
| macOS / Linux desktop | Flutter desktop targets in repo | No `app_config.json` install step; printer returns early on non-Windows | Wrong platform expectations |
| Repository layer | Sales, products, shifts, sync, inventory repos | `ManagerData` still god-object; tables/waiters/company direct DB | Maintenance / test difficulty |
| Documentation | Strong `docs/20_*`, integration guides | `PROJECT_AUDIT.md`, `TODO.md`, `PROJEKTI.md` **outdated** (still mention no backend, mock PINs) | Operators follow wrong runbooks |

---

## D. Missing Critical Features

### P0 — Critical (must fix before general production)

| Item | Detail |
|------|--------|
| Tenant-scoped reads everywhere | Filter by `activation_business_id` / `activation_branch_id` in `DatabaseService` + repositories + `ManagerData.reload()` |
| Runtime activation state machine | Listen for `revokeActivation` / `isActivated`; force navigation to `ActivationScreen` and stop POS |
| Production test suite | Activation, outbox push/pull, tenant wipe, migration v18→22, payment idempotency |
| Multi-device entity parity | Align pull (and server contract) with outbox: waiters, orders, tables, kitchen |
| Secure token storage | Plaintext `activation_access_token` / `refresh_token` in SQLite — use OS secure storage or encryption at rest |
| Server-side device deactivate | “Çaktivizo” is local-only — `sync_diagnostics_screen.dart` L135–176 |

### P1 — Important (before scaled rollout)

| Item | Detail |
|------|--------|
| Code signing + installer trust | Documented as future in `docs/17_WINDOWS_PACKAGING_INSTALLER.md`; not implemented |
| Auto-update channel | Not present |
| Payment ↔ inventory integration | Stock movements on sale (per `docs/fixes/15_*`) |
| Fiscal / compliance receipt layer | **Zero** implementation in `lib/` (only mentioned in `docs/DESKTOP_BACKEND_INTEGRATION.md`) |
| Crash reporting + support bundle | No Sentry/Crashlytics; no diagnostics ZIP export |
| macOS packaging for `app_config.json` | Manual copy required |
| Align print vs DB order | Record sale before print, or compensating retry |
| DB-level payment idempotency | UUID / idempotency key per table payment, not only `_isPaying` |
| Failed outbox operator playbook | UI shows 5 failed rows; no bulk export / server reconcile tool |
| Periodic token refresh | Only on 401 today |

### P2 — Polish

| Item | Detail |
|------|--------|
| Accessibility (`Semantics`) | **No** `Semantics` / semantics labels in `lib/` |
| Window min size / multi-monitor | No native window constraints in `windows/runner` |
| Rename `mock_data.dart` | Domain models only — misleading name |
| Update stale docs (`PROJECT_AUDIT.md`, `TODO.md`) | Avoid contradiction with this audit |
| Payment methods UI (cash/card/split) | Audit constants exist; UI absent |
| Inventory dashboard panel | Repository exists, no panel |
| `voidSale` manager UI | Method exists in `manager_data_sales.dart` L110–137 |
| NAMEMODE removal cleanup | Dead `WaiterSelectionScreen` path + login card |
| CI pipeline | Not observed in repo root |

---

## E. Data Isolation Risk Section

### What is tenant-scoped today

**Tables with `businessId` / `branchId` / `deviceId`** (migration v18+, listed in `database_schema.dart` `syncScopeTables` + inventory):

`sales`, `sale_lines`, `sale_adjustments`, `expenses`, `shifts`, `products`, `categories`, `waiters`, `waiter_salaries`, `advances`, `waiter_worked_days`, `audit_logs`, `current_orders`, `current_order_lines`, `kitchen_prints`, `kitchen_print_lines`, `inventory_items`, `stock_movements`, `outbox`

**New writes** use `DatabaseSchema.syncScopeStamp(deviceId)` after `ActivationService` calls `setActivatedTenant()`.

**Detection / wipe (v1):**

- `LocalTenantDataService.detectConflict()` — `lib/services/local_tenant_data_service.dart`
- `DatabaseService.hasLocalDataForOtherBusiness()` — scoped `SELECT 1 ... WHERE businessId != ?` **only for conflict checks**, not for UI
- `clearLocalBusinessData()` — wipes `tenantResetTables`, re-seeds 15 empty `tables`, preserves `company` + `shift` closed + `audit_device_id`

Documented in `docs/20_DESKTOP_TENANT_DATA_ISOLATION.md` (accurate as of this audit).

### What is still unscoped

| Asset | Issue |
|-------|--------|
| **All operational reads** | `fetchProducts()`, `fetchCategories()`, sales/history loaders, dashboard aggregates — `SELECT` without `WHERE businessId = ?` (e.g. `database_service.dart` `fetchProducts` → `db.query('products')`) |
| **`tables` layout** | No `businessId` column — occupancy is global per DB file |
| **`company` row** | Single row id=1 — printer, admin PIN, receipt footer **shared across tenants** on same machine (intentional preserve on wipe) |
| **Legacy `shift` singleton** | id=1 — not in `syncScopeTables`; parallel to multi-row `shifts` |
| **`app_meta`** | Activation tokens + sync cursors — not tenant-partitioned |

### What could leak between businesses

1. User activates Business B and chooses **“Ruaj të dhënat lokale”** → products, sales, expenses, waiters from Business A **still appear** in menu, reports, payroll.
2. **Dashboard KPIs / profits / sales history** aggregate unscoped tables — mixed-tenant revenue possible in one session.
3. **Outbox** may still hold events stamped with old `businessId` until pushed or wiped — server must reject or accept (operational risk).
4. **`tables` occupancy** — Table 3 occupied for Business A visible after switch to Business B.
5. **`company` settings** — Printer name / admin PIN from previous operator apply to new tenant (may be desired for hardware, wrong for security).

### What the current reset flow protects

| Action | Protects |
|--------|----------|
| **“Pastro të dhënat lokale”** on activation | Deletes rows in `tenantResetTables`, resets sync cursor keys, re-seeds empty tables |
| **Business change in `_persistActivation`** | Clears `sync_pull_cursor` and sync timestamps — forces fresh pull |
| **`revokeActivation()`** | Clears tokens only — **does not** delete business data |
| **Diagnostics tenant warning** | `localDataMayBeFromPreviousTenant()` orange banner in sync dialog |

### Long-term fix required

**Option 2** from `docs/20_DESKTOP_TENANT_DATA_ISOLATION.md`:

1. Centralize tenant context: `activeBusinessId`, `activeBranchId` from `app_meta`.
2. Add `scopedQuery(table, …)` used by **every** read path (repositories → `ManagerData`).
3. Add `businessId` to `tables` **or** store layout server-side per branch.
4. On activation mismatch: **default to wipe** (opt-in keep data only for migration tools).
5. Integration tests: activate A → data → activate B without wipe → assert **zero** rows from A in UI queries.

---

## F. Sync Risk Section

### Offline behavior

- Local SQLite is source of truth for operations; app runs without network after activation.
- `verifyActivation()` returns `false` on network error but **does not revoke** — correct offline grace (`activation_service.dart` L188–190).
- Push/pull skipped when `ConnectivityService` reports offline (`background_sync_service.dart` L97–99, L232–234).

### Outbox behavior

- Pending events in `outbox` with `payloadJson`; batch size 100.
- Malformed push response → **entire batch failed**, no partial mark (L161–174) — safe but can stall queue.
- `duplicates` from server treated as synced — idempotency depends on **server** + stable UUIDs (`docs/fixes/09_*`).
- **Enqueued entity types** (sample): `sales`, `sale_lines`, `categories`, `products`, `waiters`, `shifts`, `expenses`, `current_orders`, `kitchen_print_lines`, `waiter_worked_days`, inventory — see `_queueOutbox*` in `database_service.dart`.

### Retries

- Manual: Sync diagnostics **“Riprovo”** → `retryFailedOutboxEvents()` + `triggerSyncNow()` + `pullSyncNow()`.
- Automatic: on connectivity restore — immediate push+pull, **no** `SyncBackoffPolicy.currentDelay` sleep (`SyncBackoffPolicy` L509–513 unused for scheduling).
- Failed events: `markOutboxEventFailed`; operator must retry or clear errors.

### Conflicts

- **Pull vs local pending:** if local row `syncStatus == 'pending'`, pull **skips** update — protects in-flight edits, can **stall** convergence if pending never clears.
- **Pull vs synced local:** server payload **overwrites** without `updatedAt` comparison (except pending skip) — last writer is server for non-pending rows.
- **No UI conflict viewer** — only aggregate skip count via `SyncStatusService.markConflictSkips`.

### Server pull

Applied entities (`pull_sync_apply_service.dart` L38–46):

`categories`, `products`, `shifts`, `sales`, `sale_lines`, `sale_adjustments`, `expenses`, `inventory_items`, `stock_movements`

**Not pulled (but may be pushed):** `waiters`, `current_orders`, `current_order_lines`, `kitchen_prints`, `kitchen_print_lines`, `tables`, `advances`, `waiter_salaries`, `waiter_worked_days`, `audit_logs`

### Multi-device assumptions (honest)

| Assumption | Reality |
|------------|---------|
| Catalog syncs from cloud | **Yes** for categories/products via pull |
| Sales sync bidirectionally | Push local sales; pull other devices’ sales **if** server includes them in pull feed |
| Open table state syncs | **No** — `current_orders` not in pull apply |
| Staff roster syncs | **No** — waiters pushed but not pulled |
| Kitchen ticket state syncs | **No** |

Treat current sync as **“catalog + historical sales/expenses/inventory from server”**, not full operational replication.

### Failure scenarios

| Scenario | Outcome |
|----------|---------|
| Push fails mid-batch | No events marked synced; cursor unchanged on pull |
| Refresh token missing | `refreshActivationToken` throws — re-activation required (`ActivationResponse.refreshToken` optional L19) |
| 401 refresh 4xx | `revokeActivation()` + sync stopped — user **not** navigated to activation screen automatically |
| 403 license | Overlay blocks UI; tokens remain |
| Restore bad backup | `RestoreService` rolls back via `.pre_restore_backup` |
| Duplicate payment tap | Blocked in UI only — second sale possible if flag bypassed or second terminal |

---

## G. Security Risk Section

**Strict assessment — do not treat as production-hardened.**

| Area | Finding | Severity |
|------|---------|----------|
| **Activation tokens in SQLite** | `activation_access_token`, `activation_refresh_token` in `app_meta` plaintext | **High** — file copy exfiltrates API access |
| **Local license bypass** | `LicenseGateService` is in-memory overlay; SQLite/tampering can ignore | **High** for unpaid use; **Medium** if server enforces on sync |
| **Tenant data bleed** | Unscoped reads | **High** on shared/reassigned machines |
| **Admin PIN** | Hashed in DB — good | Low (if strong PIN chosen) |
| **Waiter PIN** | Hashed — good in PINMODE | Low |
| **WaiterSelectionScreen** | Name-only login without PIN | **Medium** (route only from deprecated NAMEMODE card; screen still exists) |
| **First-run admin setup** | Unknown PIN on login can prompt to set as admin PIN | **Medium** on fresh install |
| **Hardcoded dev credentials** | **Not found** in `lib/` (fixes 01–02 applied) | — |
| **PIN 9999 / 1234** | **Not in `lib/`** | Stale docs only |
| **SQLite tampering** | Sales, audit chain, license flags editable with file access | **High** — offline trust model |
| **Audit log** | Hash chain on insert — verification UI tolerant (`audit_log_service.dart` ~L215) | Medium — deters casual edit, not forensic grade |
| **Activation API logging** | Debug-only; tokens redacted — `activation_api_log.dart` | Low |
| **Backup encryption** | Mandatory min 8 chars for encrypted export — good | Low |
| **Rate limiter** | Resets on app restart | Low |
| **No crash reporting** | Field failures invisible | Medium |
| **Printer** | PowerShell / raw spooler — attack surface on Windows | Low–Medium |

---

## H. Required Next Prompts

Numbered implementation roadmap (recommended order):

1. **Add tenant-scoped reads** — `WHERE businessId = ? AND branchId = ?` (or branch-optional) on all `DatabaseService` fetch/query methods; reload `ManagerData` after activation.
2. **Activation session guard** — `Listenable` activation state; on `revokeActivation()` → `pushAndRemoveUntil(ActivationScreen)` + block POS routes.
3. **Server device deactivate API** — wire diagnostics “Çaktivizo” to backend + local revoke.
4. **Expand pull sync** (with server contract) — waiters, `current_orders`, `kitchen_prints`, `tables` layout; document ordering/FK rules.
5. **Sync conflict viewer** — surface skipped pending rows; allow force-overwrite or discard local pending.
6. **Use `SyncBackoffPolicy.currentDelay`** — schedule `triggerSyncNow` after failures; cap max delay.
7. **Payment hardening** — DB idempotency key per table checkout; record sale before print or queue print retry.
8. **Secure token storage** — Windows DPAPI / flutter_secure_storage for tokens.
9. **Wire `voidSale` + PIN-gated refunds** — manager PIN for `recordAdjustment` from sales history.
10. **Inventory UI + sale stock decrement** — complete fix 15.
11. **Fiscal layer** (if jurisdiction requires) — separate module; no current code.
12. **Automated tests** — see [§14 test coverage](#14-test-coverage).
13. **Windows code signing + auto-update** — per `docs/17_WINDOWS_PACKAGING_INSTALLER.md`.
14. **macOS `app_config.json` packaging** — mirror Inno bundling.
15. **Production observability** — crash reporter + “Export support bundle” (DB meta, sync status, redacted logs).
16. **Doc purge** — archive or update `PROJECT_AUDIT.md`, `TODO.md`, `PROJEKTI.md`.

---

## I. Final Checklist

Before `pos_system` can be called **production-ready**, verify:

### Activation & config
- [ ] Production `app_config.json` deployed beside every release binary (Windows installer includes it).
- [ ] `POS_API_BASE_URL` documented for dev/CI only; fallback localhost never used in production builds.
- [ ] Refresh token always issued and stored; rotation tested.
- [ ] Revoke mid-session forces re-activation UI.
- [ ] Server deactivate matches local “Çaktivizo”.

### Data & tenant safety
- [ ] All reads scoped to active `businessId` / `branchId`.
- [ ] Re-activation without wipe impossible by default (or strongly warned).
- [ ] `tables` and `company` policy documented per deployment model.

### Sync
- [ ] Push/pull entity parity with server documented and tested.
- [ ] Multi-device test: two PCs, same branch — catalog, sales, staff behavior defined.
- [ ] Failed outbox monitored; backoff applied.
- [ ] Pending-local vs server conflict resolution defined.

### Sales & payments
- [ ] Payment idempotency at DB layer.
- [ ] Print/sale ordering consistent; failure visible to cashier.
- [ ] Refund/void flows audited and PIN-protected.

### Security & compliance
- [ ] Tokens not in plaintext SQLite.
- [ ] Strong admin PIN policy; no first-run weak defaults in production.
- [ ] Fiscal/compliance requirements met or explicitly out of scope.
- [ ] Installer signed; binaries trusted.

### Operations
- [ ] Encrypted backup restore drill completed.
- [ ] Crash reporting live.
- [ ] Support bundle export tested.
- [ ] Release checklist in `docs/17_*` executed (build, config, installer smoke test).

### Quality
- [ ] `flutter test` + integration suite green.
- [ ] `flutter analyze` — zero errors; warnings triaged.
- [ ] Stale internal audits updated or superseded by this document.

---

## Detailed Area Notes (inspection index)

### 1. Activation lifecycle

| Check | Status |
|-------|--------|
| Runtime API config | ✅ `runtime_config_service.dart` |
| `app_config.json` | ✅ file + example |
| `POS_API_BASE_URL` | ✅ env var |
| Key validation | ✅ `validateActivationKey` |
| `/activation/desktop` body | ✅ includes `branchCode`, `deviceUuid` |
| Local reset | ✅ tokens only |
| Token persistence | ✅ `app_meta` |
| Token refresh | ✅ with 403 suspend handling |
| Revoked (401) | ✅ revoke local |
| Suspended (403) | ✅ `LicenseGateService` — not revoke |

### 2. Tenant data isolation

See [§E](#e-data-isolation-risk-section). Implementation files: `local_tenant_data_service.dart`, `tenant_data_conflict_dialog.dart`, `database_schema.dart` (`tenantResetTables`), `activation_screen.dart`.

### 3. Offline-first database

| Check | Status |
|-------|--------|
| SQLite v22 | ✅ |
| Migrations | ✅ extensive `database_schema.dart` `onUpgrade` |
| Local source of truth | ✅ |
| FK + transactions for sales | ✅ |
| Backup/restore | ✅ encrypted + integrity |
| Corruption handling | ✅ restore rollback |
| Data retention / purge | ❌ no automatic TTL for sales/audit |

### 4. Sync system

See [§F](#f-sync-risk-section). Key files: `background_sync_service.dart`, `pull_sync_apply_service.dart`, `sync_repository.dart`, `sync_status_service.dart`.

### 5. Sales / payment flow

| Check | Status |
|-------|--------|
| Order creation / kitchen print | ✅ `pos_order_screen.dart` `_sendOrder` |
| Payment | ✅ `_payTable` |
| Duplicate tap | ⚠️ UI only |
| Receipt | ✅ non-fatal print |
| Fiscal receipt | ❌ |
| Refunds/voids | ⚠️ adjustments yes; full void UI no |
| Sale snapshot | ✅ line-level snapshots |

### 6. Products / categories / inventory

| Check | Status |
|-------|--------|
| Local CRUD + sync | ✅ |
| Stock tables | ✅ schema |
| Stock on payment | ❌ |
| Low stock query | ✅ DB only |
| Pull products/categories | ✅ |

### 7. Waiters / staff / shifts / payroll

| Check | Status |
|-------|--------|
| Waiter PIN (PINMODE) | ✅ `login_screen.dart` |
| Shift lifecycle | ✅ `shift_repository.dart`, dashboard |
| Payroll/advances | ✅ dashboard panels |
| Permissions | ⚠️ admin session timeout only; coarse roles |
| Staff audit | ✅ audit log |

### 8. Tables / current orders

| Check | Status |
|-------|--------|
| 15 table layout | ✅ seeded |
| Current orders persisted | ✅ |
| Branch scoping | ❌ tables unscoped |
| Kitchen prints | ✅ local; sync pull missing |
| Multi-device tables | ❌ |

### 9. Printer / hardware

| Check | Status |
|-------|--------|
| ESC/POS | ✅ Windows |
| Reconnect / retry | ✅ `escpos_printer_service.dart` |
| Config in `company` | ✅ `printer_settings_store.dart` |
| Cash drawer | ✅ post-payment |
| Offline print queue | ⚠️ in-memory dedup by `jobId`; not persisted across restarts |
| Non-Windows | ❌ early return |

### 10. Security

See [§G](#g-security-risk-section).

### 11. UI / UX production readiness

| Check | Status |
|-------|--------|
| Dashboard | ✅ large feature set |
| Activation / license screens | ✅ |
| Sync diagnostics | ✅ |
| Loading/error states | ⚠️ uneven on older screens |
| Accessibility | ❌ |
| Desktop sizing | ⚠️ responsive login; no global min window |

### 12. Packaging / release

| Check | Status |
|-------|--------|
| Windows build + Inno | ✅ `windows/installer/pos_system.iss` |
| `app_config.json` bundle | ✅ |
| Code signing | ❌ |
| Auto-update | ❌ documented only |
| Versioning | ⚠️ `pubspec.yaml` `1.0.0+1`; installer `#define AppVersion "1.0.0"` manual sync |

### 13. Monitoring / debugging

| Check | Status |
|-------|--------|
| Debug logs | ✅ `kDebugMode` prints in sync/activation |
| Production logs | ❌ structured logging |
| Crash reporting | ❌ |
| Diagnostics export | ❌ |
| Support bundle | ❌ |

### 14. Test coverage

| Type | Status |
|------|--------|
| Unit tests | ❌ |
| Widget tests | ⚠️ 1 test (`test/widget_test.dart`) |
| Integration / sync / offline | ❌ |
| Migration tests | ❌ |
| Multi-device | ❌ manual only (`docs/20_*` checklist) |

---

## Key file index

| Area | Paths |
|------|-------|
| Entry / routing | `lib/main.dart` |
| Activation | `lib/services/activation_service.dart`, `lib/screens/activation_screen.dart` |
| Config | `lib/services/runtime_config_service.dart`, `lib/config/api_config.dart`, `release/app_config.example.json` |
| Sync | `lib/services/background_sync_service.dart`, `lib/services/pull_sync_apply_service.dart` |
| DB | `lib/services/database_service.dart`, `lib/services/database_schema.dart` |
| Tenant wipe | `lib/services/local_tenant_data_service.dart` |
| POS / pay | `lib/screens/pos_order_screen.dart`, `lib/manager/manager_data_sales.dart` |
| Backup | `lib/services/backup_service.dart`, `lib/services/restore_service.dart` |
| Printer | `lib/services/receipt_printer.dart`, `lib/services/escpos/`, `lib/services/windows_printers_service.dart` |
| Windows installer | `windows/installer/pos_system.iss` |
| Tenant docs | `docs/20_DESKTOP_TENANT_DATA_ISOLATION.md` |
| Packaging docs | `docs/17_WINDOWS_PACKAGING_INSTALLER.md` |

---

## Stale / misleading artifacts (do not treat as source of truth)

| File | Problem |
|------|---------|
| `PROJECT_AUDIT.md` | Pre-backend, hardcoded PINs, DB v13 — **superseded by this audit** |
| `TODO.md` | Claims printer not implemented — **false** (Windows ESC/POS exists) |
| `docs/fixes/18_BACKGROUND_SYNC_SERVICE_SKELETON.md` | Describes dry-run sync — **false** (real HTTP today) |
| `PROJEKTI.md` | May still reference `9999` / mock data |

---

*End of audit — generated from repository inspection only.*
