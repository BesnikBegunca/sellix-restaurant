# Desktop — auto-sync pas mutacioneve lokale

**Projekti:** `pos_system`  
**Data:** 2026-05-19  
**Qëllimi:** Pas çdo ruajtjeje lokale të rëndësishme, desktop të nisë menjëherë push të outbox-it që dashboard-i mobile të përditësohet shpejt.

---

## Pse dashboard-i mobile tregonte 0

Rrjedha e të dhënave:

```
Desktop POS
  → SQLite (offline-first)
  → outbox (pending)
  → POST /sync/push (pos_api)
  → PostgreSQL / API
  → pos_system_mobile (lexon serverin)
```

Mobile **nuk lexon** SQLite e desktop-it. Nëse desktop ruan shitjen lokalisht por **nuk bën push** menjëherë, serveri nuk ka ende shitjen → dashboard `business_admin` mbetet 0 derisa të ndodhë sync (periodik, connectivity, ose manual nga Sync Diagnostics).

---

## Sjellja e re

Pas **commit të suksesshëm** të transaksionit SQLite dhe enqueue të outbox-it:

```dart
unawaited(BackgroundSyncService.instance.triggerSyncNow(force: true));
```

Implementimi qendror: `DatabaseService._enqueueOutbox` (kur nuk jemi brenda `Transaction`) dhe pas transaksioneve që enqueue në `txn`.

### Rregulla

| Rregull | Detaj |
|---------|--------|
| Offline-first | Ruajtja lokale **nuk** varet nga rrjeti |
| Jo bllokues | Sync nuk `await` në UI; pagesa vazhdon edhe nëse push dështon |
| `force: true` | Anashkalon backoff për push të menjëhershëm pas mutacionit |
| Offline | `triggerSyncNow` kthen pa gabim; outbox mbetet `pending` |
| Dështim push | Ngjarjet **nuk** fshihen; retry nga backoff / connectivity / diagnostics |

---

## Operacionet që nisin sync

### Me outbox (sync automatik)

| Zona | Metoda / rrugë |
|------|----------------|
| **Pagesë / shitje** | `insertSaleWithLines` (pas transaksionit) |
| **Shitje legacy** | `insertSale` |
| **Rregullim shitjeje** | `insertSaleAdjustment` |
| **Shpenzime** | `insertExpense` |
| **Mbyllje turni** | `closeShiftRecord` |
| **Kategori / produkt** | `insertCategory`, `deleteCategory`, `insertProduct`, `updateProduct`, `deleteProduct`, `moveProductCategory` |
| **Inventar** | `insertInventoryItem`, `updateInventoryItem`, `insertStockMovement` |
| **Kamarierë / pagat** | `insertWaiter`, `updateWaiterPin`, `deleteWaiterById`, `upsertWaiterSalary`, `insertAdvance`, `setWorkedDay` |
| **Porosi aktuale** | `upsertCurrentOrderMeta`, `replaceCurrentOrderLines`, `clearCurrentOrder` |
| **Kuzhinë** | `insertKitchenPrint` |
| **Outbox manual** | `insertOutboxEvent` |

### Pa outbox (nuk shton ngjarje — dokumentim)

| Operacion | Shënim |
|-----------|--------|
| **Hapje turni** | `insertShiftRecord` — **nuk** enqueue outbox `create`; vetëm `closeShiftRecord` dërgon `update`. Sync pas hapjes **nuk** dërgon turn të ri në server. |
| **Fshirje shpenzimi** | `deleteExpenseById` — fshin lokalisht, **pa** outbox `delete` (gap i vjetër; mobile nuk reflekton fshirjen). |
| **Fshirje avansi** | `deleteAdvanceById` — e njëjta. |
| **Void shitjeje (manager)** | `deleteSaleById` — pa outbox. |

---

## Rrjedha e pagesës (POS)

1. `recordSaleWithLines` → `insertSaleWithLines` (txn + outbox sales/lines)  
2. **`triggerSyncNow(force: true)`** (fire-and-forget)  
3. Printim kupon / dialog suksesi  

Shitja mbetet e ruajtur edhe nëse push ose print dështon.

---

## Sjellja offline

1. Krijo shitje → outbox `pending` rritet  
2. `triggerSyncNow` → skip (offline), log debug  
3. Aktivizo internetin → `BackgroundSyncService` connectivity + backoff nisin push  
4. Mobile pas refresh tregon të dhënat  

---

## Sync Diagnostics

Pas push të suksesshëm (`BackgroundSyncService.triggerSyncNow`):

- `sync_last_push_at` / `sync_last_success_at` përditësohen  
- `sync_last_error` pastrohet  
- `SyncStatusService.refresh()` në `finally` (pending count, failed count)  

UI: **Sync Diagnostics** — pending duhet të ulet pas push; timestamp push përditësohet.

---

## Skedarë

| Skedar | Ndryshim |
|--------|----------|
| `lib/services/database_service.dart` | `_scheduleSyncAfterLocalMutation`, hook në `_enqueueOutbox`, pas txn për shitje/inventar/porosi/kuzhinë |

---

## Manual test checklist

1. [ ] Desktop me Railway API (`app_config.json` ose `POS_API_BASE_URL`).  
2. [ ] Aktivizo terminalin.  
3. [ ] Krijo një shitje (pagesë).  
4. [ ] **Sync Diagnostics:** pending rritet pastaj zvogëlohet; `sync_last_push_at` përditësohet.  
5. [ ] Mobile `business_admin` — refresh dashboard.  
6. [ ] Të ardhurat / porositë reflektojnë shitjen.  
7. [ ] Çaktivizo internetin; krijo shitje tjetër.  
8. [ ] Pending outbox mbetet > 0.  
9. [ ] Aktivizo internetin; sync automatik (connectivity + force pas mutacionit të radhës ose retry).  
10. [ ] Mobile përditësohet.  

---

## Lidhje

- `docs/22_DESKTOP_SYNC_RETRY_FAILED_EVENTS.md`  
- `docs/100_POS_SYSTEM_FULL_TECHNICAL_AUDIT.md` (§4 Sync)
