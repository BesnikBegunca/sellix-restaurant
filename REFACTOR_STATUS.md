# Refactor Status — POS System

Qëllimi: split file të mëdha pa ndryshuar UI, logjikë, ose sjellje.
Pas çdo ekstraktimi: `flutter analyze --no-pub` → **0 errors**.

---

## ✅ Të përfunduara

| File | Para | Pas | Çfarë u bë |
|------|------|-----|------------|
| `lib/screens/manager_dashboard_screen.dart` | 8 614 | 184 | Split i plotë — 11 panel + 3 widget |
| `lib/manager/manager_data.dart` | 1 256 | 702 | Split në 3 part files (extension) |
| `lib/manager/manager_data_sales.dart` | — | 193 | recordSale, recordSaleWithLines, recordAdjustment, voidSale, topEmployee |
| `lib/manager/manager_data_menu.dart` | — | 234 | addCategory, addProduct, editProduct, moveProduct |
| `lib/manager/manager_data_tables.dart` | — | 345 | setTableLayout, clearTable, saveCurrentOrder, tablesForWaiter |
| `lib/services/database_service.dart` | 1 603 | 1 112 | Schema DDL → database_schema.dart |
| `lib/services/database_schema.dart` | — | 670 | ensureTables, upgrade, create, seedDefaultMenu |
| `lib/features/dashboard/panels/overview_panel.dart` | 1 049 | 233 | 6 widget → `widgets/overview/` |
| `lib/features/dashboard/panels/menu_panel.dart` | 1 064 | 452 | asset_picker.dart + category_product_table.dart |
| `lib/features/dashboard/panels/staff_payroll_panel.dart` | 1 308 | 418 | 3 widget → `widgets/staff/` |
| `lib/screens/sales_history_screen.dart` | 1 103 | 789 | SHKpiRow, SHTopProductsCard, SHCategoryChart, showSHRefundDialog |
| `lib/features/pos_order/widgets/order_panel.dart` | 421 | 151 | OrderLineRow, QtyButton, SendOrderButton, PayButton |
| `lib/features/dashboard/panels/expenses_panel.dart` | 729 | 461 | ExpensesEmptyState, ExpenseFilterChip, ExpensesDataTable |
| `lib/features/dashboard/panels/waiters_panel.dart` | 444 | 213 | WaiterList, WaiterGridCard |
| `lib/features/dashboard/panels/shift_panel.dart` | 529 | 276 | GjendjaDialog → widgets/shift/ |
| `lib/features/dashboard/panels/profits_panel.dart` | 546 | 508 | ProfitBreakdownRow → widgets/profits/ |
| `lib/features/dashboard/panels/reports_panel.dart` | 434 | 312 | ReportCard → widgets/reports/ |
| `lib/features/dashboard/panels/tables_config_panel.dart` | 575 | 548 | TableLegendDot → widgets/tables/ |
| `lib/features/sales_history/widgets/sale_card.dart` | 480 | 406 | AdjustmentRow → adjustment_row.dart |
| `lib/features/audit_log/widgets/audit_log_card.dart` | 643 | 575 | AuditKpiCard → audit_kpi_card.dart |
| `lib/screens/login_screen.dart` | 967 | 866 | HoverCardButton, NumKeyBody, HoverSmallChip → lib/widgets/ |
| `lib/screens/audit_log_screen.dart` | 690 | 525 | AuditKpiRow, AuditCategoryTabs, AuditEmptyState, AuditErrorCard |
| `lib/features/dashboard/panels/company_settings_panel.dart` | 649 | 501 | SettingsCard, LoginModeTile, SettingsCheckTile → widgets/settings/ |
| `lib/screens/sales_history_screen.dart` | 789 | 563 | SHFiltersCard (SHDateFilter publik, 5 metoda → widget) |

---

## ✅ 🟢 E lehtë — PËRFUNDUAR

| File | Para | Pas | Çfarë u nxjerr |
|------|------|-----|----------------|
| `order_panel.dart` | 421 | 151 | OrderLineRow, QtyButton, SendOrderButton, PayButton |
| `expenses_panel.dart` | 729 | 461 | ExpensesEmptyState, ExpenseFilterChip, ExpensesDataTable |
| `waiters_panel.dart` | 444 | 213 | WaiterList, WaiterGridCard |
| `shift_panel.dart` | 529 | 276 | GjendjaDialog |
| `profits_panel.dart` | 546 | 508 | ProfitBreakdownRow |
| `reports_panel.dart` | 434 | 312 | ReportCard |
| `tables_config_panel.dart` | 575 | 548 | TableLegendDot |
| `sale_card.dart` | 480 | 406 | AdjustmentRow |
| `audit_log_card.dart` | 643 | 575 | AuditKpiCard |
| `login_screen.dart` | 967 | 866 | HoverCardButton, NumKeyBody, HoverSmallChip |

---

## ✅ 🟡 Mesatar — PËRFUNDUAR

| File | Para | Pas | Çfarë u nxjerr |
|------|------|-----|----------------|
| `audit_log_screen.dart` | 690 | 525 | AuditKpiRow, AuditCategoryTabs, AuditEmptyState, AuditErrorCard |
| `company_settings_panel.dart` | 649 | 501 | SettingsCard, LoginModeTile, SettingsCheckTile |
| `sales_history_screen.dart` | 789 | 563 | SHFiltersCard (SHDateFilter publik + 5 metoda) |

---

## 🔴 Vështirë — coupling i rëndë, rrezik gabimi

| File | Rreshta | Arsyeja |
|------|---------|---------|
| `lib/screens/admin_settings_screen.dart` | **1 331** | `_buildReceiptSettingsCard` (rr. 301–587) dhe `_buildBackupCard` (rr. 588–1323) referojnë 10+ state fields: `_footerCtrl`, `_addressCtrl`, `_phoneCtrl`, `_useEscPos`, `_cashDrawerEnabled`, `_paperWidthMm`, `_isBackupOperation`, `_hasRestoreUndo`, etj. Do nevojiten 10+ parametra + callback — shton abstraktime. |
| `lib/screens/pos_order_screen.dart` | **567** | Ekran i vetëm `StatefulWidget`; logjika e pagesës, tavolina, dhe produktet janë të ndërthurura. |

---

## ⚪ OK si janë — nuk kanë nevojë

| File | Rreshta | Arsyeja |
|------|---------|---------|
| `lib/services/database_schema.dart` | 670 | Vetëm DDL SQL, nuk ka widget |
| `lib/services/sales_history_pdf.dart` | 464 | Vetëm PDF builder, një klasë logjike |
| `lib/services/audit_log_service.dart` | 922 | Service me metoda log — ndarja me `part of` mundësohet por rreziku vs. fitimi i vogël |
| `lib/services/database_service.dart` | 1 112 | Service DB — schema tashmë e ndarë; pjesa tjetër janë query metoda |
| `lib/features/dashboard/widgets/staff/waiter_payroll_detail.dart` | 721 | Tashmë i nxjerrë nga staff_payroll_panel; vetë është widget i madh por i lidhur |

---

## Rregullat

1. Mos ndrysho UI, logjikë, navigim, ose sjellje
2. Përdor `export` nëse widget lëviz nga `screens/` në `features/`
3. `flutter analyze --no-pub` → 0 errors pas çdo hapi
4. Privatët `_Foo` bëhen publike `Foo` kur dalin në file tjetër
