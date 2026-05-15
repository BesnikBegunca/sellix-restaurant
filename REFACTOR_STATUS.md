# Refactor Status — `manager_dashboard_screen.dart`

## Qëllimi
Ndajmë skedarin monolitik `lib/screens/manager_dashboard_screen.dart`
(fillimisht **8 614 rreshta / 66 klasa**) në skedarë të veçantë sipas arkitekturës
`lib/features/dashboard/`.

Rregull strikte: **vetëm ndarje kodi** — asnjë ndryshim UI, logjike apo state.

---

## Gjendja aktuale

| Skedar | Rreshta | Status |
|--------|---------|--------|
| `lib/screens/manager_dashboard_screen.dart` | **1 369** | 🔄 In progress |
| `lib/features/dashboard/panels/overview_panel.dart` | ~680 | ✅ Nxjerrë |
| `lib/features/dashboard/panels/shift_panel.dart` | ~280 | ✅ Nxjerrë |
| `lib/features/dashboard/panels/waiters_panel.dart` | ~320 | ✅ Nxjerrë |
| `lib/features/dashboard/panels/expenses_panel.dart` | ~480 | ✅ Nxjerrë |
| `lib/features/dashboard/panels/profits_panel.dart` | ~360 | ✅ Nxjerrë |
| `lib/features/dashboard/panels/reports_panel.dart` | ~435 | ✅ Nxjerrë |
| `lib/features/dashboard/panels/top_employee_panel.dart` | ~362 | ✅ Nxjerrë |
| `lib/features/dashboard/panels/menu_panel.dart` | ~950 | ✅ Nxjerrë |
| `lib/features/dashboard/panels/tables_config_panel.dart` | ~487 | ✅ Nxjerrë |
| `lib/features/dashboard/panels/staff_payroll_panel.dart` | ~720 | ✅ Nxjerrë |
| `lib/features/dashboard/widgets/stat_card.dart` | ~120 | ✅ Nxjerrë |
| `lib/shared/widgets/dashboard_helpers.dart` | ~40 | ✅ Nxjerrë |

`flutter analyze` → **0 errors** ✅

---

## Çfarë ka mbetur në `manager_dashboard_screen.dart`

Aktualisht skedari ka **1 369 rreshta / 14 klasa**:

### 1. `_CompanySettingsPanel` + `_CompanySettingsPanelState` (rr. ~159–803)
- Menaxhon emrin e kompanisë, logon, mënyrën e hyrjes (PIN / Emër), printerin
- Përdor: `FilePicker`, `WindowsPrintersService`, `PrinterSettingsStore`
- Destinacioni: `lib/features/dashboard/panels/company_settings_panel.dart`

### 2. `_ManagerSideNav` + `_SideNavItem` + `_SideNavItemState` (rr. ~805–1072)
- Shiriti anësor i navigimit (zgjeruar/ngushtuar, ikona, etiketa)
- Destinacioni: `lib/features/dashboard/widgets/manager_side_nav.dart`

### 3. `_ManagerTopBar` + `_ManagerTopBarState` + 4 widget ndihmës (rr. ~1073–1369)
- Shiriti i sipërm (titull seksioni, ora, badge menaxheri, gjendje turni)
- Nënklasa: `_ShiftStatusChip`, `_TopBarChip`, `_TopBarManagerBadge`, `_ManagerBusinessPill`, `_ManagerShiftPill`
- Destinacioni: `lib/features/dashboard/widgets/manager_top_bar.dart`

---

## Hapat e ardhshëm (në rend)

### Faza 1 — Ndarja e `manager_dashboard_screen.dart` (aktive)

- [ ] **1.** Nxjerr `_CompanySettingsPanel` → `company_settings_panel.dart`
  - Hiq importet e papërdorura nga dashboard pas nxjerrjes
  - Wire: `case 9: return CompanySettingsPanel(m: _m);`
- [ ] **2.** Nxjerr `_ManagerSideNav` + `_SideNavItem` → `manager_side_nav.dart`
- [ ] **3.** Nxjerr `_ManagerTopBar` + nënklasave → `manager_top_bar.dart`
- [ ] **4.** Pas 1–3: dashboard = vetëm `ManagerDashboardScreen` (~155 rreshta) ✨

### Faza 2 — Skedarë të tjerë të mëdhenj

- [ ] **5.** Nda `lib/screens/sales_history_screen.dart`
- [ ] **6.** Nda `lib/screens/audit_log_screen.dart`

### Faza 3 — Modelet

- [ ] **7.** Nxjerr modelet nga `lib/manager/manager_data.dart`
  - `WaiterInfo`, `AdvanceRow`, `TableInfo`, `ExpenseRow` etj. → `lib/models/`

### Faza 4 — Ekranet e tjera

- [ ] **8.** Nda `lib/screens/pos_order_screen.dart`

### Faza 5 (opsionale)

- [ ] **9.** Nda `lib/services/database_service.dart`

---

## Shënime teknike

- Import path nga `lib/features/dashboard/panels/` → `'../../../'` për lib root
- Import path nga `lib/features/dashboard/widgets/` → `'../../../'` për lib root
- `sectionTitle()` dhe `inputDeco()` → `lib/shared/widgets/dashboard_helpers.dart`
- `StatCard` → `lib/features/dashboard/widgets/stat_card.dart`
- Pas çdo nxjerrjeje: `flutter analyze --no-pub` duhet të kthejë **0 errors**
