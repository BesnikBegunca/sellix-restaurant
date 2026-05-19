# POS SYSTEM DESKTOP — FULL ENGINEERING & PRODUCTION AUDIT

**Projekti:** `pos_system` (Flutter Desktop POS, Windows-first)  
**Data auditit:** 2026-05-19  
**Metoda:** Vetëm lexim kodi — **pa ndryshime kodi**  
**Burimi i së vërtetës:** Ky skedar + implementimi aktual në `lib/`  
**Repo të lidhura (jashtë workspace):** `pos_api` (NestJS), `pos_system_mobile` (SuperAdmin / ops)

> Kur dokumentacioni i vjetër (`docs/99`, pjesërisht `docs/17`) konflikton me kodin, **beso kodin dhe këtë raport**.

---

# 1. Executive Summary

Vlerësim brutal bazuar në kod real, jo në prani të endpoint-eve.

| Area | Score 1–10 | Verdict |
|------|:----------:|---------|
| **Offline-first architecture** | **8** | SQLite v22, shitje/pagesa lokale pa rrjet — vlera kryesore e produktit |
| **Sync reliability** | **5** | Push/pull funksionon për 9 entitete API; batch i prishur, connectivity ≠ API, void pa sync |
| **Multi-device readiness** | **4** | Shitje/katalog konvergojnë; porositë/kuzhina/kamarierët **jo** |
| **Tenant isolation** | **4** | Shkrim i scoped; lexime **pa** `businessId` — mbështetet në wipe, jo SQL |
| **Security** | **6** | Tokena në secure storage; PIN SHA-256 i dobët; DB lokale e lexueshme |
| **SQLite integrity** | **7** | FK ON, audit immutable, backup me integrity_check; migrime me catch bosh |
| **Activation flow** | **7** | Aktivizim + refresh + revoke 401; verify offline i paqartë; revoke server vetëm SuperAdmin |
| **Payment safety** | **7** | `saleUuid` + txn atomik + dedup outbox; rrezik dy kamarierë / void pa cloud |
| **Production readiness** | **5** | Windows + Inno + `app_config.json` guard; pa code signing, pa auto-update, pa telemetri |
| **Long-term scalability** | **4** | `ManagerData` + `DatabaseService` ~2200 rreshta; asymetri entitetesh |

### Përmbledhje një fjali

Desktop POS është **i fortë si terminal offline një-lokacioni** me sync të vërtetë vetëm për **9 tipet e mbështetura nga pos_api**; **nuk është** platformë multi-POS / multi-tenant pa disiplinë operative dhe punë shtesë në API + desktop.

### Bllokuesit më të mëdhenj të prodhimit

1. Lexime SQL **pa filtër tenant** — rrezik të dhënash të vjetra pas re-aktivizimit (debug) ose restore nga backup i tenant-it tjetër  
2. **Void/delete lokale** pa outbox → cloud/mobile mbajnë shitjen  
3. **Entitete të push-uara por jo të pull-uara** (waiters, orders, kitchen) → drift multi-device  
4. **Entitete në outbox pa processor API** → `failed` i përhershëm (`Unsupported entityType`)  
5. **`main()` loop i pafund** nëse `ManagerData._init()` hedh — app nuk nis kurrë  
6. Mobile dashboard **0** kur serveri nuk ka të dhëna — shpesh **B** (push) ose **C** (reject), jo gabim UI desktop

---

# 2. Arkitektura e sistemit

## 2.1 Diagrami i rrjedhës (implementim real)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Flutter UI (screens/widgets)                     │
│  pos_order_screen │ manager_dashboard │ activation │ sync_diagnostics  │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              ManagerData (ChangeNotifier, singleton, god-object)         │
│   parts: manager_data.dart │ _sales │ _menu │ _tables                    │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
            SalesRepository   ProductRepository   ShiftRepository …
            (delegim i hollë — pa logjikë domain)
                    │               │               │
                    └───────────────┼───────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│           DatabaseService (~2200+ rreshta) + DatabaseSchema              │
│   SQL │ migrations v22 │ outbox enqueue │ tenant wipe │ backup VACUUM    │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    ▼
                              SQLite (pos_system.db)
                                    │
        ┌───────────────────────────┴───────────────────────────┐
        │ Mutacion lokal                                         │
        │   → INSERT/UPDATE row + outbox (pending)             │
        │   → _scheduleSyncAfterLocalMutation()                  │
        └───────────────────────────┬───────────────────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│     BackgroundSyncService (singleton)                                    │
│   push: POST /sync/push (batch ≤100)                                     │
│   pull: GET /sync/pull?since=&limit=200                                  │
│   guards: connectivity, backoff, activated, license, config blocked       │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│   ApiClient (Dio) + RuntimeConfigService + ActivationService             │
│   Bearer nga SecureActivationTokenStore (çdo request)                   │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    ▼
                              pos_api (JWT tenant)
                                    ▼
                              PostgreSQL
```

## 2.2 Stack

| Shtresë | Teknologji |
|---------|------------|
| UI | Flutter 3.x, Material 3 |
| DB lokale | `sqflite` + `sqflite_common_ffi` (desktop) |
| HTTP | `dio` |
| Online gate | `connectivity_plus` (link-layer, **jo** ping API) |
| Tokena | `flutter_secure_storage` (DPAPI / Keychain / libsecret) |
| Printim | ESC/POS + fallback Windows text |
| Instalim | Inno Setup 6 |

## 2.3 Singleton dhe ChangeNotifier

| Komponent | Pattern | Roli |
|-----------|---------|------|
| `ManagerData.instance` | Singleton + ChangeNotifier | Cache globale UI |
| `ActivationService.instance` | Singleton | Aktivizim, verify, refresh |
| `ActivationStateController.instance` | ChangeNotifier | Routing: Activation / Login / Revoked |
| `BackgroundSyncService.instance` | Singleton | Sync |
| `DatabaseService.instance` | Singleton | Të gjitha SQL |
| `RuntimeConfigService.instance` | Singleton | API URL |
| `SyncStatusService.instance` | ChangeNotifier | Poll 10s diagnostikë |
| `LicenseGateService` | ChangeNotifier | Overlay 403 |

**~30+ singleton** në `lib/` — pa DI; e pranueshme për desktop POS, e vështirë për teste.

**Problemi:** tre burime për “a jemi aktivizuar?” — `ActivationService`, `ActivationStateController`, `SyncStatusService` — mund të divergojnë për një frame.

## 2.4 Repositories

`lib/repositories/` — vetëm delegim te `DatabaseService`; logjika e biznesit është në `ManagerData` dhe `DatabaseService`.

---

# 3. Startup & activation flow

## 3.1 Rendi i `main()` (`lib/main.dart`)

```
WidgetsFlutterBinding
  → sqflite FFI (Windows/Linux/macOS)
  → RuntimeConfigService.load()
  → ApiClient.configureBaseUrl + onUnauthorizedRevoke
  → while (ManagerData.isLoading) { delay 50ms }   ⚠️ PA TIMEOUT
  → ConnectivityService.initialize()
  → BackgroundSyncService.initialize()  // vetëm listener
  → loadPersistedActivation() → ActivationStateController
  → nëse configBlocked: stop sync, sync_last_error
  → else nëse activated: verifyActivation() → start() sync nëse ende activated
  → SyncStatusService.start()
  → runApp(PosSystemApp)
```

**Routing home:** `ConfigErrorScreen` → `LoginScreen` (activated) → `DeviceRevokedScreen` → `ActivationScreen`.

## 3.2 `RuntimeConfigService`

| Prioritet | Burim |
|:---------:|-------|
| 1 | `app_config.json` pranë exe |
| 2 | `POS_API_BASE_URL` env |
| 3 | `release/app_config.json` — **vetëm debug/profile** |
| 4 | `http://127.0.0.1:3000` — **bllokuar në release** |

`isBlockedInRelease = kReleaseMode && (isUsingFallback || isLocalhost)` → `ConfigErrorScreen`.

**Silent fallback:** JSON i prishur / path catch → `null` → shpesh bllokim release pa mesazh “skedari ekziston por është invalid”.

## 3.3 Aktivizimi

| Hapi | Skedar | Status |
|------|--------|--------|
| Validate key | `activation_screen` → API | ✅ |
| Tenant gate | `LocalTenantDataService.prepareForActivation` | ✅ release: wipe i detyrueshëm |
| Activate | `POST /activation/desktop` | ✅ |
| Persist | `app_meta` + `SecureActivationTokenStore` | ✅ |
| Verify startup | `GET /activation/verify` | ⚠️ `false` në çdo gabim rrjeti — offline vazhdon |
| Refresh | `POST /activation/refresh` në sync 401 | ✅ |
| Revoke 401 | `handleRevokedByServer` | ✅ |
| Revoke server nga desktop | `kServerRevokeAvailableToDesktop = false` | ❌ vetëm SuperAdmin mobile |

## 3.4 Race conditions / deadlocks / loops

| Problemi | Evidencë | Severity |
|----------|---------|----------|
| **Startup deadlock** | `ManagerData._init()` pa `try/finally`; nëse hedh, `isLoading` mbetet `true` → `main()` loop i pafund | **Kritik** |
| Dy `_initDB()` paralel | `DatabaseService.database` lazy pa lock | Mesatar (i rrallë) |
| Push + pull paralel | `_isSyncing` / `_isPulling` të ndara | Mesatar — ngarkesë API |
| Verify vs revoke | `_handlingRevoke` zvogëlon re-entrancy | I ulët |
| Activation loop | Nuk u gjet loop i qartë; load strict revokon nëse mungojnë tokena | — |

## 3.5 Hot restart

- Tokena: secure store + migrim nga `app_meta` legacy  
- Debug: cache file në Documents nëse keychain dështon  
- `activation_completed` + IDs në SQLite — kërkohet refresh token **jo-bosh**

---

# 4. SQLite audit

**Version:** 22 (`database_service.dart`)  
**FK:** `PRAGMA foreign_keys = ON` në `onOpen`  
**Migrime:** `DatabaseSchema.upgrade` — shumë `try/catch` bosh → dështime **të heshtura**

## 4.1 Tabela operacionale

| Table | businessId | branchId | Sync (uuid, timestamps, syncStatus) | Tenant-safe lexim? | Notes |
|-------|:----------:|:--------:|:-------------------------------------:|:------------------:|-------|
| `sales` | ✓ v18 | ✓ | ✓ | **Jo** | UNIQUE `uuid`; idempotencë pagese |
| `sale_lines` | ✓ | ✓ | ✓ | **Jo** | FK → sales |
| `sale_adjustments` | ✓ | ✓ | ✓ | **Jo** | |
| `expenses` | ✓ | ✓ | ✓ | **Jo** | |
| `shifts` | ✓ | ✓ | ✓ | **Jo** | `snapshotJson` on open |
| `products` | ✓ | ✓ | ✓ | **Jo** | |
| `categories` | ✓ | ✓ | ✓ | **Jo** | |
| `waiters` | ✓ | ✓ | ✓ | **Jo** | |
| `waiter_salaries` | ✓ | ✓ | ✓ | **Jo** | |
| `advances` | ✓ | ✓ | ✓ | **Jo** | |
| `waiter_worked_days` | ✓ | ✓ | ✓ | **Jo** | |
| `current_orders` | ✓ | ✓ | ✓ | **Jo** | Push po, pull **jo** |
| `current_order_lines` | ✓ | ✓ | ✓ | **Jo** | |
| `kitchen_prints` | ✓ | ✓ | ✓ | **Jo** | |
| `kitchen_print_lines` | ✓ | ✓ | ✓ | **Jo** | |
| `inventory_items` | ✓ NOT NULL | ✓ NOT NULL | ✓ | **Jo** | v22; pa UI shitje-stock |
| `stock_movements` | ✓ NOT NULL | ✓ NOT NULL | ✓ | **Jo** | |
| `outbox` | ✓ NOT NULL | ✓ NOT NULL | syncStatus, retry | **Jo** | FIFO push |
| `audit_logs` | ✓ | ✓ | ✓ | **Jo** | Triggers: no UPDATE/DELETE; **nuk** fshihet në wipe |
| `tables` | ✗ | ✗ | ✗ | **Jo** | Layout tavolinash; wipe → 15 bosh |
| `company` | ✗ | ✗ | ✗ | N/A | Singleton; ruhet në wipe |
| `shift` | ✗ | ✗ | ✗ | N/A | Legacy singleton |
| `app_meta` | ✗ | ✗ | meta | N/A | activation_*, sync_pull_cursor |

**Placeholder:** `local-business`, `main-branch` — backfill v18.

## 4.2 Transaksione

| Operacion | Txn | Outbox |
|-----------|:---:|:------:|
| `insertSaleWithLines` | ✅ | ✅ në të njëjtin txn; dedup `IfAbsent` |
| `insertSale` (legacy) | ❌ | Jashtë txn |
| `closeShiftRecord` | partial | ✅ `shifts` update |
| `insertShiftRecord` | — | **❌** |
| `deleteSaleById` | ✅ | **❌** |
| `pullSyncNow` apply | ✅ | cursor pas commit |
| `clearLocalBusinessData` | ✅ | fshin outbox |

## 4.3 Audit logs

- Hash chain në insert (`AuditLogService`)  
- Triggers SQLite: ndalim UPDATE/DELETE  
- **Nuk** sync-ohen përmes outbox  
- **Mbeten** pas tenant wipe — histori tenant-i të mëparshëm

## 4.4 Backup / restore / integrity

| Veçori | Status |
|--------|--------|
| `VACUUM INTO` / kopje | ✅ |
| Kriptim fjalëkalim (≥8) | ✅ |
| `PRAGMA integrity_check` pas restore | ✅ |
| Rollback automatik restore | ✅ |
| `_criticalTables` restore | ⚠️ vetëm 6 tabela — jo outbox/audit |

---

# 5. Tenant isolation audit

## 5.1 Modeli real

**Një SQLite për pajisje.** Izolimi = **wipe para aktivizimit** + stamp në shkrim, **jo** `WHERE businessId` në lexime.

| Mekanizëm | Skedar | Release |
|-----------|--------|---------|
| `detectConflict` | `local_tenant_data_service.dart` | ✅ |
| `prepareForActivation` | dialog wipe | ✅ mandatory |
| `clearLocalBusinessData` | `tenantResetTables` | ✅ |
| `activation_last_business_id` | `app_meta` | ✅ detektim |
| `setActivatedTenant` | `database_schema.dart` | ✅ outbox stamp |

## 5.2 Queries të parëmbyllura (mostra — të gjitha në `database_service.dart`)

| File | Query / Metodë | Scoped? | Risk |
|------|----------------|:-------:|------|
| `database_service.dart` | `fetchTables()` | Jo | Të dhëna layout të tenant-it tjetër |
| `database_service.dart` | `fetchCategories()`, `fetchProducts()` | Jo | Menu e përzier |
| `database_service.dart` | `fetchWaiters()` | Jo | |
| `database_service.dart` | `fetchSales()`, `fetchFilteredSales()` | Jo | Dashboard / historik |
| `database_service.dart` | `fetchExpenses()`, `fetchAllShifts()` | Jo | |
| `database_service.dart` | `getInventoryItems()` | Jo | |
| `database_service.dart` | `getPendingOutboxEvents()` | Jo | Outbox tenant i vjetër |
| `database_service.dart` | `fetchAuditLogs()` | Jo | Forenzik i përzier |
| `database_service.dart` | `fetchCurrentOrderTotalsByWaiter()` | Jo | Agregate globale |
| `database_service.dart` | `hasMeaningfulLocalBusinessData()` | Jo | `COUNT(*)` pa tenant |
| `support_bundle_service.dart` | `_fetchRecentOutbox` | Jo | Diagnostikë |

**Përfundim:** Tenant isolation **funksionon operativisht** vetëm nëse: (1) release wipe gjithmonë, (2) një biznes për makinë, (3) restore vetëm nga backup i duhur.

---

# 6. Payment & sale flow audit

## 6.1 Rrjedha (`pos_order_screen._payTable`)

1. `_isPaying` guard + audit `duplicatePaymentBlocked`  
2. Merge rreshtash porosie  
3. `resolvePaymentSaleUuid(tableId, waiterName)` → meta `payment_pending_{table}_{waiter}`  
4. **`recordSaleWithLines`** — txn atomik, outbox, **para printimit**  
5. Print (`ReceiptPrinter`) — gabim print **nuk** anulon shitjen  
6. `clearTable` + navigim  

## 6.2 Idempotencë

| Mekanizëm | Status |
|-----------|--------|
| UNIQUE `sales.uuid` | ✅ |
| `wasExisting` → pa print/outbox të ri | ✅ |
| `_queueOutboxByIdIfAbsent` | ✅ |
| `triggerSyncNow(force: true)` pas commit | ✅ (`docs/27`) |

## 6.3 Rreziqet e mbetura

| Rrezik | Severity |
|--------|----------|
| Dy kamarierë, e njëjta tavolinë — pending key përfshin `waiterName` → dy `saleUuid` | **Mesatar** |
| `voidSale` / `deleteSaleById` — pa outbox | **I lartë** (cloud drift) |
| `insertSale` legacy — UUID i ri çdo herë | **Mesatar** (jo nga UI) |
| `PinRateLimiter` vetëm në memorie | **Mesatar** |
| Dy instanca app — dy DB | **I lartë** (ops) |

## 6.4 Print policy

- **Commit-first, print-after** — ✅ implementuar  
- Reprint: `SaleReceiptService` nga historiku — ✅  

---

# 7. Sync architecture audit

## 7.1 Modeli

Outbox → `POST /sync/push` → `GET /sync/pull` → `PullSyncApplyService` (një txn) → cursor në `app_meta` vetëm pas suksesit.

## 7.2 Matrix entitetesh

| Entity | Local create | Push | Pull | Multi-device safe | Notes |
|--------|:------------:|:----:|:----:|:-----------------:|-------|
| `sales` | ✅ | ✅ | ✅ | ✅ (pas push) | `status: completed` injektuar në mapper nëse mungon |
| `sale_lines` | ✅ | ✅ | ✅ | ✅ | `saleUuid` në payload |
| `sale_adjustments` | ✅ | ✅ | ✅ | ✅ | |
| `categories` | ✅ | ✅ | ✅ | ✅ | |
| `products` | ✅ | ✅ | ✅ | ✅ | `categoryUuid` mapping |
| `expenses` | ✅ | ✅ | ✅ | ✅ | |
| `shifts` | open: ✅ | **vetëm close→update** | ✅ | ⚠️ | Hapja **nuk** shkon në cloud |
| `inventory_items` | ✅ | ✅ | ✅ | ⚠️ | Pa UI stock në shitje |
| `stock_movements` | ✅ | ✅ | ✅ | ⚠️ | |
| `waiters` | ✅ | ❌ reject | ❌ | **Jo** | Unsupported në API |
| `waiter_salaries` | ✅ | ❌ | ❌ | **Jo** | |
| `advances` | ✅ | ❌ | ❌ | **Jo** | `deleteAdvance` pa outbox |
| `waiter_worked_days` | ✅ | ❌ | ❌ | **Jo** | |
| `current_orders` | ✅ | ❌ | ❌ | **Jo** | |
| `current_order_lines` | ✅ | ❌ | ❌ | **Jo** | |
| `kitchen_prints` | ✅ | ❌ | ❌ | **Jo** | |
| `kitchen_print_lines` | ✅ | ❌ | ❌ | **Jo** | |
| `tables` | ✅ lokal | ❌ | ❌ | **Jo** | Layout per-device |
| `audit_logs` | ✅ lokal | ❌ | ❌ | N/A | Forenzik lokal |

**pos_api `SUPPORTED_ENTITY_TYPES`:** categories, products, inventory_items, shifts, sales, sale_lines, sale_adjustments, expenses, stock_movements.

## 7.3 Retry / backoff / connectivity

| Shtresë | Sjellje |
|---------|---------|
| Batch fail (rrjet, parse) | Të gjitha events mbeten `pending`; backoff eksponencial 2s–5min + jitter |
| Server `rejected` | `failed`, `retryCount++` |
| `force: true` | Anashkalon backoff (pas mutacionit) |
| Connectivity | Wi‑Fi ≠ API reachability |

## 7.4 `syncStatus` në entitet

Pas push të suksesshëm, **vetëm outbox** bëhet `synced`; rreshtat në `sales` etj. **mbeten `pending`** deri në pull — diagnostikë konfuze.

---

# 8. Outbox audit

## 8.1 Enqueue paths

- `_enqueueOutbox` — UUID i ri çdo event (pa dedup global)  
- `_queueOutboxByIdIfAbsent` — pagesa (`sales`, `sale_lines`)  
- Pas txn: `_scheduleSyncAfterLocalMutation()`  

## 8.2 Statuset

`pending` → `synced` | `failed`  
`retryCount` rritet vetëm për `rejected` serveri — **jo** për gabime rrjeti.

## 8.3 Gaps të verifikuara

| Veprim | Outbox? |
|--------|:-------:|
| Shitje / rreshta | ✅ |
| Mbyllje turni | ✅ update |
| Hapje turni | ❌ |
| Void shitje | ❌ |
| Fshirje expense/advance | ❌ (pjesërisht) |
| Waiters/orders/kitchen | ✅ enqueue → **API reject** |

## 8.4 Drift desktop / server / mobile

- Desktop krijon shitje lokale → push → serveri  
- Mobile lexon **serverin** — pa push, dashboard = 0  
- Entitete të push-uara por unsupported → outbox `failed` përgjithmonë  
- Void lokal → serveri ende ka shitjen → mobile e shfaq

---

# 9. API compatibility audit

Wire format push (`sync_push_payload_mapper.dart` + `SyncPushEventDto`):

```json
{ "uuid", "entityType", "entityUuid", "operation", "payload": { } }
```

Tenant në body: **jo** — nga JWT në pos_api.

| Entity | Desktop payload | API expects | Compatible | Problem |
|--------|-----------------|-------------|:----------:|---------|
| `sales` | snapshot + `soldAt` alias; `status` default `completed` | sale + soldAt, status | ⚠️ | Status “completed” i detyruar nëse mungon lokalisht |
| `sale_lines` | `productPrice`→`price`, `saleUuid` | line + saleUuid | ✅ | |
| `sale_adjustments` | `adjustmentType`→`type` | adjustment | ✅ | |
| `products` | `categoryId` int → `categoryUuid` | categoryUuid | ✅ | |
| `categories` | raw snapshot | category | ✅ | |
| `shifts` | update on close | shift upsert | ⚠️ | Open shift mungon në server |
| `expenses` | raw | expense | ✅ | |
| `inventory_items` | raw | inventory | ✅ | |
| `stock_movements` | raw | movement | ✅ | |
| `waiters` | full row | — | ❌ | `Unsupported entityType` |
| `current_orders` | full row | — | ❌ | |
| `kitchen_prints` | full row | — | ❌ | |
| `waiter_salaries` | full row | — | ❌ | |

**Pull limit:** desktop default 200; pos_api default 100 — mosmarrëveshje e vogël.

**Përgjigje push:** `accepted`, `duplicates`, `rejected[{uuid, reason}]` — parse i rreptë; batch i prishur → asnjë markim.

---

# 10. Mobile integration audit

`pos_system_mobile` **nuk është** në këtë workspace. Përfundimet nga arkitektura API + desktop.

## 10.1 Çfarë pret mobile

- Të dhëna **në PostgreSQL** pas sync desktop  
- SuperAdmin: biznese, degë, çelësa aktivizimi, revoke pajisje (`PATCH /devices/:id/revoke`)  
- Dashboard analytics: agregate server-side (jo SQLite desktop)

## 10.2 Çfarë dërgon desktop

- Vetëm 9 entitetet e mbështetura (kur push kalon)  
- **Jo** waiters, orders, kitchen, payroll në cloud  
- Shitjet kërkojnë push të suksesshëm për të parë në mobile

## 10.3 Pse mobile dashboard del **0**

| Kod | Kuptimi | Si të verifikosh |
|-----|---------|------------------|
| **A** | Desktop nuk krijon të dhëna | Shitje në historik lokal desktop |
| **B** | Desktop nuk push-on | `sync_diagnostics`: pending outbox, `sync_last_error`, config blocked |
| **C** | API nuk ruan | `failed` outbox, `rejected` reason në bundle |
| **D** | Dashboard query gabim | Branch/date/timezone në mobile vs server |
| **E** | Mobile parse/UI | API kthen të dhëna (curl/Postman) por UI 0 |

**Më i shpeshti në praktikë:** **B** (offline, config release, aktivizim, license block) ose **C** (payload reject, unsupported types të ngatërruara me sales).

**Kujdes:** Dashboard **desktop** lexon SQLite lokale (`ManagerData.revenueToday`) — mund të jetë >0 ndërsa **mobile** = 0 sepse serveri është bosh.

## 10.4 Entitete realisht të sinkronizuara mobile ↔ server

| Entitet | Në cloud për mobile? |
|---------|:--------------------:|
| sales, sale_lines, sale_adjustments | ✅ nëse push OK |
| products, categories | ✅ |
| expenses, shifts (mbyllje) | ✅ |
| inventory | ✅ (nëse përdoret) |
| waiters, orders, kitchen | ❌ |
| tables layout | ❌ |

---

# 11. Security audit

| Area | Risk | Severity | Notes |
|------|------|----------|-------|
| Tokena aktivizimi në DB plaintext | Mitiguar | ✅ Fixed | `SecureActivationTokenStore` + migrim |
| Localhost API në release | Mitiguar | ✅ | `ConfigErrorScreen` |
| Lexime pa tenant | Data leak | **Kritik** (debug) / **Lartë** | Wipe release |
| Kopje SQLite | Lexim i plotë i biznesit | **Lartë** | Fizik access |
| PIN admin/kamarier | SHA-256 + salt, pa PBKDF2 | **Mesatar** | Offline brute-force |
| PIN rate limit | Vetëm RAM, 5/60s | **Mesatar** | Reset në restart |
| SQL injection | Parametrizuar | **I ulët** | `VACUUM INTO` path i kontrolluar |
| Backup | AES me fjalëkalim përdoruesi | **Mesatar** | Fuqia e fjalëkalimit |
| Audit immutability | Triggers | **I ulët** | |
| Void pa sync | Integritet / mashtrim | **Lartë** | Operacional |
| Code signing Windows | Trojan install | **Lartë** | ❌ mungon |
| 403 license heuristic | Bllokim gabim | **Mesatar** | `LicenseGateService` |
| Support bundle | Redaktim sekretesh | **I ulët** | `support_bundle_redaction` |

---

# 12. Production deployment audit

## 12.1 Pipeline Windows

1. `flutter build windows --release`  
2. `release/app_config.json` (nga example; `scripts/verify_api_config.sh`)  
3. Inno Setup `windows/installer/pos_system.iss`  
4. Output: `release/installer_output/POSSystemSetup_1.0.0.exe`  

## 12.2 Çfarë duhet manualisht

- URL Railway/prodhimi në `app_config.json` për çdo build  
- SuperAdmin: çelësa aktivizimi, revoke pajisje  
- Trajnim: wipe në ndryshim biznesi; void policy  
- Restore drill në Windows 10/11  

## 12.3 Çfarë mund të dështojë në instalim real

| Skenar | Rezultati |
|--------|-----------|
| Pa `app_config.json` në release | `ConfigErrorScreen` — **me qëllim** |
| URL localhost në config release | Bllokuar |
| Linux pa libsecret | Tokena nuk ruhen — aktivizim i pamundur |
| Secure storage dështon në release | `saveTokens` rethrow |
| Dy versione app / restore backup i gabuar | Të dhëna të përziera |

## 12.4 Production-ready?

| Aspekt | Verdict |
|--------|---------|
| Pilot 1 degë, 1–2 POS, staff i trajnuar | **Po**, me kushte |
| Multi-POS i sinkronizuar plotësisht | **Jo** |
| Retail chain pa ops | **Jo** |

**Mungon:** code signing, auto-update, telemetri crash, fiscal.

---

# 13. Logging & diagnostics audit

| Zona | Ku loggohet | Mjaftueshëm? |
|------|-------------|:------------:|
| Runtime config | `debugPrint` vetëm debug | ⚠️ Release: jo |
| Aktivizim | `[Activation]` debug | ⚠️ |
| Sync push/pull | `debugPrint` + `app_meta` sync_last_* | ✅ Meta; ⚠️ detaje event |
| Outbox failed | DB + UI `sync_diagnostics_screen` | ✅ |
| Support bundle | `SupportBundleService` + redaction | ✅ |
| Revoke 401 | `handleRevokedByServer` | ⚠️ |
| Payment duplicate | `audit_logs` | ✅ |
| ManagerData init fail | **Asgjë** — deadlock silent | ❌ |

**Debugging i vështirë:** `syncStatus` entity vs outbox; push OK por entity ende `pending`; connectivity “online” por API down.

---

# 14. Test coverage audit

| Test Area | Exists | Quality | Missing |
|-----------|:------:|:-------:|---------|
| Payment idempotency | ✅ | I ulët | Vetëm meta key string — jo DB insert |
| Activation persistence | ✅ | I ulët | `nonEmptyMeta` helper |
| Activation revoke | ✅ | Mirë | Heuristics 401 |
| Tenant gate | ✅ | Mirë | Modele + lista wipe |
| Sync backoff | ✅ | Mirë | Policy math |
| Sync payload mapper | ✅ | Mirë | `saleUuid` mapping |
| Runtime config localhost | ✅ | Mirë | |
| Secure token store | ✅ | I ulët | Konstante |
| Support bundle redaction | ✅ | Mirë | |
| Widget smoke login | ✅ | Minimal | |
| **Integration: sale→outbox→push** | ❌ | — | **Kritik** |
| **E2E activation** | ❌ | — | |
| **Tenant scoped reads** | ❌ | — | |
| **voidSale sync** | ❌ | — | |

**10 skedarë test** në `test/` — nuk mbulojnë flow-in kryesor POS.

---

# 15. Technical debt

| Priority | Problem | Impact | Effort |
|:--------:|---------|--------|--------|
| P0 | Lexime SQL pa `businessId` | Leak cross-tenant | L |
| P0 | `deleteSaleById` pa outbox delete | Cloud/mobile drift | M |
| P0 | Startup loop pa timeout në `ManagerData._init` | App hung | S |
| P0 | Push entitete unsupported (enqueue kot) | Outbox `failed` noise | M |
| P1 | Pull parity waiters/orders/kitchen **ose** ndalo push | Multi-device | L (API+desktop) |
| P1 | `insertShiftRecord` pa outbox | Turni “open” invisible në cloud | S |
| P1 | `syncStatus` entity pas push | Diagnostikë konfuze | M |
| P1 | Integration test suite | Regresione | M |
| P1 | Code signing installer | Security trust | M |
| P2 | Refactor `ManagerData` / `DatabaseService` | Velocity | L |
| P2 | PIN PBKDF2 + rate limit persistent | Security | M |
| P2 | Inventory UI + stock në shitje | Feature complete | L |
| P2 | Arkivim `docs/99`, përditësim `docs/17` | Doc drift | S |

**God objects:** `DatabaseService`, `ManagerData`, `BackgroundSyncService`.

**Fake-complete:** outbox për waiters/orders; inventory schema pa flow; sync “completed” në mapper; dashboard mobile që supozon cloud të plotë.

---

# 16. Final verdict

## What Actually Works

- Shitje/pagesa offline me SQLite transaksional dhe idempotencë `saleUuid`  
- Outbox + push/pull për **9 entitetet pos_api**  
- Aktivizim, tokena secure, verify offline-friendly, revoke 401 UI  
- Bllokim localhost në release, `ConfigErrorScreen`  
- Backoff, retry failed outbox, support bundle  
- Audit log immutable, backup i kriptuar, restore me integrity_check  
- Windows installer + `app_config.json`  

## What Is Partially Working

- Multi-device për **katalog + shitje të push-uara**  
- Tenant isolation (wipe release, lexime jo scoped)  
- Verify activation (offline vs invalid token i paqartë)  
- Sync pas mutacionit (`docs/27` — disa gaps void/delete)  
- Inventory (schema + pull, pa UX shitje)  
- License 403 (heuristic, jo error codes strukturor)  

## What Is Broken

- Outbox për entitete **pa** processor API → `failed` i përhershëm  
- Void shitje → serveri **nuk** fshihet  
- Hapje turni → **nuk** shfaqet në cloud  
- `ManagerData._init` exception → **deadlock startup**  
- Mobile dashboard 0 kur push nuk ka ndodhur (sjellje e pritur, produkt i keq komunikuar)  

## Production Blockers

1. Politika void/delete vs cloud  
2. Trajnim wipe + `app_config.json` i saktë çdo build  
3. SuperAdmin për revoke  
4. Mos përdorim multi-POS për porosi të hapura të waiter-ve të ndryshëm në të njëjtën tavolinë  
5. Fix P0 startup timeout (rekomandim inxhinierik — **jo** implementuar në këtë audit)  

## Multi-device Risks

| Skenar | Rezultati |
|--------|----------|
| Dy POS, i njëjti menu | Pull konvergon products/categories |
| Dy POS, porosi të hapura | **Divergjencë** — orders nuk pull-ohen |
| Void në POS A | POS B + mobile shfaqin ende shitjen |
| Turni hapur A, mbyllur B | Konfuzion shifts në cloud |

## Immediate Fixes (rekomandime, pa kod në këtë sesion)

1. Shto timeout + `try/finally` në `ManagerData._init`  
2. Mos enqueue outbox për `entityType` jo në `SUPPORTED_ENTITY_TYPES`  
3. `deleteSaleById` → outbox `delete` + kontratë API  
4. Runbook: “mobile 0 = kontrollo push në sync diagnostics”  
5. Test integrimi: activate → sale → push → pull  

## Future Architecture Problems

- Monolit `DatabaseService` — çdo feature e re rrit rrezikun SQL  
- Dy burime të së vërtetës aktivizimi + `syncStatus` i rremë në entitet  
- Connectivity si proxy për API health  
- Pa event sourcing / CRDT për porosi multi-device  

## Recommended Next Steps

1. P0: scoped reads **ose** DB per tenant file  
2. P0: outbox delete për void + test E2E sync  
3. P1: vendos strategji — ose API pull për orders/waiters, ose ndalo push  
4. P1: integration tests në CI  
5. P1: signed installer  
6. P2: refaktor ManagerData  

## Honest Production Rating

| Kontekst | Rating |
|----------|:------:|
| **Pilot i fortë** — 1 lokacion, 1 degë, 1–2 POS, ops i trajnuar, Railway | **6.5 / 10** |
| **Multi-POS i sinkronizuar** për porosi/kuzhinë | **3 / 10** |
| **Multi-tenant SaaS** pa wipe strikt | **3 / 10** |
| **Offline-first core** | **8 / 10** |

---

## Appendix A — Skedarë kryesorë

| Zona | Path |
|------|------|
| Startup | `lib/main.dart` |
| Config | `lib/services/runtime_config_service.dart` |
| Aktivizim | `lib/services/activation_service.dart` |
| Tokena | `lib/services/secure_activation_token_store.dart` |
| Sync | `lib/services/background_sync_service.dart` |
| Pull | `lib/services/pull_sync_apply_service.dart` |
| Payload | `lib/services/sync_push_payload_mapper.dart` |
| DB | `lib/services/database_service.dart`, `lib/services/database_schema.dart` |
| Tenant | `lib/services/local_tenant_data_service.dart` |
| Pagesë | `lib/screens/pos_order_screen.dart`, `lib/manager/manager_data_sales.dart` |
| API types (repo fqinj) | `pos_api/src/sync/constants/supported-entity-types.ts` |
| Installer | `windows/installer/pos_system.iss` |

## Appendix B — Dokumentacion desktop (20–27)

| Doc | Status |
|-----|--------|
| `20` Tenant isolation | ✅ përputhet me kod (lexime unscoped) |
| `21` Revoked device | ✅ |
| `22` Sync retry failed | ✅ |
| `23` Production API config | ✅ |
| `24` Payment idempotency | ✅ |
| `25` Secure token storage | ✅ |
| `26` Support bundle | ✅ |
| `27` Auto sync after mutations | ✅ me gaps të listuara |
| `99` Remaining work | ❌ **STALE** — mos përdor |

---

*Fund audit — përditëso këtë skedar kur ndryshon sjellja materiale e kodit.*
