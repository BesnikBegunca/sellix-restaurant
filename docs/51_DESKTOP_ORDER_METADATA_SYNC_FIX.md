# 51 — Desktop: restaurim i metadata-së së porosisë në sync

**Data:** 2026-05-23  
**Projekti:** `pos_system`  
**Faza:** Phase 2 — metadata restoration (jo print/open orders, jo analytics)

---

## Përmbledhje ekzekutive

Desktop ruajti gjithmonë `waiterName`, `tableId`, `tableName` (në rreshta) dhe `orderNumber` (në print/porosi aktive), por **`SyncPushPayloadMapper` i striponte** para `POST /sync/push`. Tani metadata dërgohet në API; `sales` persiston `orderNumber` dhe `tableName` në pagesë.

---

## Shkaku rrënjësor

| Problem | Shkak |
|---------|--------|
| Kamarieri / tavolina humben në cloud | `_mapSalesPayload` → `out.remove('waiterName'/'tableId'/…)` |
| Numër porosie UUID në mobile | `orderNumber` mungonte në tabelën `sales` dhe në push |

---

## Skedarët e ndryshuar

| Skedar | Ndryshim |
|--------|----------|
| `lib/services/sync_push_payload_mapper.dart` | Mos strip metadata; `_normalizeSalesOrderMetadata` |
| `lib/services/database_schema.dart` | Migrim `sales.orderNumber`, `sales.tableName` |
| `lib/services/database_service.dart` | DB v23; `insertSaleWithLines` + kolona të reja |
| `lib/repositories/sales_repository.dart` | Parametra `orderNumber`, `tableName` |
| `lib/manager/manager_data_sales.dart` | `recordSaleWithLines` → insert |
| `lib/screens/pos_order_screen.dart` | `_payTable` → `orderNumber: _activeOrderNumber` |
| `test/sync_push_payload_mapper_test.dart` | Teste metadata të ruajtura |

---

## Sjellja e vjetër vs e re

| Aspekt | Para | Pas |
|--------|------|-----|
| Push `sales` | `total`, `soldAt`, `status` | + `waiterName`, `tableId`, `tableName`, `orderNumber` |
| Push `sale_lines` | 5 fusha (pa metadata) | **I njëjti** (pa ndryshim) |
| SQLite `sales` | pa `orderNumber` header | `orderNumber`, `tableName` kur paguhet |
| Pagesë pa Printo | `orderNumber` null | OK — vetëm shitje me print kanë numër |

### Shembull payload push (sales)

```json
{
  "uuid": "…",
  "total": 25.5,
  "soldAt": "2026-05-23T10:00:00.000Z",
  "status": "completed",
  "waiterName": "Arta",
  "tableId": 3,
  "tableName": "Tavolina 3",
  "orderNumber": 152
}
```

---

## Përputhshmëri prapa

- DB ekzistuese: migrim **v24** + `ensureSalesOrderMetadataColumns()` në `onOpen`/`upgrade`/`create` (idempotent, PRAGMA `table_info`).
- Shitje të vjetra lokale: kolonat e reja `NULL` — sync i ri i dërgon metadata vetëm për shitje të reja.
- `sale_lines` strip metadata — **e qëllimshme** (metadata vetëm në header `sales`).

---

## Teste

```bash
flutter test test/sync_push_payload_mapper_test.dart
```

- `sales preserves order metadata in push payload`
- `sales normalizes snake_case order metadata aliases`
- `sale_lines strips order metadata` (i pandryshuar)

---

## QA manuale

1. Printo porosi (numër global, p.sh. 152).
2. Paguaj tavolinën.
3. Verifiko sync (`sync_diagnostics` → outbox `synced`).
4. Në PostgreSQL / mobile: kamarier, tavolinë, `#152`.

---

## Rollback

1. Revert commit; DB v23 mbetet (kolona nullable — e padëmshme).
2. Mapper i vjetër strip — mobile kthehet në UUID/device (si më parë).
3. **Mos** fshi kolonat SQLite në prod pa plan migrimi.

---

## Kufizime të mbetura

- Porosi të printuara por të papaguara: **ende lokale** (`kitchen_prints`).
- `orderNumber` 0 nëse paguhet pa Printo.
- Shitje historike në cloud **pa** backfill automatik.

---

*Fund i raportit.*
