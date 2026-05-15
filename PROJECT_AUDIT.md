# PROJECT AUDIT REPORT

**Project:** `pos_system` (Flutter POS — pikë shitjeje)  
**Audit date:** 2026-05-15  
**Scope:** Read-only inspection of repository source, config, and tooling. No code was modified.  
**Analyzer:** `flutter analyze --no-pub` → **68 issues** (0 errors, 7 warnings, 61 info)

---

## 1. Executive Summary

### What this project does

`pos_system` is a **Flutter desktop-first POS application** (Windows/Linux/macOS via `sqflite_common_ffi`) for restaurant/retail operations: waiter login (PIN or name selection), table management, order taking, kitchen/receipt printing (ESC/POS + raw Windows spooler), shift management, sales history with refunds/voids, expenses, payroll/advances, manager dashboard with charts/PDF exports, encrypted backup/restore, and a **client-side license expiry** gate stored in SQLite.

All business data lives in a **local SQLite database** (`pos_system.db`). There is **no cloud backend**, **no Firebase**, and **no multi-device sync**.

### Current technical maturity

The project is **feature-rich for a single-terminal MVP** but **not production-hardened**. Significant refactoring has started (`REFACTOR_STATUS.md`, `manager_dashboard_screen.dart` reduced from ~8.6k to ~150 lines), yet many screens and services remain **500–1,300 lines**. Internal hardening reports (`SALES_HARDENING_REPORT.md`, `BACKUP_HARDENING_REPORT.md`) show deliberate improvements to sales archival and backup safety, but **security, testing, and operational readiness lag behind feature work**.

### Biggest strengths

- **SQLite as single source of truth** with schema versioning (v13), foreign keys, and transactional writes for sales (`insertSaleWithLines`).
- **Mature backup/restore pipeline**: `VACUUM INTO`, encrypted exports (`BackupCryptoService`), integrity checks, auto-rollback (`RestoreService`).
- **Audit log hash chain** in `DatabaseService.insertAuditLog` — tamper-evident local logging.
- **Cohesive visual design system** (`lib/theme/`) and growing `lib/features/` modularization.
- **Shift/sales hardening** — sales no longer deleted on shift close; `shifts` + `sale_adjustments` tables.

### Biggest weaknesses

- **Authentication is effectively absent**: manager PIN `9999` and dev credentials `admin`/`admin` are hardcoded; waiter PINs stored **in plaintext** in SQLite.
- **License enforcement is client-only** — trivially bypassable by editing `app_meta` or patching the binary.
- **Global singleton state** (`ManagerData.instance`) causes full-app rebuilds and makes testing/concurrency fragile.
- **Almost no automated tests** — one widget test that likely fails against current UI strings.
- **Very large UI files** (1,268 lines `admin_settings_screen.dart`, 907 lines `login_screen.dart`) — high bug and maintenance risk.
- **Printer integration incomplete** per `TODO.md`; payment can succeed while print fails silently.

### Main launch blockers

| Blocker | Severity |
|---------|----------|
| Hardcoded manager/dev credentials (`9999`, `admin`/`admin`) | P0 |
| Plaintext PIN storage; NAMEMODE skips waiter PIN | P0 |
| Client-only license (not suitable for paid distribution without server) | P0–P1 |
| No CI, no integration tests, broken/outdated widget test | P1 |
| `use_build_context_synchronously` in payment flow | P1 |
| Incomplete thermal printer path on Windows (`TODO.md`) | P1 (if receipts required) |

### Overall launch readiness score: **4 / 10**

**Interpretation:** Usable for a **controlled pilot** on one Windows machine with trusted staff, **not** for public/commercial release without security and ops work.

---

## 2. File-by-File Analysis

> Ratings: code quality 1–10, launch risk Low / Medium / High.  
> Files under 150 lines with no business logic are summarized in groups.

---

### File: `lib/main.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | App entry: FFI SQLite init, blocks until `ManagerData` loads, routes to license/dev/login/waiter screens, global `ThemeData`. |
| **Good** | Desktop sqflite FFI setup; centralized theme; license gate before main UI. |
| **Weak** | Busy-wait loop `while (ManagerData.instance.isLoading)` — blocks main isolate, no splash/timeout. |
| **Hidden risks** | Infinite hang if `_init()` fails silently; entire app rebuilds on every `ManagerData` notification. |
| **Bugs / runtime** | Unused import `app_tokens.dart` (analyzer warning). |
| **Code quality** | **7/10** |
| **Launch risk** | **Medium** |
| **Improvements** | Replace polling with `FutureBuilder`/splash; scope listeners to subtrees; handle init failures. |

---

### File: `lib/manager/manager_data.dart` (+ parts)

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Global `ChangeNotifier` singleton: company settings, menu, tables, sales, shifts, license, printers. |
| **Good** | Clear comment that DB is source of truth; split into `manager_data_sales/menu/tables.dart` parts; `reload()` after restore. |
| **Weak** | God-object (~587 lines + extensions); mixes domain logic, caching, and orchestration. |
| **Hidden risks** | In-memory cache can desync if DB mutated outside `ManagerData`; `shiftOpen = true` forced on init. |
| **Bugs / runtime** | `addWaiter` rejects PIN `9999` but does not hash PINs; duplicate PIN check is cache-only before DB unique constraint. |
| **Code quality** | **6/10** |
| **Launch risk** | **High** (central dependency) |
| **Improvements** | Repository layer; inject dependencies; explicit loading/error states. |

---

### File: `lib/manager/manager_data_sales.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Sales recording, void/refund orchestration, waiter totals. |
| **Good** | `recordSaleWithLines` documents atomic DB write; product snapshot at sale time. |
| **Weak** | Cache updated after DB — partial failure could desync (mitigated if DB throws). |
| **Hidden risks** | `voidSale` iterates `_salesHistory` in memory — stale if not reloaded. |
| **Code quality** | **7/10** |
| **Launch risk** | **Medium** |

---

### File: `lib/manager/manager_data_menu.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Category/product CRUD, reordering. |
| **Good** | Audit hooks; DB-first mutations. |
| **Weak** | Null-check patterns flagged by analyzer. |
| **Code quality** | **7/10** |
| **Launch risk** | **Low** |

---

### File: `lib/manager/manager_data_tables.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Table layout, current orders, clear table, persist orders. |
| **Good** | Transactional line replacement in `DatabaseService`. |
| **Weak** | Unused local `current` (analyzer warning). |
| **Hidden risks** | `pos_order_screen` clears UI cart on load — persisted lines merged only at pay time; staff may lose visibility of saved kitchen state. |
| **Code quality** | **6/10** |
| **Launch risk** | **Medium** |

---

### File: `lib/services/database_service.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | SQLite DAL: all CRUD, migrations trigger, audit log chain, sales/shifts/refunds. |
| **Good** | `PRAGMA foreign_keys`; `vacuumInto`; transactions for orders/sales/audit; version 13. |
| **Weak** | **1,011 lines** — still a god service; mixed concerns. |
| **Hidden risks** | `VACUUM INTO` path built via string interpolation (escaped, but fragile); no connection pooling needed but single `_db` cache. |
| **Bugs / runtime** | Race if `closeDatabase` during active UI writes. |
| **Code quality** | **6/10** |
| **Launch risk** | **High** |
| **Improvements** | Split by domain (SalesDao, MenuDao, etc.); integration tests per migration. |

---

### File: `lib/services/database_schema.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | DDL, `onCreate`/`onUpgrade`, seeds, `ensureShiftsSnapshotColumn`. |
| **Good** | Idempotent `ensureTables`; defensive `try/catch` on migrations; triggers documented. |
| **Weak** | Silent `catch (_) {}` on some migrations — failures may go unnoticed. |
| **Hidden risks** | DB v13 complexity — restore from old backup relies on upgrade path being correct. |
| **Code quality** | **7/10** |
| **Launch risk** | **Medium** |

---

### File: `lib/services/license_service.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | License expiry in `app_meta`; dev login validation. |
| **Good** | Simple API; extension stacks from current expiry. |
| **Weak** | **`devUsername`/`devPassword` = `admin`/`admin` hardcoded**; no cryptography. |
| **Hidden risks** | Anyone with file access can set `license_expires_at` in SQLite. |
| **Code quality** | **5/10** |
| **Launch risk** | **High** (commercial/licensing) |
| **Improvements** | Server-signed license, hardware binding, remove default dev creds from release builds. |

---

### File: `lib/services/backup_crypto_service.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | AES-256-CBC encrypted backup files with 100k SHA-256 iterations. |
| **Good** | Documented format; checksum verification; atomic temp writes. |
| **Weak** | Custom KDF (iterated SHA-256) vs standard PBKDF2/Argon2; no authenticated encryption (GCM). |
| **Code quality** | **8/10** |
| **Launch risk** | **Low** (for local backup use case) |

---

### File: `lib/services/backup_service.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Export DB as plain/compressed/encrypted. |
| **Good** | Uses `DatabaseBackupManager` + crypto. |
| **Weak** | Depends on admin UI for password UX. |
| **Code quality** | **7/10** |
| **Launch risk** | **Low** |

---

### File: `lib/services/restore_service.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Import backups with validation, rollback, undo. |
| **Good** | Excellent pipeline (magic bytes, integrity_check, critical tables, sidecar undo). |
| **Weak** | Restore while app active — UI must not write concurrently (`_isRestoring` flag only). |
| **Code quality** | **8/10** |
| **Launch risk** | **Medium** (operator error) |

---

### File: `lib/services/audit_log_service.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Typed audit events, PDF export, verification helpers. |
| **Good** | Rich event taxonomy; integrates with hash chain in DB. |
| **Weak** | **842 lines**; unused `input` variable; verification is local-only. |
| **Hidden risks** | Attacker with DB file can append forged rows unless chain verified on read (partially implemented). |
| **Code quality** | **6/10** |
| **Launch risk** | **Medium** |

---

### File: `lib/services/escpos/escpos_printer_service.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Raw ESC/POS bytes to Windows printer. |
| **Good** | Profile-based widths; cash drawer kick. |
| **Weak** | `onError` handler may not return value (warning); platform-specific. |
| **Code quality** | **6/10** |
| **Launch risk** | **Medium** |

---

### File: `lib/services/escpos/escpos_receipt_builder.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Build receipt byte payloads. |
| **Good** | Test receipt for admin verification. |
| **Code quality** | **7/10** |
| **Launch risk** | **Low** |

---

### File: `lib/services/windows_printers_service.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | List/print via PowerShell on Windows. |
| **Good** | Timeouts on Process.run; printer online check. |
| **Weak** | Shell injection surface if printer names malicious (partially escaped); **not a native channel** (TODO wants platform channel). |
| **Code quality** | **6/10** |
| **Launch risk** | **Medium** |

---

### File: `lib/services/receipt_printer.dart` / `receipt_text.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | High-level print API for kitchen/payment/shift receipts. |
| **Good** | Abstraction over ESC/POS and text paths. |
| **Weak** | Failures often swallowed by callers (`catch (_) {}` in `pos_order_screen`). |
| **Launch risk** | **Medium** |

---

### File: `lib/models/pos_models.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Domain models: waiters, sales, expenses, categories, etc. |
| **Good** | `fromMap` factories; immutable-style fields. |
| **Weak** | `WaiterInfo.pin` as plain `String`. |
| **Code quality** | **7/10** |
| **Launch risk** | **Medium** (security model) |

---

### File: `lib/models/mock_data.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Misnamed — contains `TableInfo`, `ProductItem` (not mocks). |
| **Good** | Shared lightweight models. |
| **Weak** | Confusing filename; duplicates concepts in `pos_models.dart`. |
| **Code quality** | **6/10** |
| **Launch risk** | **Low** |

---

### Screen: `lib/screens/login_screen.dart` (907 lines)

| Aspect | Assessment |
|--------|------------|
| **Purpose** | PIN pad, built-in calculator, waiter/manager routing. |
| **Good** | PIN validation regex; failed PIN audit; responsive layout (`LayoutBuilder`). |
| **Weak** | **Manager PIN `9999` in source**; NAMEMODE rejects all waiter PINs at this screen. |
| **Hidden risks** | No lockout/rate limit on PIN attempts. |
| **Bugs** | Widget test expects `'Enter PIN'` — may not match localized UI. |
| **Code quality** | **5/10** |
| **Launch risk** | **High** |

---

### Screen: `lib/screens/dev_mode_login_screen.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Login when license invalid; opens dev-only license panel. |
| **Good** | Clear UX when license expired. |
| **Weak** | Same hardcoded `admin`/`admin`. |
| **Launch risk** | **High** |

---

### Screen: `lib/screens/waiter_selection_screen.dart`

| Aspect | Assessment |
|--------|------------|
| **Purpose** | NAMEMODE waiter pick list. |
| **Good** | Audit on waiter select. |
| **Weak** | **No PIN required** — tap name → full table access; admin PIN dialog still `9999`. |
| **Launch risk** | **High** (NAMEMODE) |

---

### Screen: `lib/screens/table_selection_screen.dart` (411 lines)

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Grid of tables for selected waiter. |
| **Good** | Uses `ManagerData.tablesForWaiter`. |
| **Weak** | Large monolithic widget. |
| **Code quality** | **6/10** |
| **Launch risk** | **Medium** |

---

### Screen: `lib/screens/pos_order_screen.dart` (539 lines)

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Order UI: categories, cart, pay, print. |
| **Good** | `_isPaying` guard; atomic `recordSaleWithLines`; merges persisted + cart lines at payment. |
| **Weak** | `_loadPersistedOrder` **clears cart** intentionally — confusing for staff; print errors swallowed. |
| **Bugs** | `use_build_context_synchronously` after async pay (lines ~176, 336); unused `_hydrated`, `cellH`. |
| **Hidden risks** | Receipt prints **before** DB sale commit — customer gets receipt even if DB fails after print. |
| **Code quality** | **6/10** |
| **Launch risk** | **High** |

---

### Screen: `lib/screens/manager_dashboard_screen.dart` (~185 lines)

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Shell for 15 manager sections + dev-only license mode. |
| **Good** | Successful refactor from 8k+ lines; panel composition. |
| **Weak** | `devModeOnly` still allows license extension without re-auth timeout. |
| **Code quality** | **8/10** |
| **Launch risk** | **Medium** |

---

### Screen: `lib/screens/admin_settings_screen.dart` (1,268 lines)

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Login mode, backup/restore, printer/receipt toggles, ESC/POS settings. |
| **Good** | Comprehensive ops tooling in one place. |
| **Weak** | **Largest file in repo**; 10+ controllers; hard to test. |
| **Hidden risks** | Restore + backup while shift active — operator training required. |
| **Code quality** | **4/10** |
| **Launch risk** | **High** (data loss if misused) |

---

### Screen: `lib/screens/sales_history_screen.dart` (736 lines)

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Filters, KPIs, refund dialog, PDF export. |
| **Good** | Feature-rich reporting UI. |
| **Weak** | Monolith; deprecated `DropdownButtonFormField.value`. |
| **Code quality** | **5/10** |
| **Launch risk** | **Medium** |

---

### Screen: `lib/screens/audit_log_screen.dart` (645 lines)

| Aspect | Assessment |
|--------|------------|
| **Purpose** | Filterable audit trail + detail + PDF. |
| **Good** | Supports compliance narrative locally. |
| **Weak** | Size; chain verification UX unclear to end user. |
| **Code quality** | **6/10** |
| **Launch risk** | **Low** |

---

### Dashboard panels (`lib/features/dashboard/panels/`)

| File | Lines | Notes | Quality | Risk |
|------|-------|-------|---------|------|
| `overview_panel.dart` | ~233 | Refactored; composes widgets | 8/10 | Low |
| `shift_panel.dart` | 502 | Shift close + print dialogs | 7/10 | Medium |
| `menu_panel.dart` | 431 | Menu CRUD UI | 7/10 | Medium |
| `expenses_panel.dart` | 695 | Large; expense dialogs inline | 5/10 | Medium |
| `profits_panel.dart` | 522 | Charts + KPIs | 6/10 | Low |
| `reports_panel.dart` | 412 | Export actions | 7/10 | Low |
| `waiters_panel.dart` | 426 | PIN `9999` reserved message | 6/10 | Medium |
| `tables_config_panel.dart` | 551 | Layout editor | 6/10 | Medium |
| `staff_payroll_panel.dart` | 401 | Payroll summaries | 7/10 | Medium |
| `company_settings_panel.dart` | 627 | Logo, printer, receipt | 6/10 | Medium |
| `refund_panel.dart` | 395 | Kitchen print refunds | 7/10 | Medium |
| `license_panel.dart` | small | License extension UI | 6/10 | High |
| `top_employee_panel.dart` | 348 | Leaderboard | 7/10 | Low |

---

### Dashboard widgets (`lib/features/dashboard/widgets/`)

| File | Notes | Quality | Risk |
|------|-------|---------|------|
| `manager_side_nav.dart` | Navigation rail | 7/10 | Low |
| `manager_top_bar.dart` | Search/header | 7/10 | Low |
| `overview/*` | Charts, KPI cards — good separation | 8/10 | Low |
| `staff/waiter_payroll_detail.dart` | **702 lines** — calendar, advances | 5/10 | Medium |
| `menu/category_product_table.dart` | Product table | 7/10 | Low |

---

### POS order widgets (`lib/features/pos_order/widgets/`)

| File | Notes | Quality | Risk |
|------|-------|---------|------|
| `order_panel.dart` | 398 lines — cart sidebar | 7/10 | Medium |
| `cart_line.dart` | Line item widget | 8/10 | Low |
| `product_tile.dart` / `category_tile.dart` | Grid cells | 8/10 | Low |

---

### Sales history feature (`lib/features/sales_history/`)

| File | Notes | Quality | Risk |
|------|-------|---------|------|
| `models/sales_models.dart` | View models | 7/10 | Low |
| `widgets/sale_card.dart` | 469 lines — detail heavy | 6/10 | Medium |
| `widgets/sh_*` | KPI/charts/refund dialog | 7/10 | Medium |

---

### Theme (`lib/theme/`)

| File | Notes | Quality | Risk |
|------|-------|---------|------|
| `app_colors.dart`, `app_tokens.dart`, `app_spacing.dart`, `app_radius.dart`, `app_shadows.dart`, `app_text_styles.dart`, `pos_grid.dart` | Consistent design tokens | **9/10** | Low |

---

### Shared widgets (`lib/widgets/`, `lib/shared/`)

| File | Notes | Quality | Risk |
|------|-------|---------|------|
| `dashboard/*` | Reusable cards, KPI, dialogs | 8/10 | Low |
| `hover_interaction.dart` | Desktop hover polish | 8/10 | Low |
| `gg_header.dart` | Branded header | 7/10 | Low |

---

### Utils

| File | Notes | Quality | Risk |
|------|-------|---------|------|
| `lib/utils/image_utils.dart` | Image pick/resize for menu | 7/10 | Low |

---

### Config & platform

| File | Notes | Quality | Risk |
|------|-------|---------|------|
| `pubspec.yaml` | SDK ^3.10.4; sqflite, pdf, encrypt, fl_chart | 8/10 | Low |
| `analysis_options.yaml` | Default flutter_lints only | 6/10 | Low |
| `README.md` | **Flutter template — not project-specific** | 2/10 | Medium |
| `test/widget_test.dart` | Single test; likely **stale** | 3/10 | High |
| `android/`, `ios/`, `linux/`, `macos/`, `web/` | Standard Flutter scaffolding; **POS target is desktop** | N/A | Low |
| `windows/runner/*` | Default — no custom POS channels yet | 5/10 | Medium |
| `.gitignore` | Standard; no `.env` (none used) | 7/10 | Low |

---

### Documentation (non-code, informative)

| File | Value |
|------|-------|
| `REFACTOR_STATUS.md` | Honest tech-debt tracker |
| `SALES_HARDENING_REPORT.md` | Documents v8→v9 sales/shift fixes |
| `BACKUP_HARDENING_REPORT.md` | Documents backup crypto design |
| `TODO.md` | Printer work incomplete |

---

## 3. Architecture Review

### Folder structure

```
lib/
  main.dart
  manager/          # Global state + domain orchestration
  models/           # Data classes (some misplaced in mock_data.dart)
  screens/          # Full-page routes (many oversized)
  features/         # Partial modularization (dashboard, pos_order, sales_history, audit_log)
  services/         # DB, backup, print, audit, license
  theme/            # Design system ✓
  widgets/          # Shared UI
```

**Trend is positive** (`features/` extraction) but **incomplete** — half the app remains in `screens/` monoliths.

### Separation of UI and business logic

| Layer | Status |
|-------|--------|
| `DatabaseService` | Pure DAL — **good** |
| `ManagerData` | Domain + cache + UI notification — **acceptable but overloaded** |
| Screens/panels | **Heavy** — SQL calls sometimes from panels (`refund_panel.dart` calls `DatabaseService` directly) |

### State management

- **Pattern:** `ChangeNotifier` singleton + `addListener` in widgets.
- **Problems:** No dependency injection; testing requires global reset; broad `notifyListeners()` causes unnecessary rebuilds.
- **Missing:** `provider` / `riverpod` / `bloc` — not inherently bad for MVP, but scales poorly.

### Data flow

```
UI → ManagerData → DatabaseService → SQLite
         ↓ cache lists
UI ← notifyListeners()
```

Restore path: `RestoreService` → close DB → replace file → `ManagerData.reload()`.

### Dependency direction

Mostly **UI → ManagerData → DatabaseService**. Violations: some panels call `DatabaseService` directly; `AuditLogService` singleton called from everywhere.

### Reusability

Dashboard widgets (`lib/widgets/dashboard/`) are reusable. Screen-specific logic is often copy-pasted (PIN pads, dialogs).

### Scalability

| Dimension | Assessment |
|-----------|------------|
| Multi-terminal | **Not supported** — single SQLite file per machine |
| Multi-location | **Not supported** — no sync |
| Large menu/catalog | OK with SQLite indexes; UI may slow with huge grids |
| Concurrent waiters | Single process — OK for one POS terminal |

### Long-term maintainability

**Moderate risk.** Refactor momentum helps, but without finishing extraction and adding tests, velocity will drop as file sizes grow.

---

## 4. Launch Readiness

### Is this ready for production?

**No** — not for untrusted environments, multi-staff accountability, or licensed commercial distribution.

### What can break after launch?

1. **Silent print failures** — payment recorded, receipt missing (`catch (_) {}`).
2. **DB corruption** on power loss during write (SQLite mitigates but not eliminated).
3. **Restore during active service** — race with open orders.
4. **Migration failure** on upgrade from old backup — silent `catch` in schema helpers.
5. **Wrong waiter attribution** in NAMEMODE (no PIN).
6. **License expiry** blocks entire venue until dev login (if not pre-extended).
7. **Context/async bugs** in payment dialog after slow print.

### What is missing before launch?

- Secure credential storage (hashed PINs, configurable manager PIN).
- Release build stripping dev credentials.
- Integration tests for payment, shift close, restore.
- CI pipeline (`flutter analyze`, `flutter test`).
- Operator documentation (README is template).
- Printer E2E validation on target hardware.
- Error monitoring (Sentry/Crashlytics) — none.

### Acceptable for MVP?

**Yes, with constraints:**

- Single Windows PC in one venue.
- Trusted staff; NAMEMODE disabled; PINMODE only.
- Manager PIN changed from default (currently **not possible** without code change — blocker).
- Manual daily backup procedure trained.
- License pre-activated for long period.

### Must fix before public release

1. Remove/replace hardcoded `9999` and `admin`/`admin`.
2. Hash waiter PINs; lockout after N failures.
3. Server-side or signed license (if selling software).
4. Fix or remove broken tests; add CI.
5. Complete printer integration or document manual workflow.

### Scores

| Criterion | Score |
|-----------|-------|
| MVP readiness | **5 / 10** |
| Production readiness | **3 / 10** |
| Code maintainability | **5 / 10** |
| Security readiness | **2 / 10** |
| Performance readiness | **6 / 10** |
| UI/UX readiness | **7 / 10** |

---

## 5. Critical Problems (Top 10)

### 1. Hardcoded manager PIN `9999`

| | |
|--|--|
| **Why dangerous** | Anyone who knows restaurant POS conventions can access full manager dashboard, refunds, backup restore, license. |
| **Consequence** | Theft, fraudulent refunds, data wipe via restore, payroll manipulation. |
| **Files** | `lib/screens/login_screen.dart`, `lib/screens/waiter_selection_screen.dart`, `lib/features/dashboard/panels/waiters_panel.dart`, `lib/manager/manager_data.dart` |
| **Fix** | Configurable hashed PIN in DB; force change on first setup; rate limiting. |
| **Priority** | **P0** |

### 2. Dev Mode credentials `admin` / `admin`

| | |
|--|--|
| **Why dangerous** | Bypasses license gate; extends license indefinitely. |
| **Consequence** | Software piracy; continued use without payment. |
| **Files** | `lib/services/license_service.dart`, `lib/screens/dev_mode_login_screen.dart` |
| **Fix** | Remove from release builds; use compile-time flags + strong unique installer password. |
| **Priority** | **P0** |

### 3. Waiter PINs stored in plaintext

| | |
|--|--|
| **Why dangerous** | Backup file or disk access exposes all PINs. |
| **Consequence** | Account takeover, repudiation of audit trail. |
| **Files** | `lib/services/database_schema.dart` (`waiters.pin`), `lib/services/database_service.dart` (`insertWaiter`) |
| **Fix** | Store `sha256(pin + salt)` or bcrypt; compare hashes on login. |
| **Priority** | **P0** |

### 4. NAMEMODE has no waiter authentication

| | |
|--|--|
| **Why dangerous** | Tap any name → operate any table. |
| **Consequence** | Wrong waiter on sales, disputes, internal fraud. |
| **Files** | `lib/screens/waiter_selection_screen.dart`, `lib/main.dart` (routing) |
| **Fix** | Require PIN even in name mode, or remove NAMEMODE for production. |
| **Priority** | **P0** |

### 5. Client-only license enforcement

| | |
|--|--|
| **Why dangerous** | `app_meta.license_expires_at` editable with any SQLite tool. |
| **Consequence** | No reliable revenue protection. |
| **Files** | `lib/services/license_service.dart`, `lib/manager/manager_data.dart`, `lib/main.dart` |
| **Fix** | Online activation or RSA-signed license blobs verified in app. |
| **Priority** | **P0** (commercial) / **P2** (internal use) |

### 6. Payment flow: print before DB commit; errors swallowed

| | |
|--|--|
| **Why dangerous** | Financial record mismatch; staff assume sale saved when print failed or vice versa. |
| **Consequence** | Revenue loss, duplicate charges, customer disputes. |
| **Files** | `lib/screens/pos_order_screen.dart` (`_payTable`) |
| **Fix** | Transaction order: DB first, then print; surface errors; idempotency key. |
| **Priority** | **P1** |

### 7. `use_build_context_synchronously` in payment UI

| | |
|--|--|
| **Why dangerous** | Dialog after dispose → crash or wrong navigator state. |
| **Consequence** | Intermittent crashes at peak service. |
| **Files** | `lib/screens/pos_order_screen.dart` |
| **Fix** | Check `mounted` before `showGeneralDialog`; pass root navigator key. |
| **Priority** | **P1** |

### 8. No automated test coverage / broken widget test

| | |
|--|--|
| **Why dangerous** | Regressions in sales, migrations, restore undetected. |
| **Consequence** | Production data loss after upgrade. |
| **Files** | `test/widget_test.dart`, entire `lib/` |
| **Fix** | DB migration tests, payment integration test, CI on PR. |
| **Priority** | **P1** |

### 9. Monolithic admin/backup screen (1,268 lines)

| | |
|--|--|
| **Why dangerous** | High regression risk; restore logic adjacent to UI toggles. |
| **Consequence** | Accidental restore wipes live service data. |
| **Files** | `lib/screens/admin_settings_screen.dart` |
| **Fix** | Extract backup controller; confirmation gates; separate ops role. |
| **Priority** | **P1** |

### 10. Incomplete Windows printer integration

| | |
|--|--|
| **Why dangerous** | Core POS expectation (kitchen ticket) unmet on some setups. |
| **Consequence** | Operational workaround, order mistakes. |
| **Files** | `TODO.md`, `lib/services/windows_printers_service.dart`, `lib/screens/admin_settings_screen.dart` |
| **Fix** | Complete platform channel + persisted `company.printerName` workflow. |
| **Priority** | **P1** (if printing required) / **P2** (if optional) |

---

## 6. Strengths

1. **Thoughtful SQLite schema evolution** (v13) with shifts, sale lines, adjustments, kitchen prints, audit logs.
2. **Backup/restore engineering** above typical Flutter app quality — encryption, integrity check, undo.
3. **Audit log hash chain** — rare in POS MVPs; good foundation for local compliance narrative.
4. **Atomic sale recording** with line-item snapshots — protects historical accuracy when menu changes.
5. **Design system** (`lib/theme/`) — professional, consistent green/beige brand.
6. **Dashboard refactor** — `manager_dashboard_screen.dart` now maintainable; panels/widgets split.
7. **Desktop SQLite FFI** correctly initialized in `main.dart`.
8. **PDF exports** (sales, audit, expenses, manager summary) for manager workflows.
9. **Internal documentation** (`REFACTOR_STATUS`, hardening reports) shows engineering discipline.
10. **Shift model** — archival instead of deleting sales on close.

---

## 7. Weaknesses

### Technical debt

- 8+ files over 600 lines; 3 over 900 lines.
- Incomplete migration from `screens/` to `features/`.
- `REFACTOR_STATUS.md` lists remaining targets — work not done.

### Poor patterns

- Global singletons everywhere.
- Busy-wait in `main()`.
- Silent `catch (_) {}` for printing and migrations.
- Direct `DatabaseService` calls from UI panels.

### Duplicate / confusing code

- `mock_data.dart` naming vs actual domain types.
- Duplicate path entries in tooling (`lib\` vs `lib/` on Windows) — same files, but indicates messy tooling state.

### Fragile logic

- Cart cleared on order screen load while DB still has `current_order_lines`.
- License routing: invalid license → dev screen only (blocks normal ops).
- `shiftOpen = true` on every init — may mask closed shift state.

### Missing validation

- No max PIN attempt lockout.
- Money parsing in login calculator — limited but present; order screen relies on product prices from DB without server-side validation (N/A offline).

### Missing error handling

- Print failures hidden from user during payment.
- Init failure in `ManagerData._init` not surfaced to UI.

### Bad naming / docs

- `README.md` is generic Flutter starter text.
- Mixed Albanian/English UI strings.

### Risky dependencies

- `file_picker` ^6.1.1 — verify platform support for restore UX.
- PowerShell dependency for printing — fragile on locked-down Windows.

---

## 8. Security Review

| Area | Finding | Severity |
|------|---------|----------|
| **Authentication** | PIN compared as plain string; manager PIN hardcoded | Critical |
| **Authorization** | No role model beyond "waiter" vs "manager PIN"; dev mode is superuser | Critical |
| **Database rules** | N/A — local SQLite, full access to OS user | High |
| **Sensitive data exposure** | Full DB in user app data; backups may be unencrypted | High |
| **API keys** | None in codebase (good) | — |
| **Client-side trust** | All enforcement client-side; license and PIN trivially bypassed | Critical |
| **Role-based access** | Binary: waiter vs 9999 manager | High |
| **Input validation** | Basic PIN length/digits; SQL uses parameterized queries (good) | Medium |
| **Financial risks** | Refunds/voids in manager UI; no dual-control; audit log local only | High |

**No network attack surface** in core app — physical/console access is the threat model.

---

## 9. Performance Review

| Area | Finding |
|------|---------|
| **Rebuilds** | `ManagerData` listener on `PosSystemApp` rebuilds entire `MaterialApp` tree |
| **DB queries** | Generally fine for single terminal; sales history may grow — indexes on `sales.timestamp`, `shiftId` should be verified |
| **Listeners** | Many screens `addListener` on `ManagerData` — OK at this scale |
| **Large widgets** | `login_screen`, `admin_settings` — build/layout cost on low-end PCs |
| **Memory** | Company logo as `Uint8List` in memory; product images from assets/disk |
| **Images** | `image_utils.dart` — watch large menu images |
| **Caching** | In-memory lists in `ManagerData` — good for speed |
| **Startup** | Blocking wait on DB init — acceptable for small DB; no splash |

**Verdict:** Performance adequate for **single-terminal MVP**; not tested at 100k+ sales rows.

---

## 10. UI/UX Review

| Area | Finding |
|------|---------|
| **Consistency** | Strong — theme tokens, cards, buttons unified |
| **Responsiveness** | `LayoutBuilder` on login; dashboard panels adapt — good |
| **Empty states** | `app_empty_states.dart` used in dashboard |
| **Loading states** | Partial — `refund_panel` has `_loading`; many panels lack skeletons |
| **Error states** | SnackBars common; some flows silent (print) |
| **Navigation** | Imperative `Navigator.push` only — no named routes/deep linking |
| **Design quality** | **Above average** for internal POS tools |
| **Accessibility** | **No `Semantics` widgets found** — screen readers likely poor; contrast generally OK |

**Language mix:** Albanian labels in places, English in others (`Select Waiter`, `Admin PIN`) — polish needed for launch.

---

## 11. Recommended Roadmap

### Phase 1 — Must fix before launch

| Item | Why | Difficulty | Risk if ignored |
|------|-----|------------|-----------------|
| Replace hardcoded `9999` with configurable hashed manager PIN + first-run setup | Prevents trivial manager takeover | Medium | Fraud, data breach |
| Remove or gate `admin`/`admin` dev login in release builds | Stops license bypass | Easy | Revenue loss |
| Hash waiter PINs in DB | Protects credentials in backups | Medium | PIN leak |
| Disable or secure NAMEMODE for production | Prevents impersonation | Easy | Wrong sales attribution |
| Fix `pos_order_screen` async context + sale-before-print order | Stability & financial integrity | Medium | Crashes, receipt/DB mismatch |
| Add CI: `flutter analyze` + tests on every commit | Catch regressions | Easy | Silent breakage on upgrade |

### Phase 2 — Should fix soon after launch

| Item | Why | Difficulty | Risk if ignored |
|------|-----|------------|-----------------|
| Finish printer platform channel (`TODO.md`) | Operational reliability | Hard | Kitchen chaos |
| Split `admin_settings_screen.dart` | Safer backup UX | Medium | Accidental restore |
| Integration tests for restore + migrations | Data safety | Hard | Lost sales history |
| Rate-limit PIN attempts + audit alerts | Brute force | Medium | Unauthorized access |
| Signed license or online activation | Commercial model | Hard | Piracy |
| Replace `main()` busy-wait with splash + error UI | Professional startup | Easy | Hang on DB failure |
| Update README + operator runbook | Onboarding | Easy | Support burden |

### Phase 3 — Long-term improvements

| Item | Why | Difficulty | Risk if ignored |
|------|-----|------------|-----------------|
| Introduce proper state management (Riverpod) + repositories | Testability | Hard | Slow feature velocity |
| Cloud sync / multi-terminal | Scale beyond one device | Hard | Cannot grow venues |
| Complete `features/` extraction per `REFACTOR_STATUS.md` | Maintainability | Medium | More 1k-line files |
| Accessibility pass | Legal/inclusive requirements | Medium | Excluded users |
| Observability (crash reporting) | Post-launch debugging | Medium | Blind to field failures |
| GCM/authenticated encryption for backups | Crypto best practice | Medium | Theoretical backup attacks |

---

## 12. Final Verdict

### Is this project launch-ready?

**Not for general production.** It is **conditionally launch-ready** only as a **single-location, single-PC, trusted-operator pilot** on Windows, after changing default credentials and training staff on backup/restore.

### If yes — under what conditions?

- PINMODE only; NAMEMODE off.
- Manager PIN changed from `9999` (requires code change today — **must ship configurable PIN first**).
- Dev credentials stripped from release build.
- License pre-extended; dev login disabled in field.
- Daily encrypted backups verified with test restore.
- Printer path tested on exact hardware.
- Owner accepts **no cloud sync** and **local-only security**.

### If no — what exactly blocks it?

1. Hardcoded manager and dev credentials.  
2. Plaintext PINs and weak auth model.  
3. No test/CI safety net.  
4. Client-only license (if commercial).  
5. Payment/print ordering and silent failures.

### Final score: **4 / 10**

### Brutal honest recommendation

The team has built a **surprisingly complete offline POS** with **above-average data integrity work** (backup, sales archival, audit chain) for an MVP. However, **security is at demo level**, not restaurant level: **`9999` and `admin`/`admin` alone disqualify a public launch**. Treat the current build as an **internal alpha**: finish credential management, tests, and printer hardening, then run a **2-week pilot** with daily restore drills before calling it production. The UI is ready before the **trust model** is.

---

*End of audit report.*
