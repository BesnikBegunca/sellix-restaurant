# 73 — Desktop: sinkronizim i porosive të printuara (PRINTO)

**Data:** 2026-05-25  
**Projekti:** `pos_system`  
**Qëllimi:** Kur kamarieri shtyp **PRINTO**, porosia të shfaqet në `mobile_dashboard` → Orders (porosi të hapura/printuara), pa ndryshuar UI ose printimin lokal.

---

## Përmbledhje ekzekutive

| Para | Pas |
|------|-----|
| PRINTO → vetëm `kitchen_prints` / `current_orders` lokale | PRINTO → outbox `printed_orders` → `POST /sync/push` |
| `kitchen_prints` në outbox por **skip** (tip i pambështetur) | `printed_orders` në `supportedSyncEntityTypes` |
| PAGUAJ → vetëm `sales` | PAGUAJ → `sales` + `printed_orders` **update** (`paid` + `saleUuid`) |
| Mobile nuk sheh porosi të printuara | Mobile merr payload me `status: printed` |

**Shënim API:** `pos_api` duhet të pranojë entitetin `printed_orders` në `SUPPORTED_ENTITY_TYPES` dhe processor-in përkatës (jashtë këtij repo-je).

---

## Rrjedha

```mermaid
sequenceDiagram
  participant POS as Desktop POS
  participant DB as SQLite
  participant OB as outbox
  participant API as pos_api

  POS->>POS: PRINTO (_sendOrder)
  POS->>DB: insertKitchenPrint
  DB->>DB: kitchen_prints + lines
  DB->>OB: printed_orders create (uuid = kitchen_print.uuid)
  OB->>API: sync push

  POS->>POS: PAGUAJ (_payTable)
  POS->>DB: insertSaleWithLines
  DB->>OB: sales create
  DB->>OB: printed_orders update (paid + saleUuid)
  POS->>DB: clearTable (vetëm lokal)
  Note over DB: kitchen_prints lokale fshihen;\nprinted_orders NUK delete në cloud
```

Shih [74_PRINTED_ORDER_LIFECYCLE_SYNC.md](./74_PRINTED_ORDER_LIFECYCLE_SYNC.md) për ciklin Printuar → Paguar (pa fshirje pas pagesës).

---

## Entiteti `printed_orders`

- **Burim i vërtetë:** rreshti në `kitchen_prints` (çdo shtypje PRINTO = një batch).
- **UUID i qëndrueshëm:** `kitchen_prints.uuid` (entityUuid në outbox).
- **Idempotencë:** në të njëjtin transaction, `create` për të njëjtin `entityUuid` nuk përsëritet (`_hasOutboxEventForEntity`).
- **Nuk krijohet** nga shitjet e paguara — vetëm nga PRINTO.

### Shembull payload push

```json
{
  "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "orderNumber": 6,
  "tableId": 1,
  "tableName": "Tavolina 1",
  "waiterName": "Urim",
  "total": 3.00,
  "itemsCount": 1,
  "status": "printed",
  "printedAt": "2026-05-25T12:34:56.789Z"
}
```

Pas pagesës (update):

```json
{
  "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "orderNumber": 6,
  "tableId": 1,
  "tableName": "Tavolina 1",
  "waiterName": "Urim",
  "total": 3.00,
  "itemsCount": 1,
  "status": "paid",
  "printedAt": "2026-05-25T12:34:56.789Z",
  "saleUuid": "660e8400-e29b-41d4-a716-446655440010"
}
```

| Fushë | Burim |
|-------|--------|
| `uuid` | `kitchen_prints.uuid` |
| `orderNumber` | `kitchen_prints.orderNumber` |
| `tableId` | `kitchen_prints.tableId` |
| `tableName` | `Tavolina {tableId}` (i njëjti format si PAGUAJ) |
| `waiterName` | `kitchen_prints.waiterName` |
| `total` | `kitchen_prints.total` (batch-i i atij PRINTO) |
| `itemsCount` | shuma `qty` në linjat e batch-it |
| `printedAt` | `kitchen_prints.printedAt` (UTC në mapper) |
| `saleUuid` | vetëm pas pagesës, nga shitja e re |

---

## Skedarët e ndryshuar

| Skedar | Ndryshim |
|--------|----------|
| `lib/services/supported_sync_entity_types.dart` | Shto `printed_orders` |
| `lib/services/sync_push_payload_mapper.dart` | `_mapPrintedOrdersPayload` |
| `lib/services/database_service.dart` | Queue PRINTO / pay / delete; heq outbox `kitchen_prints` |
| `test/supported_sync_entity_types_test.dart` | `printed_orders` i pranuar |
| `test/sync_push_payload_mapper_test.dart` | Teste payload |

**Pa ndryshim UI:** `pos_order_screen.dart`, `send_order_button.dart`.

**Printimi lokal:** `ReceiptPrinter.printKitchenOrder` i pandryshuar.

---

## Sjellje sipas veprimit

| Veprim | Outbox |
|--------|--------|
| PRINTO | `printed_orders` **create** |
| PAGUAJ (shitje e re) | `sales` create + `printed_orders` **update** (`paid`, `saleUuid`) — **i njëjti uuid** |
| clearTable pas pagesës | vetëm pastrim lokal; **jo** delete cloud |
| Fshirje PRINTO (void menaxher) | `printed_orders` **delete** |
| Retry sync | `create` idempotent për të njëjtin uuid |

`current_orders` / `kitchen_print_lines` mbeten jashtë push-it të mbështetur (si më parë).

---

## QA manuale

1. Hap tavolinë, shto artikuj, **PRINTO**.
2. `sync_diagnostics` → outbox `printed_orders`, `syncStatus: synced` (pas API).
3. Në mobile Orders: porosi me `#orderNumber`, tavolinë, kamarier, total.
4. **PAGUAJ** → shitja në `sales`; porositë e printuara `paid` + `saleUuid`; pas clear, delete në cloud.
5. Dy PRINTO radhazi → dy uuid të ndryshëm, dy rreshta në mobile (si refund panel lokalisht).

---

## Teste

```bash
flutter test test/sync_push_payload_mapper_test.dart test/supported_sync_entity_types_test.dart
```

---

## Kufizime

- `pos_api` duhet implementuar për `printed_orders` (pull opsional).
- `tableName` nuk ruhet në `kitchen_prints` — derivuar `Tavolina {id}`.
- Çdo PRINTO = batch i veçantë (numër global i ri); nuk është një “porosi e vetme” e përditësueshme për të gjithë tavolinën.
- Shitje të paguara **pa** PRINTO nuk krijojnë `printed_orders`.

---

*Fund i raportit.*
