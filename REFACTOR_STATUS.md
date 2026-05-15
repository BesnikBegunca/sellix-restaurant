# Refactor Status — POS System

Qëllimi: split file të mëdha në `lib/features/` pa ndryshuar UI, logjikë, ose sjellje.
Pas çdo ekstraktimi: `flutter analyze --no-pub` → **0 errors**.

---

## ✅ Të përfunduara

| File | Para | Pas | Çfarë u bë |
|------|------|-----|------------|
| `lib/screens/manager_dashboard_screen.dart` | 8 614 | 150 | Split i plotë — 11 panel + 3 widget |
| `lib/manager/manager_data.dart` | 1 256 | 671 | Split në 3 part files (extension) |
| `lib/manager/manager_data_sales.dart` | — | 163 | Ekstraktuar: recordSale, recordSaleWithLines, recordAdjustment, topEmployee |
| `lib/manager/manager_data_menu.dart` | — | 234 | Ekstraktuar: addCategory, addProduct, editProduct, moveProduct |
| `lib/manager/manager_data_tables.dart` | — | 207 | Ekstraktuar: setTableLayout, clearTable, saveCurrentOrder, tablesForWaiter |
| `lib/services/database_service.dart` | 1 603 | 973 | Schema DDL → database_schema.dart |
| `lib/services/database_schema.dart` | — | 640 | ensureTables, upgrade, create, seedDefaultMenu |
| `lib/features/dashboard/panels/overview_panel.dart` | 1 049 | 233 | 6 widget → `widgets/overview/` |
| `lib/features/dashboard/panels/menu_panel.dart` | 1 064 | 452 | asset_picker.dart + category_product_table.dart |
| `lib/features/dashboard/panels/staff_payroll_panel.dart` | 1 308 | 418 | 3 widget → `widgets/staff/` |

---

## 🔴 Prioritet i lartë (>700 rreshta)

| File | Rreshta | Çfarë mund të ndahet |
|------|---------|----------------------|
| `lib/screens/admin_settings_screen.dart` | **1 331** | ⚠️ Vështirë — 10+ controllers të lidhur; kandidatë: _buildBackupCard, _buildReceiptSettingsCard |
| `lib/screens/sales_history_screen.dart` | **1 103** | Filtra widget, refund dialog, PDF export |
| `lib/screens/login_screen.dart` | **967** | PIN pad widget, waiter list widget |
| `lib/services/audit_log_service.dart` | **922** | Log methods sipas tipit: sales/menu/staff/shift |
| `lib/features/dashboard/panels/expenses_panel.dart` | **726** | Add-expense dialog, expense row widget |
| `lib/features/dashboard/widgets/staff/waiter_payroll_detail.dart` | **721** | Kalendar widget, advance dialog |
| `lib/screens/audit_log_screen.dart` | **690** | Filter bar, log list widget, detail dialog |
| `lib/features/dashboard/panels/company_settings_panel.dart` | **649** | Logo section, printer section, receipt preview |
| `lib/features/audit_log/widgets/audit_log_card.dart` | **643** | Per-type card variants |

---

## 🟡 Prioritet mesatar (400–700 rreshta)

| File | Rreshta | Çfarë mund të ndahet |
|------|---------|----------------------|
| `lib/services/database_service.dart` | **973** | Insert methods, fetch methods, shift methods → grupe |
| `lib/screens/pos_order_screen.dart` | **558** | Payment dialog, product grid widget |
| `lib/features/dashboard/panels/profits_panel.dart` | **546** | Chart widget, KPI cards |
| `lib/features/dashboard/panels/shift_panel.dart` | **529** | Shift summary card, close-shift dialog |
| `lib/features/dashboard/panels/tables_config_panel.dart` | **486** | Table grid widget, layout editor |
| `lib/services/sales_history_pdf.dart` | **464** | PDF builder — OK si është (vetëm PDFe) |
| `lib/features/sales_history/widgets/sale_card.dart` | **455** | Line items section, adjustment section |
| `lib/features/dashboard/panels/waiters_panel.dart` | **444** | Add-waiter dialog, waiter row, worked-days section |
| `lib/screens/table_selection_screen.dart` | **443** | Table grid widget |
| `lib/features/dashboard/panels/reports_panel.dart` | **434** | Chart widgets, export buttons |
| `lib/features/pos_order/widgets/order_panel.dart` | **421** | Order line row, total section |

---

## ⚪ OK — nuk kanë nevojë (nën 400 rreshta)

`database_schema.dart` (640) — vetëm DDL, nuk ka widget për të ndarë.
`sale_card.dart` (455) — tashmë në `lib/features/`, strukturë e mirë.

---

## Rregullat e refaktorimit

1. **Mos ndrysho UI** — asnjë ndryshim vizual
2. **Mos ndrysho logjikë** — metodat bëjnë saktësisht të njëjtën gjë
3. **Mos ndrysho navigimin** — routes dhe state management mbeten njëlloj
4. **Mos prish importet** — përdor `export` nëse widget kaloi në file tjetër
5. **`flutter analyze --no-pub`** pas çdo ekstraktimi — 0 errors
