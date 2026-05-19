# POS System Desktop — Remaining Work Audit

**Project:** `pos_system` (Flutter desktop POS)  
**Audit date:** 2026-05-19  
**Scope:** Read-only inspection of desktop codebase vs hardened **pos_api** capabilities.  
**Rule:** No code, UI, or refactor changes — documentation only.

> Supersedes outdated narratives in `PROJECT_AUDIT.md`, `TODO.md`, and `docs/fixes/18_BACKGROUND_SYNC_SERVICE_SKELETON.md` (sync is live HTTP today).

---

## pos_api ↔ Desktop integration matrix

| pos_api capability (production) | Desktop wired? | Evidence / gap |
|---------------------------------|----------------|----------------|
| Production Railway API URL | ✅ | `release/app_config.example.json` → `RuntimeConfigService` |
| `POST /activation/validate-key` | ✅ | `lib/config/api_config.dart` `kEndpointValidateKey`; `activation_service.dart` |
| `POST /activation/desktop` | ✅ | `kEndpointActivateDesktop`; body includes `branchCode`, `deviceUuid` |
| `GET /activation/verify` | ✅ | Startup + implicit via token use |
| `POST /activation/refresh` | ✅ | On 401 during sync; `license_suspended_screen.dart` retry |
| **`PATCH /devices/:id/revoke`** | ❌ **Not called** | No constant in `api_config.dart`; deactivation is **local-only** |
| Suspend / reactivate **business** | ⚠️ Partial | 403 → `LicenseGateService.block()`; recovery via refresh+verify on suspended screen |
| Suspend / reactivate **license** | ⚠️ Partial | Same 403 path; message heuristics in `license_gate_service.dart` |
| Suspend / revoke **device** (server) | ⚠️ Partial | Server revoke surfaces as **401** → local `revokeActivation()`; **no** dedicated “device revoked” UI |
| Activation key lifecycle | ✅ consume only | Desktop sends key; does not manage key CRUD |
| Business users / password reset / superadmin | N/A | Mobile/admin; not desktop scope |
| **`GET /sync/pull` branch validation** | ⚠️ Implicit | Pull sends `since` + `limit` only; **no `branchId` query param** — relies on JWT + server enforcement |
| `POST /sync/push` | ✅ | Outbox rows include `businessId`, `branchId`, `deviceId` per event |

**Desktop does not create businesses.** Activation links an existing `businessId` + `branchId` from the activation key (`docs/20_DESKTOP_TENANT_DATA_ISOLATION.md`, `activation_screen.dart` L93–99).

---

## A. Executive Summary

| Metric | Value |
|--------|-------|
| **Readiness score** | **5 / 10** |
| **Production verdict** | **Not production-ready** for multi-tenant, multi-device, or unattended retail. **Pilot OK** on one trusted Windows site with correct `app_config.json`, staff training, and acceptance of gaps below. |
| **pos_api alignment** | Core activation + push/pull **connected**; **device revoke API**, **mid-session force-logout UX**, and **tenant read isolation** are **not** aligned with hardened backend controls. |

### Top 5 blockers

1. **`PATCH /devices/:id/revoke` not integrated** — “Çaktivizo” clears local tokens only; server may still list device active; admin revoke does not force `ActivationScreen` during session.
2. **Tenant isolation: write-scoped, read-unscoped** — re-activation without wipe can show previous business data (`docs/20_DESKTOP_TENANT_DATA_ISOLATION.md`).
3. **Revoked device mid-session** — tokens cleared on 401 refresh failure, sync stops, but **`PosSystemApp` home stays `LoginScreen`** until restart (`lib/main.dart` L221).
4. **Multi-device sync gap** — push includes waiters/orders/kitchen; pull applies 9 entity types only (`pull_sync_apply_service.dart` L38–46).
5. **Release / ops** — no code signing, auto-update, crash reporting, or support bundle export; tokens in plaintext `app_meta`.

---

## B. Completed Features

| Feature | Status | Evidence / file paths |
|---------|--------|------------------------|
| Runtime API URL (file → env → fallback) | Complete | `lib/services/runtime_config_service.dart` |
| `app_config.json` beside executable | Complete | `release/app_config.example.json`; Inno `windows/installer/pos_system.iss` L43–45 |
| `POS_API_BASE_URL` env override | Complete | `runtime_config_service.dart` L7–8, L66–68 |
| Activation validate-key + desktop | Complete | `activation_service.dart`, `activation_screen.dart` |
| `branchCode` + `deviceUuid` in activate body | Complete | `activation_service.dart` L126–132; UUID from `syncDeviceId()` / `audit_device_id` |
| Token persist + refresh + verify | Complete | `app_meta` keys L29–36; refresh L194–241 |
| 401 → local revoke (verify + sync refresh) | Complete | `activation_service.dart` L180–186; `background_sync_service.dart` L367–369 |
| 403 suspend → overlay (not revoke) | Complete | `license_gate_service.dart`, `license_blocked_overlay.dart` |
| Tenant conflict + optional wipe | Complete | `local_tenant_data_service.dart`, `tenant_data_conflict_dialog.dart` |
| SQLite v22, outbox, push/pull | Complete | `database_service.dart` v22; `background_sync_service.dart` |
| Pull cursor transactional commit | Complete | `pullSyncNow()` L308–309 |
| Outbox `businessId`/`branchId`/`deviceId` | Complete | `_enqueueOutbox` L1912–1914 |
| Encrypted backup + restore integrity | Complete | `backup_crypto_service.dart`, `restore_service.dart` |
| Admin/waiter PIN hashing | Complete | `manager_data.dart`, schema v15–16 |
| Double-tap pay guard (UI) | Complete | `pos_order_screen.dart` L128–135 |
| Atomic sale + line snapshots | Complete | `manager_data_sales.dart` `recordSaleWithLines` |
| ESC/POS + cash drawer (Windows) | Complete | `lib/services/escpos/`, `windows_printers_service.dart` |
| Sync diagnostics | Complete | `sync_diagnostics_screen.dart`, `manager_top_bar.dart` |
| Windows Inno installer | Complete | `windows/installer/pos_system.iss` |

---

## C. Partially Complete Features

| Feature | What exists | What is missing | Risk |
|---------|-------------|-----------------|------|
| **Device revoke (pos_api)** | Local `revokeActivation()` on 401; diagnostics “Çaktivizo” | **`PATCH /devices/:id/revoke`** on user deactivate; distinguish device vs license vs business in UI | Server/device registry out of sync with terminal |
| **Force logout UX** | Revoke at **cold start** shows `ActivationScreen` | **No** `Navigator` to activation when revoked **during** POS session | Staff continues local POS with dead sync |
| **License/business suspend** | Full-screen overlay + “Kontrollo statusin” | No differentiation business vs license vs device; 401 on refresh during suspend may revoke instead of block | Confusing recovery |
| **Tenant isolation** | Columns + wipe dialog | Unscoped reads | Cross-business leakage |
| **Sync pull vs pos_api** | Bearer auth; scoped outbox | Pull query **without** explicit `branchId`; asymmetric entity set | Wrong-branch data if JWT mis-issued; multi-device drift |
| **Deactivation** | Local token clear + navigate from diagnostics | Server revoke; mid-app routing | Orphan active device records |
| **Backoff** | `SyncBackoffPolicy` counts failures | `currentDelay` unused for scheduling | Retry storms on reconnect |
| **Payment** | Atomic DB sale | Print before commit; swallowed print errors | Receipt/DB mismatch |
| **Inventory** | Schema + pull | UI; no stock decrement on sale | Non-production inventory |
| **macOS release** | Flutter target | `app_config.json` bundling | Misconfigured API URL |

---

## D. Missing Critical Features

### P0 — blocks real customer deployment

| Item | Detail |
|------|--------|
| Call **`PATCH /devices/:id/revoke`** on intentional deactivate | Use `activation_device_id` from `app_meta` (`ActivationService._kDeviceId`); add to `api_config.dart` |
| **Global activation listener** → `ActivationScreen` | On `revokeActivation()` / `!isActivated` while app running |
| **Device-revoked screen** | Clear copy vs license suspended (401 after admin revoke) |
| **Tenant-scoped reads** or mandatory wipe on business change | All `DatabaseService` queries |
| **pos_api pull contract** | Confirm branch validation matches desktop (JWT vs query); document required params |
| **Plaintext tokens in SQLite** | `activation_access_token`, `activation_refresh_token` in `app_meta` |

### P1 — important

| Item | Detail |
|------|--------|
| Expand pull to match push entities (waiters, orders, kitchen) | Server + `pull_sync_apply_service.dart` |
| Use `SyncBackoffPolicy.currentDelay` | Schedule retries |
| Rejected outbox viewer / export | Beyond 5 rows in diagnostics |
| Payment idempotency at DB layer | Not only `_isPaying` |
| Code signing + auto-update | `docs/17_WINDOWS_PACKAGING_INSTALLER.md` |
| Crash reporting + support bundle | ZIP: sync meta, redacted logs, versions |
| Production guard: refuse activate if `isUsingFallback` | Prevent production keys against localhost |

### P2 — polish

| Item | Detail |
|------|--------|
| Accessibility (`Semantics`) | None in `lib/` |
| Fiscal compliance layer | Not in code |
| Remove dead `WaiterSelectionScreen` name-only path | `waiter_selection_screen.dart` |
| Update stale docs | `PROJECT_AUDIT.md`, `TODO.md` |
| `voidSale` UI + PIN on refunds | Method exists, unused |

---

## Detailed audits (areas 1–15)

### 1. Runtime API configuration

**How URL is resolved** (`runtime_config_service.dart`):

1. `{exeDir}/app_config.json` → `apiBaseUrl`
2. Env `POS_API_BASE_URL`
3. Fallback `http://127.0.0.1:3000` (`_kFallbackUrl` L6)

Validation: must start with `http://` or `https://`; trailing slashes stripped (L71–80).

| Topic | Finding |
|-------|---------|
| Railway production | Example: `release/app_config.example.json` → `https://posapi-production-a6e7.up.railway.app` (no `/api` suffix; paths like `/activation/desktop` in `api_config.dart`) |
| Fallback risk | `isUsingFallback == true` → production activation keys hit **localhost**; debug warns in `main.dart` L33–38 |
| Prevent prod key on localhost | **Not enforced** — no startup block when fallback + non-debug build |
| `reloadConfig()` | Exists (L49) — **never called** from UI; config change needs restart |
| Installer bundle | Inno copies `release/app_config.json` → `{app}` (`pos_system.iss` L43–45) |

**pos_api connection:** ✅ Base URL is the only gate to Railway; operator must ship valid `app_config.json`.

---

### 2. Activation lifecycle

| Check | Status | Detail |
|-------|--------|--------|
| Endpoints / body | ✅ | `validate-key`: `{activationKey}`; `desktop`: `activationKey`, `branchCode`, `deviceUuid`, `deviceName`, `platform` |
| `branchCode` | ✅ | Required in UI; auto-filled from validate response (`activation_screen.dart` L62–64) |
| `deviceUuid` | ✅ | `DatabaseService.syncDeviceId()` → `audit_device_id` in `app_meta` (stable hardware id) |
| Server `deviceId` | ✅ | Stored separately as `activation_device_id` (server record id for revoke API) |
| Creates business? | **No** | Links existing `businessId` from key |
| After success | ✅ | `ManagerData.reload()`, `BackgroundSyncService.start()`, `LoginScreen` (`activation_screen.dart` L117–128) |
| Business change | ✅ | Clears sync cursor in `_persistActivation` (`activation_service.dart` L298–310) |
| Reset local activation | ✅ | `revokeActivation()` — tokens/sync meta only; sales data kept |
| Diagnostics reset | ✅ | Same + optional navigate to `ActivationScreen` (`sync_diagnostics_screen.dart`) |

**pos_api connection:** ✅ Matches activation API contract. ❌ Does not call server revoke on deactivate.

---

### 3. Device revoke / force logout

**pos_api:** `PATCH /devices/:id/revoke`

| Behavior | Status | Detail |
|----------|--------|--------|
| Desktop calls server revoke | ❌ **Missing** | No HTTP PATCH in codebase |
| 401 on verify (startup) | ✅ | `revokeActivation()` → next launch `ActivationScreen` |
| 401 on sync → refresh 4xx | ✅ | `revokeActivation()` + `BackgroundSyncService.stop()` |
| 401 on sync → refresh success | ✅ | Retries request |
| 403 on verify/sync | ⚠️ | **License block**, tokens kept — not device revoke |
| Navigate to `ActivationScreen` mid-session | ❌ **Missing** | `PosSystemApp(activated:)` fixed at `main.dart` L221 |
| Sync loop stops | ✅ | `stop()` on revoke path; license block also stops |
| Tokens cleared | ✅ | All `activation_*` keys emptied |
| Local data preserved | ✅ | By design (`docs/16_DEACTIVATION_LOGOUT_CLEANUP.md`) |
| User-visible blocked UI | ⚠️ | License overlay yes; **device revoked** indistinguishable from “sync failed” until restart |

**Classification:** **Partial** — local reaction to 401; **missing** server revoke + in-session force logout UX.

---

### 4. Business / license / device suspended

| Trigger | Desktop response | Recovery |
|---------|------------------|----------|
| 403 suspend (verify/refresh/sync) | `LicenseGateService.block()` + overlay | `LicenseSuspendedScreen`: refresh + verify; unblocks + `BackgroundSyncService.start()` on success |
| 401 device revoked | Local revoke (not overlay) | Re-activate — **no dedicated screen** |
| Background sync while blocked | Stopped (`background_sync_service.dart` L110–113, L246–249) | — |
| Aggressive retry | ❌ | Manual button only on suspended screen |
| After server reactivate | ✅ | If refresh+verify succeed, overlay clears |

**pos_api connection:** ⚠️ Suspend/reactivate works **if** API returns 403 with recognizable message (`license_gate_service.dart` L41–45). Device revoke via admin should use **401** — desktop treats as full local deactivation without explaining “revoked by admin”.

**Classification:** **Partial**

---

### 5. Tenant data isolation

See [§E](#e-tenant-isolation-risk). Summary:

| Item | Status |
|------|--------|
| `businessId`/`branchId` on writes | ✅ `syncScopeStamp`, outbox |
| Unscoped reads | ❌ All UI via unscoped `query()` |
| Business change detection | ✅ `LocalTenantDataService.detectConflict` |
| “Pastro të dhënat lokale” | ✅ `clearLocalBusinessData()` |
| `tables` / `company` | ❌ Not tenant-keyed |

**pos_api connection:** Server enforces tenant on API; **desktop SQLite can still display wrong tenant offline**.

---

### 6. Local SQLite / offline-first

| Capability | Status |
|------------|--------|
| Schema migrations v1→22 | ✅ `database_schema.dart` |
| Local source of truth | ✅ All POS operations |
| Outbox | ✅ v21+ |
| Encrypted backup | ✅ `BackupCryptoService` |
| Restore + `PRAGMA integrity_check` | ✅ `restore_service.dart` L254–271 |
| Undo restore | ✅ `.pre_restore_backup` sidecar |
| Data retention / purge | ❌ No TTL for sales/audit |

**Works offline:** sales, tables, menu CRUD, printing (local), manager dashboards.  
**Fails offline:** activation, verify, refresh, push/pull (skipped when offline).  
**Local-only (not in pull):** open `current_orders`, `kitchen_prints`, `tables` layout state.  
**Syncs to server:** outbox entities (sales, products, waiters, etc.) when online.

---

### 7. Sync system

| Topic | Finding |
|-------|---------|
| Push | `POST /sync/push` batch 100; strict parse; duplicates = synced |
| Pull | `GET /sync/pull?limit=200&since=cursor` — **no `branchId` param** |
| `branchId` on events | ✅ Each outbox row (`database_service.dart` L1912–1914) |
| Missing `branchId` safety | Rows stamped from `DatabaseSchema.setActivatedTenant`; if activation incomplete, placeholders `local-business` / `main-branch` |
| Cursor reset on tenant change | ✅ `_persistActivation` + tenant wipe clears `sync_pull_cursor` |
| Failed events | `markOutboxEventFailed`; diagnostics shows 5 + retry all failed |
| Backoff | Recorded but **not used** to delay (`SyncBackoffPolicy.currentDelay`) |
| Conflicts | Pull skips `syncStatus=pending`; no viewer |
| Restart recovery | ✅ Pending outbox + cursor persist in `app_meta` |
| **pos_api pull branch validation** | Desktop relies on **Bearer JWT** + per-row `branchId` in payloads; must match server expectations |

**Pull applies:** categories, products, shifts, sales, sale_lines, sale_adjustments, expenses, inventory_items, stock_movements.  
**Push also queues but pull does not apply:** waiters, current_orders, kitchen_*, etc.

---

### 8. Sales / payment flow

| Check | Status |
|-------|--------|
| Atomic sale + lines | ✅ Transaction in repository |
| Outbox on sale | ✅ `_queueOutboxById('sales', ...)` |
| Duplicate tap | ⚠️ UI `_isPaying` only |
| Print vs DB order | ⚠️ Print **then** `recordSaleWithLines`; print errors ignored |
| Sale snapshots | ✅ Product fields snapshotted at payment |
| Refunds | ✅ `recordAdjustment` in sales history |
| Full void | ⚠️ `voidSale()` exists — **no UI** |
| Failed sync preserves sale | ✅ Local sale committed regardless of push |

---

### 9. Products / categories / inventory

| Area | Local | Sync push | Sync pull |
|------|-------|-----------|-----------|
| Categories / products | ✅ CRUD | ✅ | ✅ |
| Inventory items / movements | ✅ DB | ✅ (if enqueued) | ✅ |
| Low stock | ✅ `getLowStockItems()` | — | — |
| Inventory UI | ❌ | — | — |
| Stock on payment | ❌ | — | — |

**Conflicts:** pending local row blocks pull overwrite.

---

### 10. Waiters / staff / PINs / shifts / payroll

| Area | Status |
|------|--------|
| Waiter PIN (PINMODE) | ✅ `login_screen.dart` `findWaiterByPin` |
| Manager PIN | ✅ Hashed; rate limit + session timeout |
| Hardcoded 9999 / admin/admin | ✅ **Not in `lib/`** |
| `WaiterSelectionScreen` | ⚠️ Name-only tap — route only from deprecated NAMEMODE card |
| Shifts / payroll / advances | ✅ Dashboard panels |
| Role permissions | ⚠️ Coarse (admin session vs waiter) |
| SQLite tampering | ⚠️ High — offline trust model |

**pos_api:** Waiters pushed but **not pulled** — staff roster won’t sync from cloud to second device.

---

### 11. Tables / current orders / kitchen

| Entity | Tenant columns | In pull | In push | Leak risk |
|--------|----------------|---------|---------|-----------|
| `tables` | ❌ | ❌ | ❌ | Occupancy crosses tenants |
| `current_orders` | ✅ | ❌ | ✅ | Local-only across devices |
| `kitchen_prints` | ✅ | ❌ | ✅ | Same |
| Tenant wipe | Re-seeds 15 empty tables | ✅ `seedEmptyTables` | — | ✅ |

---

### 12. Printer / hardware

| Topic | Status |
|-------|--------|
| ESC/POS Windows | ✅ |
| macOS/Linux | ❌ Early return |
| Disconnect | Print failure **non-fatal**; sale still records |
| Retry | `escpos_printer_service.dart` queue + job dedup |
| Cash drawer | ✅ After payment if enabled |
| Offline queue persist | ⚠️ In-memory dedup only |

---

### 13. UI / UX production readiness

| Screen | Notes |
|--------|-------|
| `ActivationScreen` | Solid flow; shows API source warning if fallback |
| `LicenseSuspendedScreen` | Clear; manual retry only |
| Sync diagnostics | Strong for ops; no export |
| Manager dashboard | Large feature set |
| `PosOrderScreen` | Functional; print-before-sale risk |
| Error/loading | Uneven on legacy screens |
| Accessibility | ❌ |
| Desktop sizing | Login responsive; no global min window in `windows/runner` |

**Missing for revoke:** No “Pajisja u çaktivizua nga administratori” full-screen when 401 mid-session.

---

### 14. Packaging / release

| Item | Status |
|------|--------|
| Windows `flutter build windows` + Inno | ✅ Documented `docs/17_WINDOWS_PACKAGING_INSTALLER.md` |
| `app_config.json` in installer | ✅ |
| Code signing | ❌ |
| Auto-update | ❌ Documented only |
| Version sync | ⚠️ `pubspec.yaml` 1.0.0+1 vs installer `#define AppVersion "1.0.0"` manual |
| SQLite path | Default sqflite FFI user dir — not bundled (correct) |
| macOS | No installer / config bundle |

---

### 15. Monitoring / debugging / support

| Item | Status |
|------|--------|
| Debug API logs | ✅ `kDebugMode` in `api_client.dart`, `activation_api_log.dart` (tokens redacted) |
| Production logs | ❌ |
| Crash reporting | ❌ |
| Diagnostics export / support bundle | ❌ |
| Remote troubleshooting | ⚠️ Manual: sync dialog + copy URL/cursor |

---

## E. Tenant Isolation Risk

### Scoped tables (writes)

`database_schema.dart` `syncScopeTables` + `inventory_items`, `stock_movements`, `outbox`.

Inserts use `DatabaseSchema.syncScopeStamp()` after `setActivatedTenant()`.

### Unscoped reads

`fetchProducts()`, `fetchCategories()`, sales loaders, dashboard aggregates — **no `WHERE businessId = ?`**.

Documented explicitly in `docs/20_DESKTOP_TENANT_DATA_ISOLATION.md` L35–37.

### Leak scenarios

1. Activate Business B, choose **“Ruaj të dhënat lokale”** → Business A menu/sales visible.
2. **`tables`** occupancy global per DB file.
3. **`company`** printer/admin PIN shared across tenants on same disk.
4. **Outbox** may still hold old `businessId` until pushed or wiped.

### Reset protection

| Action | Effect |
|--------|--------|
| “Pastro të dhënat lokale” | Wipes `tenantResetTables`, re-seeds tables, clears sync keys |
| Business change on activate | Clears pull cursor + sync timestamps |
| `revokeActivation()` | **Does not** wipe business data |

### Long-term fix

1. Scoped reads everywhere **or** hard-default to wipe on `businessId` change.  
2. Add `businessId` to `tables` or server-driven layout per branch.  
3. Integration tests with two businesses on one machine.

---

## F. Sync Risk

### Offline

- Operations continue; push/pull skipped.  
- `verifyActivation` network error → **does not** revoke (offline grace).

### Push / pull

- **Asymmetric entity sets** — primary multi-device risk.  
- Malformed push response → entire batch stays pending (safe).  
- Pull overwrites non-pending rows without `updatedAt` merge.

### Retry

- Connectivity → immediate push+pull.  
- Manual retry failed outbox in diagnostics.  
- **Backoff not applied to scheduling.**

### Branch scope (pos_api)

- Outbox: every event has `branchId` from activated tenant.  
- Pull request: **`since` + `limit` only** — branch enforcement must be **server-side via JWT**; desktop cannot detect client-side branch mismatch beyond failed/rejected events.

### Failure scenarios

| Scenario | Outcome |
|----------|---------|
| Admin revokes device on server | Next 401 → local revoke; user may stay on POS until restart |
| Wrong API URL (fallback) | Silent failure against localhost |
| Pending local + server update | Pull skip → stale server view on device |
| Refresh token missing | Re-activation required |

---

## G. Security Risk

| Risk | Severity | Notes |
|------|----------|-------|
| Plaintext tokens in `app_meta` | **High** | Copy DB → API access |
| No server revoke on deactivate | **High** | Device record stale |
| Mid-session revoke UX | **High** | Continued local use |
| Unscoped tenant reads | **High** | Data leak |
| SQLite file edit | **High** | Sales, license flags |
| License overlay bypass | **Medium** | Patch binary / meta |
| WaiterSelection name-only | **Low** today | NAMEMODE migrated away |
| First-run admin PIN from any unknown PIN | **Medium** | Fresh install |
| Audit hash chain | **Medium** | Tamper-evident, not forensic |
| Rate limiter resets on restart | **Low** |

**pos_api hardening not fully leveraged** until desktop calls device revoke and forces logout UI on 401.

---

## H. Required Next Prompts

Exact implementation roadmap (recommended order):

1. **Revoked device handling** — `PATCH /devices/:id/revoke` on deactivate; global listener → `ActivationScreen`; dedicated “Pajisja u çaktivizua” screen on 401 (vs license 403).
2. **Suspended license/business UX** — Parse server `message` codes; separate copy for business vs license vs device; avoid revoking tokens on 403.
3. **Tenant scoped reads** OR **strict default wipe** on `businessId` change (disable “keep local data” in production builds).
4. **Sync retry/backoff** — Wire `SyncBackoffPolicy.currentDelay`; optional jitter on connectivity restore.
5. **Conflict / rejected event viewer** — Full failed outbox list, entity type, reason, export JSON for support.
6. **pos_api pull parity** — Align pull entities with push + confirm branch validation contract (query param vs JWT).
7. **Block activation on localhost fallback** — `if (kReleaseMode && isUsingFallback) throw` or hard gate on `ActivationScreen`.
8. **Windows release** — Code signing, version bump automation, installer smoke test checklist.
9. **Auto-update** — Squirrel/MSIX or custom updater (per `docs/17_*`).
10. **Diagnostics export / support bundle** — zip: `app_meta` (redacted), sync status, outbox sample, versions, last errors.
11. **Secure token storage** — OS keychain / DPAPI.
12. **Payment hardening** — DB idempotency key; sale before print or print queue with retry.
13. **Automated tests** — activation, revoke, 403 vs 401, tenant wipe, outbox push, pull cursor.
14. **Inventory UI + stock on sale** — if product scope includes inventory.
15. **Doc cleanup** — Archive `PROJECT_AUDIT.md` / `TODO.md` pointers to this file.

---

## I. Final Checklist

Before **production-ready**:

### pos_api integration
- [ ] `PATCH /devices/:id/revoke` called on operator deactivate
- [ ] Server revoke (401) forces activation UI **during session**
- [ ] 403 suspend vs 401 revoke handled differently
- [ ] Pull/push entity parity documented and tested with pos_api
- [ ] Branch validation behavior verified end-to-end with Railway API

### Config & activation
- [ ] `app_config.json` on every install; fallback never in production
- [ ] Refresh token always stored
- [ ] Activation does not proceed on wrong base URL

### Data & tenant
- [ ] Reads scoped OR wipe mandatory on business change
- [ ] Multi-business manual test on one PC (`docs/20_*` checklist)

### Sync & sales
- [ ] Failed/rejected outbox visible and recoverable
- [ ] Backoff applied
- [ ] Payment idempotency beyond UI flag
- [ ] Print/sale ordering acceptable for finance

### Security & release
- [ ] Tokens not plaintext
- [ ] Signed installer
- [ ] Crash reporting + support bundle
- [ ] `flutter test` + critical integration tests green

---

## Stale artifacts (do not use as truth)

| File | Issue |
|------|-------|
| `PROJECT_AUDIT.md` | Pre-backend, v13 DB, hardcoded PINs |
| `TODO.md` | Printer “not implemented” — false |
| `docs/DESKTOP_BACKEND_INTEGRATION.md` “What Was Not Implemented” | Pull marked out of scope — **pull exists now** |
| `docs/15_PRODUCTION_API_CONFIG.md` | Fallback URL may say `/api`; code uses `http://127.0.0.1:3000` |

---

*End of audit — desktop inspected against hardened pos_api capabilities.*
