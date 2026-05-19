# POS System Desktop — Full Technical Audit

**Project:** `pos_system` (Flutter desktop POS)  
**Audit date:** 2026-05-19  
**Scope:** Entire desktop codebase, installer, docs cross-check vs implementation  
**Method:** Read-only inspection — no code changes  
**Supersedes:** `docs/99_POS_SYSTEM_REMAINING_WORK_AUDIT.md` for current-state truth (that file is **partially outdated**; see §16)

**Related repos (not in this workspace):** `pos_api` (NestJS backend), `pos_system_mobile` (SuperAdmin / ops mobile — referenced in docs only)

---

## Document purpose

This is the **single source of truth** for engineering, deployment, and product decisions on the desktop POS. It states what is implemented, what works, what is risky, and what blocks production — without optimism.

---

# 1. Executive Summary

### Readiness scores (honest)

| Dimension | Score (1–10) | Verdict |
|-----------|--------------|---------|
| **Overall engineering maturity** | **6 / 10** | Strong offline SQLite + sync foundation; gaps in tenant reads, sync parity, and ops |
| **MVP / pilot (one site, one branch, trained staff)** | **7 / 10** | Usable with Railway API, `app_config.json`, mandatory tenant wipe on business change |
| **Multi-tenant / multi-device production** | **4 / 10** | Not safe without strict operational discipline |
| **Unattended retail / chain rollout** | **3 / 10** | Missing signing, auto-update, monitoring, fiscal layer, scoped reads |

### Strongest areas (enterprise-grade or close)

- **Offline-first SQLite** with migrations (v22), transactions for sales, outbox queue
- **Activation + JWT** wired to pos_api (validate, activate, verify, refresh)
- **Secure activation token storage** (OS keychain / DPAPI) with legacy migration off `app_meta`
- **Production API config guard** — release blocks localhost/fallback (`ConfigErrorScreen`)
- **Sync push/pull** with cursor commit after transaction, malformed-response safety, per-event reject handling
- **Sync retry/backoff** + failed-outbox UI + support bundle export
- **Payment idempotency** at DB layer (`saleUuid`, outbox dedup)
- **Audit log immutability** (SQLite triggers) + hash chain on insert
- **Encrypted backup/restore** with integrity check
- **PIN hashing** (admin + waiter) + rate limiting
- **Device revoke UX** (`DeviceRevokedScreen`) + mid-session routing via `ActivationStateController`
- **Windows Inno Setup** + `app_config.json` bundling documented

### Weakest areas (prototype-level or incomplete)

- **Tenant isolation on reads** — writes stamped with `businessId`/`branchId`; almost all UI reads are **unscoped**
- **Push/pull entity asymmetry** — many pushed types never applied on pull
- **Local void/delete** without outbox `delete` events → cloud can retain deleted sales
- **Shift open** not enqueued to outbox (only close → `update`)
- **Inventory** schema + pull only — no sale-time stock decrement in POS flow
- **Automated test coverage** — ~9 test files, mostly unit/policy; almost no integration tests
- **macOS/Linux** as dev targets only; production story is **Windows-first**
- **No code signing, auto-update, crash telemetry**

### Biggest risks (production blockers if ignored)

1. **Cross-tenant data visible after re-activation without wipe** (release mitigated by mandatory wipe dialog — reads still unscoped)
2. **Multi-device drift** (orders/kitchen/waiters pushed but not pulled back)
3. **Server/cloud out of sync after local manager void** (`deleteSaleById` — no outbox delete)
4. **Misconfigured API URL on install** (mitigated in release by `ConfigErrorScreen`; operator must ship valid `app_config.json`)
5. **Operational dependence on SuperAdmin mobile** for device revoke on server (`kServerRevokeAvailableToDesktop = false`)

### What still feels prototype-level

- Manager dashboard as a large `ManagerData` god-object over unscoped SQL
- License vs device vs business suspension messaging (heuristic 403 parsing)
- Inventory module stub
- Minimal automated regression suite
- Documentation sprawl with some stale files (see §16)

---

# 2. System Architecture

## 2.1 High-level stack

| Layer | Technology | Role |
|-------|--------------|------|
| UI | Flutter 3.x (Material 3) | Desktop UI (Windows primary) |
| Local DB | SQLite via `sqflite` + `sqflite_common_ffi` on desktop | Offline source of truth |
| HTTP | `dio` | pos_api REST |
| Connectivity | `connectivity_plus` | Online/offline gates sync |
| Secure storage | `flutter_secure_storage` | Activation tokens |
| Printing | ESC/POS + `WindowsPrintersService` text fallback | Windows-oriented |
| Packaging | Inno Setup 6 | Windows installer |

**Version:** `pubspec.yaml` → `1.0.0+1` (also `lib/config/app_version_info.dart` — keep in sync manually)

## 2.2 Application startup flow (`lib/main.dart`)

```
WidgetsFlutterBinding
  → sqflite FFI init (Windows/Linux/macOS)
  → RuntimeConfigService.load()
  → ApiClient.configureBaseUrl + onUnauthorizedRevoke hook
  → wait ManagerData.instance.isLoading == false  (poll 50ms)
  → ConnectivityService.initialize()
  → BackgroundSyncService.initialize()  (listener only; does not auto-sync until start())
  → ActivationService.loadPersistedActivation()  → bool
  → ActivationStateController.setActivated(restored)
  → if NOT configBlocked AND activated:
        verifyActivation()  (GET /activation/verify)
        if still activated → BackgroundSyncService.start()
  → SyncStatusService.start()
  → runApp(PosSystemApp)
```

**Home routing** (`PosSystemApp._buildHome`):

1. `ConfigErrorScreen` — if `RuntimeConfigService.isBlockedInRelease`
2. `LoginScreen` — if `ActivationStateController.isActivated`
3. `DeviceRevokedScreen` — if `serverRevoked`
4. `ActivationScreen` — otherwise

**License:** `LicenseBlockedOverlay` wraps entire app (403 suspend path).

## 2.3 State management

| Mechanism | Usage |
|-----------|--------|
| `ManagerData` extends `ChangeNotifier` | Global cache: menu, tables, sales history, waiters, company settings |
| `ActivationStateController` | Activation / revoke routing |
| `SyncStatusService` | Sync health polling (10s) + flags from `BackgroundSyncService` |
| `LicenseGateService` | 403 suspend block |
| Local `setState` | Per-screen UI |

**No** Riverpod/Bloc — intentional simplicity; cost is tight coupling to singletons.

## 2.4 ManagerData architecture

- **Parts:** `manager_data.dart`, `manager_data_sales.dart`, `manager_data_menu.dart`, `manager_data_tables.dart`
- **Pattern:** UI → `ManagerData` → `*Repository` → `DatabaseService` (thin repos)
- **Truth:** SQLite is authoritative; memory lists refresh on load/mutations
- **Risk:** Large surface area; business rules scattered between ManagerData and DatabaseService (~2200+ lines in DB service alone)

## 2.5 Service layer (key services)

| Service | Responsibility |
|---------|----------------|
| `DatabaseService` | All SQL, outbox enqueue, migrations entry |
| `DatabaseSchema` | DDL, upgrades, tenant reset table lists, sync scope stamps |
| `ActivationService` | Activation lifecycle, token refresh, revoke |
| `SecureActivationTokenStore` | OS-backed tokens |
| `RuntimeConfigService` | API URL resolution |
| `ApiClient` | Dio + Bearer from secure store per request |
| `BackgroundSyncService` | Push/pull orchestration, backoff, 401 refresh |
| `PullSyncApplyService` | Apply pull entities in FK order inside txn |
| `LocalTenantDataService` | Conflict detection + wipe before activation |
| `SyncDiagnosticsExportService` / `SupportBundleService` | Support exports |
| `AuditLogService` | Append-only audit with hash chain |
| `BackupCryptoService` / restore via `RestoreService` | Encrypted backups |
| `ReceiptPrinter` / `SaleReceiptService` | Print + reprint |
| `ConnectivityService` | Online detection |

## 2.6 Repositories

`lib/repositories/`: `sales_repository`, `product_repository`, `shift_repository`, `expense_repository`, `inventory_repository`, `salary_repository`, `sync_repository` — **delegation only**, little domain logic.

## 2.7 Screens map

| Screen | Purpose |
|--------|---------|
| `activation_screen.dart` | First-run / re-activation |
| `config_error_screen.dart` | Release: invalid API config |
| `device_revoked_screen.dart` | Server 401 revoke |
| `license_suspended_screen.dart` | 403 recovery attempt |
| `login_screen.dart` | PIN entry (admin/waiter) |
| `table_selection_screen.dart` | Floor plan |
| `waiter_selection_screen.dart` | Waiter pick |
| `pos_order_screen.dart` | Core POS + payment |
| `manager_dashboard_screen.dart` | Back-office |
| `sales_history_screen.dart` | History + refund UI |
| `sync_diagnostics_screen.dart` | Ops / support |
| `audit_log_screen.dart` | Audit viewer |
| `admin_settings_screen.dart` | Company, printer, backup |

Feature widgets under `lib/features/` (dashboard panels, POS tiles, sales history cards).

---

# 3. Activation & Licensing

## 3.1 Intended flow (pos_api)

```
ActivationScreen
  → POST /activation/validate-key  (optional pre-check)
  → LocalTenantDataService.prepareForActivation  (tenant conflict / wipe)
  → POST /activation/desktop  { activationKey, branchCode, deviceUuid, deviceName, platform }
  → persist metadata in app_meta + tokens in SecureActivationTokenStore
  → ManagerData.reload() + BackgroundSyncService.start()
  → LoginScreen
```

**Desktop does not create businesses** — activation key binds to existing `businessId` + `branchId` from server.

## 3.2 Runtime API configuration

**Priority** (`lib/services/runtime_config_service.dart`):

1. `app_config.json` beside executable (+ macOS bundle parent paths)
2. `POS_API_BASE_URL` environment variable
3. `release/app_config.json` — **debug/profile only** (`!kReleaseMode`)
4. `http://127.0.0.1:3000` fallback — **debug operations only**

**Release safety:** `isBlockedInRelease = kReleaseMode && (isUsingFallback || isLocalhost)` → `ConfigErrorScreen`, no activation/sync.

**VS Code:** `.vscode/launch.json` → **「POS macOS - Railway API」** sets Railway URL for macOS debug.

**Scripts:** `scripts/run_macos_prod_api.sh`, `scripts/verify_api_config.sh`

| Status | Item |
|--------|------|
| ✅ Works | File/env/release-dev paths, release block, diagnostics labels |
| ⚠️ Partial | `reloadConfig()` exists but only used from `ConfigErrorScreen` retry |
| ❌ Missing | In-app “change API URL” without restart (by design) |

## 3.3 Token storage

| Store | Content |
|-------|---------|
| `SecureActivationTokenStore` | `pos_activation_access_token`, `pos_activation_refresh_token` |
| `app_meta` | `activation_completed`, `activation_business_id`, `activation_branch_id`, `activation_device_id`, license expiry, last business name/id |
| **Not in SQLite** | Bearer / refresh secrets (legacy keys migrated then cleared) |

**Migration:** `migrateTokensFromAppMetaIfNeeded()` on startup (also inside `loadPersistedActivation`).

**Debug hot restart:** debug cache file in Documents if keychain fails; in-memory fallback does **not** survive hot restart unless cache/keychain works.

**Load requirements** (`loadPersistedActivation`):

- `activation_completed == true`
- Non-empty `businessId`, `branchId`, `deviceId`
- Non-empty access **and** refresh in secure store
- Else → `revokeActivation()` + `ActivationScreen`

| Status | Item |
|--------|------|
| ✅ Works | Secure storage, migration, strict load, debug logs `[Activation]` |
| ⚠️ Partial | Refresh token required at activate — server must return it |
| ⚠️ Partial | `verifyActivation` returns false on **any** network error (offline continues — ambiguous vs invalid token until 401) |

## 3.4 Verify, refresh, revoke

| Endpoint | Behavior |
|----------|----------|
| `GET /activation/verify` | Startup when activated; 401 → `handleRevokedByServer` → `DeviceRevokedScreen` |
| `POST /activation/refresh` | On sync 401; updates secure tokens |
| `PATCH /devices/:id/revoke` | **Implemented but disabled** — `kServerRevokeAvailableToDesktop = false` (SuperAdmin-only on API) |

**Mid-session revoke:** `ApiClient.onUnauthorizedRevoke` stops sync, calls `handleRevokedByServer`; UI routes via `ActivationStateController` — **works** (contrary to outdated `docs/99`).

**Local reset:** `resetLocalActivation()` — clears tokens/metadata; **does not** call server revoke.

## 3.5 License / business suspension (403)

- `LicenseGateService` blocks UI on heuristic 403 messages
- `LicenseSuspendedScreen` — refresh + verify to recover
- **Not** the same as device revoke (401)

| Status | Item |
|--------|------|
| ⚠️ Partial | Heuristic message parsing; no structured error codes from API |
| ✅ Works | Overlay blocks POS; recovery path exists |

## 3.6 Persistence & hot restart

| Scenario | Expected |
|----------|----------|
| Cold start, valid config + activation | `LoginScreen` |
| Hot restart after activation | `LoginScreen` (reload from secure store + app_meta) |
| Reset local activation | `ActivationScreen` |
| Release without `app_config.json` | `ConfigErrorScreen` |

**Docs:** `docs/21_DESKTOP_REVOKED_DEVICE_BEHAVIOR.md`, `docs/23_*`, `docs/25_*`, `docs/19_*`

---

# 4. Sync Architecture

## 4.1 Model

- **Outbox pattern:** local mutations → `outbox` rows (`pending` → `synced` / `failed`)
- **Push:** `POST /sync/push` batch (default 100 events)
- **Pull:** `GET /sync/pull?since=&limit=200` → single SQLite transaction apply → advance `sync_pull_cursor` only on success
- **Offline-first:** no network required for sales; sync when online + activated + config valid

## 4.2 Push — entity types enqueued (from `database_service.dart`)

| entityType | Typical operations |
|------------|-------------------|
| `current_orders` | create, update, delete |
| `current_order_lines` | create, update, delete |
| `kitchen_prints` | create |
| `kitchen_print_lines` | create |
| `categories` | create, update, delete |
| `products` | create, update, delete |
| `waiters` | create, update, delete |
| `sales` | create |
| `sale_lines` | create |
| `sale_adjustments` | create |
| `expenses` | create, update, delete |
| `waiter_salaries` | create, update, delete |
| `advances` | create, update, delete |
| `waiter_worked_days` | create, delete |
| `shifts` | **update only** (on close) — **open shift NOT enqueued** |
| `inventory_items` | create, update, delete |
| `stock_movements` | create, update, delete |

**Not in outbox:** `audit_logs` (local forensic only).

**Payment idempotency:** `_queueOutboxByIdIfAbsent` prevents duplicate outbox rows for same entity UUID on retry.

## 4.3 Pull — entity types applied (`pull_sync_apply_service.dart`)

| Entity key in response | Applied |
|---------------------|---------|
| `categories` | ✅ |
| `products` | ✅ |
| `shifts` | ✅ |
| `sales` | ✅ |
| `sale_lines` | ✅ |
| `sale_adjustments` | ✅ |
| `expenses` | ✅ |
| `inventory_items` | ✅ |
| `stock_movements` | ✅ |

**NOT pulled:** `waiters`, `current_orders`, `current_order_lines`, `kitchen_prints`, `kitchen_print_lines`, `waiter_salaries`, `advances`, `waiter_worked_days`, `tables`

## 4.4 Multi-device limitations (explicit)

| Scenario | Result |
|----------|--------|
| Device A creates sale, pushes | Server has sale |
| Device B pulls | Gets sales/categories/products — **not** open kitchen orders from A |
| Device A updates waiter | Pushed; B never receives waiter rows via pull |
| Device B voids sale locally | Local delete only — **server may still have sale** |

## 4.5 Retry, backoff, connectivity

**`SyncBackoffPolicy`:** exponential 2s base, cap 5 min, jitter 50–100%, max 8 failure records; `Timer` schedules retry (not immediate storm on reconnect).

**Connectivity:** `BackgroundSyncService` listens; `_requestSyncWhenReady` respects backoff.

| Status | Item |
|--------|------|
| ✅ Works | Backoff, failed events list (full), retry single/all, export JSON |
| ✅ Works | Malformed push response → entire batch fails (no partial corrupt mark) |
| ⚠️ Partial | Shared backoff for push **and** pull |
| ❌ Missing | Server-side idempotency contract documented in desktop only via behavior |

## 4.6 Sync diagnostics & support bundle

**`sync_diagnostics_screen.dart`:** API URL, activation meta, token presence (not values), outbox counts, backoff countdown, failed events (full list), tenant warning, export failed JSON, **export support bundle**, reset local activation.

**`SupportBundleService`:** app info, API config, activation flags, sync meta, failed + recent outbox, audit sample, DB integrity, printer flags — **redacted** secrets.

| Status | Item |
|--------|------|
| ✅ Works | Per `docs/22_*`, `docs/26_*` |
| ⚠️ Outdated doc | `docs/99` claims only 5 failed rows — **false** now |

## 4.7 Branch isolation

- Outbox rows include `businessId`, `branchId`, `deviceId` from `syncScopeStamp()`
- Pull uses JWT — **no explicit `branchId` query param** on desktop; relies on pos_api enforcement
- Local DB can contain multiple businessIds if wipe skipped (debug) or legacy data

---

# 5. SQLite & Offline System

## 5.1 Schema

- **Version:** 22 (`database_service.dart` `openDatabase(version: 22)`)
- **Migrations:** `DatabaseSchema.upgrade` — additive columns, UUID backfill, sync timestamps/status, outbox v21
- **FK:** `PRAGMA foreign_keys = ON` on open

## 5.2 Core tables (operational)

`sales`, `sale_lines`, `sale_adjustments`, `current_orders`, `current_order_lines`, `kitchen_prints`, `kitchen_print_lines`, `products`, `categories`, `waiters`, `waiter_salaries`, `advances`, `waiter_worked_days`, `shifts`, `expenses`, `tables`, `company`, `inventory_items`, `stock_movements`, `outbox`, `app_meta`, `audit_logs`

## 5.3 Transactions & idempotency

| Operation | Transactional |
|-----------|---------------|
| `insertSaleWithLines` | ✅ single txn; idempotent on `saleUuid` |
| `pullSyncNow` apply | ✅ one txn; cursor after commit |
| `clearLocalBusinessData` | ✅ txn + reseed tables |
| `deleteSaleById` | ✅ txn — **no outbox** |

## 5.4 Audit logs (immutable)

- SQLite triggers: **no UPDATE/DELETE** on `audit_logs`
- Hash chain: `prevHash` + `rowHash` on insert (`AuditLogService`)
- **Excluded** from `tenantResetTables` — wipe does not delete audit history (fix for SQLite error 1811)
- **Not synced** via outbox in current code

## 5.5 Tenant reset (`tenantResetTables`)

Clears: kitchen, sales stack, orders, inventory, outbox, expenses, payroll tables, products/categories, shifts, tables (reseed 15 empty), etc.

**Preserves:** `company`, `audit_logs`, `shift` row reset to closed, activation-related `app_meta`, `audit_device_id`

Clears sync keys: `sync_pull_cursor`, `sync_last_*`, `global_order_number`

## 5.6 Backup / restore

- Encrypted backups (`BackupCryptoService`)
- `VACUUM INTO` for consistent snapshot
- Restore: integrity check + rollback on failure (`RestoreService`)

## 5.7 Printer / company persistence

- `company` table: printer name, ESC/POS flags, cash drawer, paper width, admin PIN hash, logo bytes, receipt footer
- Survives tenant wipe by design

## 5.8 Local-first behavior

| Works offline | Requires online |
|---------------|-----------------|
| Create orders, pay, print (local) | Activation, verify, sync |
| SQLite sales | Pull new catalog |
| ManagerData reads local | Token refresh |

---

# 6. Multi-Tenant Isolation

## 6.1 Write path (scoped)

- After activation: `DatabaseSchema.setActivatedTenant(businessId, branchId)`
- New rows get `businessId`, `branchId`, `deviceId` via `syncScopeStamp()`

## 6.2 Read path (largely unscoped)

- `fetchSales()`, `fetchProducts()`, `fetchWaiters()`, dashboard aggregates, etc. — **no `WHERE businessId = ?`**
- **Assumption:** one tenant per machine OR user always wiped on business change

## 6.3 Mandatory wipe (release)

- `LocalTenantDataService.isMandatoryWipeEnforced == kReleaseMode`
- Business change → dialog: **Anulo** / **Pastro dhe vazhdo** only (release)
- Debug: optional **Ruaj vetëm për testim**

## 6.4 Conflict detection

- `hasLocalDataForOtherBusiness` — checks operational tables **excluding `audit_logs`**
- `activation_last_business_id` vs new id
- Placeholder `local-business` detection

## 6.5 Risk matrix

| Risk | Severity | Mitigation today |
|------|----------|------------------|
| See prior tenant products/sales after re-activate without wipe | **Critical** (debug) / **High** (release wipe required) | Release mandatory wipe |
| `audit_logs` from old tenant visible | **Low** | Forensic; excluded from foreign check |
| Outbox with old businessId after partial failure | **Medium** | Wipe clears outbox |
| Multi-tenant on one DB file | **High** | Operational — one activation per machine |

## 6.6 Future refactor (documented intent)

- Filter all reads by activated tenant OR always wipe + single-tenant DB per business
- Scope `tables` layout per branch

**Doc:** `docs/20_DESKTOP_TENANT_DATA_ISOLATION.md` (updated for audit_logs preservation)

---

# 7. Payments & Printing

## 7.1 Payment flow (`pos_order_screen._payTable`)

1. UI guard `_isPaying` + audit `logDuplicatePaymentBlocked`
2. Resolve `saleUuid` (`resolvePaymentSaleUuid` — pending meta per table/waiter)
3. **`recordSaleWithLines`** (DB txn, outbox enqueue) — **before print**
4. Print payment receipt + optional cash drawer
5. Success dialog → `clearTable` → navigate home

| Status | Item |
|--------|------|
| ✅ Works | DB-first, idempotent uuid, print failure snackbar |
| ✅ Works | Reprint from sales history (`SaleReceiptService`) |

## 7.2 Printing

- ESC/POS via `EscPosPrinterService` (Windows raw)
- Fallback text via `WindowsPrintersService`
- Settings in `company` + `PrinterSettingsStore`
- **Windows-centric** — macOS/Linux printing not production-targeted

## 7.3 Failures

| Case | Behavior |
|------|----------|
| Print fails | Sale kept; user warned; reprint available |
| DB fails | No print; order remains |
| Double tap | One sale (idempotency) |

**Doc:** `docs/24_DESKTOP_PAYMENT_IDEMPOTENCY.md`

---

# 8. Security Audit

| Area | Posture | Rating |
|------|---------|--------|
| Activation tokens in SQLite plaintext | **Fixed** — secure storage + migration | ✅ Was Critical |
| Localhost API in release | Blocked — `ConfigErrorScreen` | ✅ Was High |
| Unscoped tenant reads | Data leak on re-activation | **Critical** (mitigated by wipe policy) |
| SQLite file copy | Full local business data readable | **High** — encrypt disk / physical access |
| Admin/waiter PIN | Salted hashes in DB | **Low** (offline attack surface) |
| PIN brute force | In-memory rate limiter (5 tries / 60s) | **Medium** (resets on app restart) |
| Audit log tampering | Triggers prevent update/delete | **Low** |
| Bearer in memory | `ApiClient` caches last read token | **Low** |
| Backup encryption | Password-based | **Medium** (operator password strength) |
| Support bundle export | Redaction rules | **Low** if used correctly |
| Revoke on 401 | Tokens cleared; UI reset | **Low** |
| `deleteSale` without server sync | Integrity / fraud | **High** (operational) |
| No code signing | Trojan risk on install | **High** (Windows) |

**Offline trust model:** Device is trusted; physical access = game over for local DB.

---

# 9. UI/UX Production Readiness

| Area | Assessment |
|------|------------|
| Activation | Clear Albanian copy; API banner; blocked state in release |
| Revoke / suspend | Dedicated screens; overlay for license |
| Sync diagnostics | Power-user oriented — good for support |
| POS flow | Functional; table/waiter/order flow |
| Manager dashboard | Feature-rich; dense |
| Loading/errors | Snackbars; some swallowed errors (print) |
| Desktop responsiveness | Fixed layouts; `ConstrainedBox` patterns |
| Accessibility | **Weak** — little `Semantics` |
| Operator usability | Good for trained staff; weak discoverability for diagnostics |

---

# 10. Windows EXE Deployment

## 10.1 Build pipeline

1. `flutter build windows --release`
2. Prepare `release/app_config.json` from example (`scripts/verify_api_config.sh`)
3. Compile `windows/installer/pos_system.iss` (Inno Setup 6)
4. Output: `release/installer_output/POSSystemSetup_1.0.0.exe`

## 10.2 Installer contents

- Full Flutter `Release/` bundle → `{app}`
- `app_config.json` → `{app}` (required for production API)

## 10.3 Production startup

- Valid `app_config.json` → `source=file`, Railway URL, activation works
- Missing/invalid config in **release** → `ConfigErrorScreen` (no silent localhost)

## 10.4 Gaps

| Item | Status |
|------|--------|
| Code signing | ❌ Not implemented |
| Auto-update | ❌ Not implemented |
| macOS notarized build | ❌ |
| Linux desktop package | ❌ |

**Docs:** `docs/17_WINDOWS_PACKAGING_INSTALLER.md`, `docs/23_*` (note: §17 mentions localhost fallback without release block — **partially outdated**)

---

# 11. Mobile Integration (pos_system_mobile)

**Not present in this repository.** Assumptions from docs and API design:

| Function | Typical owner |
|----------|----------------|
| Create business, branches, licenses | SuperAdmin mobile |
| Generate activation keys | SuperAdmin mobile |
| Revoke device (`PATCH /devices/:id/revoke`) | SuperAdmin mobile |
| Suspend business/license | SuperAdmin mobile |
| Dashboard analytics | Mobile reads **server** data |

**Desktop role:** Consume activation key; push/pull sync; does not administer tenants.

**Real-time:** No WebSocket on desktop — mobile dashboards depend on **server** state after sync, not live local SQLite.

**Sync dependency:** Desktop must push for server to reflect sales; mobile won't see unpaid local-only state until sync.

---

# 12. pos_api Integration Matrix

| Endpoint / capability | Desktop | Notes |
|----------------------|---------|-------|
| `POST /activation/validate-key` | ✅ | |
| `POST /activation/desktop` | ✅ | `branchCode`, `deviceUuid` |
| `GET /activation/verify` | ✅ | Startup |
| `POST /activation/refresh` | ✅ | Sync 401 |
| `POST /sync/push` | ✅ | Outbox-driven |
| `GET /sync/pull` | ✅ | 9 entity groups |
| `PATCH /devices/:id/revoke` | ⚠️ Code exists; **flag off** |
| Business/license admin | N/A | Mobile |
| JWT branch enforcement | ⚠️ Implicit | No extra query params on pull |

**Base URL:** No `/api` prefix in desktop paths — paths like `/activation/desktop` (`lib/config/api_config.dart`).

---

# 13. Production Readiness Checklist

### Must finish before multi-site production (P0)

- [ ] Operator runbook: `app_config.json` + `verify_api_config.sh` on every build
- [ ] Enforce **Pastro dhe vazhdo** training on any business/activation key change
- [ ] Document void/delete policy — local void does not sync
- [ ] SuperAdmin process for server device revoke
- [ ] Confirm pos_api pull/push schemas match outbox payloads (integration test environment)
- [ ] Restore drill tested on Windows 10/11

### Important (P1)

- [ ] Tenant-scoped reads OR per-tenant database files
- [ ] Outbox `delete` for voided sales
- [ ] Pull parity for waiters/orders/kitchen (or stop pushing them)
- [ ] Shift `create` on outbox when opening shift
- [ ] Code signing + installer signing
- [ ] Integration test suite (activation + sync + payment)
- [ ] Crash reporting (Sentry etc.)

### Can wait (P2)

- [ ] Fiscal / e-invoice integration
- [ ] Auto-update channel
- [ ] macOS production package
- [ ] Full accessibility pass
- [ ] Inventory UI + stock deduction on sale

---

# 14. Remaining Work Roadmap

## P0 — Production blockers

| ID | Item | Effort |
|----|------|--------|
| P0-1 | Tenant-scoped **reads** or hard single-tenant DB enforcement | Large |
| P0-2 | `deleteSaleById` → outbox delete events + server contract | Medium |
| P0-3 | Push/pull entity parity (define source of truth per entity) | Large (API + desktop) |
| P0-4 | Signed Windows installer | Medium |
| P0-5 | End-to-end test env: activate → sale → push → pull on second device | Medium |

## P1 — Important

| ID | Item | Effort |
|----|------|--------|
| P1-1 | Enable desktop server revoke when API allows OR document SuperAdmin-only | Small |
| P1-2 | Shift open → outbox create | Small |
| P1-3 | Structured 403 error codes (license vs business vs device) | Medium (API) |
| P1-4 | Integration tests in CI | Medium |
| P1-5 | Inventory production feature or hide from UI | Medium |

## P2 — Polish

| ID | Item | Effort |
|----|------|--------|
| P2-1 | Accessibility | Medium |
| P2-2 | Refactor ManagerData / smaller view models | Large |
| P2-3 | Auto-update | Large |
| P2-4 | Consolidate / archive stale docs | Small |

---

# 15. Known Bugs & Limitations (verified in code)

| Issue | Severity | Location |
|-------|----------|----------|
| Local void sale not synced | High | `deleteSaleById` — no outbox |
| Open shift not pushed until close | Medium | `insertShiftRecord` vs `closeShiftRecord` |
| Pull ignores pushed waiter/order/kitchen | High | `pull_sync_apply_service.dart` |
| Unscoped SQL reads | Critical (data) | Widespread `DatabaseService` |
| `verifyActivation` false on network blip | Low | Offline-by-design; may confuse support |
| Debug secure storage fallback lost on hot restart if keychain fails | Medium | `SecureActivationTokenStore` |
| `file_picker` plugin warnings on desktop | Low | Dependency noise |
| `docs/99` inaccurate on tokens, revoke UI, support bundle | Doc debt | See §16 |

---

# 16. Documentation cross-check (outdated vs current)

| Document | Status |
|----------|--------|
| **`docs/100_*` (this file)** | **Current SoT** |
| `docs/20`–`docs/26` (desktop hardening series) | **Mostly current** |
| `docs/99_POS_SYSTEM_REMAINING_WORK_AUDIT.md` | **OUTDATED** — plaintext tokens, no DeviceRevokedScreen, no support bundle, backoff "unused", mid-session revoke claims |
| `docs/17_WINDOWS_PACKAGING_INSTALLER.md` | **Partially outdated** — localhost fallback in release is now blocked |
| `docs/DESKTOP_BACKEND_INTEGRATION.md` | **Partially outdated** — tokens in app_meta; `PosSystemApp(activated:)` constructor |
| `docs/15_PRODUCTION_API_CONFIG.md` | **Partially outdated** — see `docs/23` instead |
| `docs/fixes/*` | Historical change logs — accurate as history, not as SoT |
| `PROJECT_AUDIT.md` / `TODO.md` | Likely stale — verify before trusting |

**Rule:** When docs conflict with code, **trust code** and this document.

---

# 17. Testing & quality

| Tests | Coverage |
|-------|----------|
| `test/widget_test.dart` | Login smoke (activated) |
| `test/activation_revoke_test.dart` | Revocation heuristics |
| `test/tenant_activation_gate_test.dart` | Gate + tenant reset lists |
| `test/sync_backoff_policy_test.dart` | Backoff math |
| `test/runtime_config_service_test.dart` | Localhost URL detection |
| `test/secure_activation_token_store_test.dart` | Legacy keys |
| `test/payment_idempotency_test.dart` | Meta key helper |
| `test/support_bundle_redaction_test.dart` | Redaction |
| `test/activation_persistence_test.dart` | Meta validation |

**Missing:** integration tests against real SQLite file, sync push/pull mocks, activation E2E, golden UI tests.

**Analyzer:** Project has baseline infos/warnings (e.g. `file_picker`); not gate for release today.

---

# 18. Final Verdict

### Honest production rating

**6 / 10** as a **hardened pilot desktop POS** connected to Railway pos_api.  
**Not** a turnkey multi-tenant SaaS terminal without operational constraints.

### Safe use today

- **One** physical site, **one** branch, **one** primary device (or devices accepting sync asymmetry)
- Trained staff, mandatory wipe on business change (release)
- Valid `app_config.json` on every Windows install
- SuperAdmin mobile available for revoke/suspend/keys

### Risky environments

- Shared PC activated under multiple businesses without wipe (debug)
- Multiple POS terminals expecting identical kitchen/order state
- High void/refund volume without server reconciliation
- Sites requiring fiscal printer certification

### Monitor in production

- `sync_last_error`, failed outbox count (diagnostics)
- Activation token presence flags
- API config source (support bundle)
- Push rejection reasons
- Backup success on schedule

### Multi-device stress

- Sales/catalog converge via pull
- Open tickets/kitchen queues **diverge**
- Conflicts handled server-side for pushed entities; not all entity types merge locally

### Offline-heavy usage

- **Strong** — core value proposition
- Sync catches up with backoff
- Long offline + revoke on server may show 401 only when back online

### Long-term architecture scalability

- **SQLite + outbox** scales for single-store volume
- **ManagerData monolith** will slow feature velocity
- **Tenant read scoping** is the main architectural debt for true multi-tenant product

---

## Appendix A — File index (implementation truth)

| Area | Primary files |
|------|----------------|
| Startup | `lib/main.dart` |
| Activation | `lib/services/activation_service.dart`, `lib/screens/activation_screen.dart` |
| Tokens | `lib/services/secure_activation_token_store.dart` |
| Config | `lib/services/runtime_config_service.dart`, `lib/screens/config_error_screen.dart` |
| Sync | `lib/services/background_sync_service.dart`, `lib/services/pull_sync_apply_service.dart` |
| DB | `lib/services/database_service.dart`, `lib/services/database_schema.dart` |
| Tenant | `lib/services/local_tenant_data_service.dart` |
| Payment | `lib/screens/pos_order_screen.dart`, `lib/manager/manager_data_sales.dart` |
| Installer | `windows/installer/pos_system.iss`, `release/app_config.example.json` |

---

*End of audit — update this file when material behavior changes.*
