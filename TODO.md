# POS Company Settings Implementation TODO

Current step: ✅ 1/8

## Completed:
## 1. [✅] Add dependency (pubspec.yaml)
- Added shared_preferences: ^2.3.2

## Completed:
## 1. [✅] Add dependency (pubspec.yaml)
- Added shared_preferences: ^2.3.2

## 2. [✅] Update ManagerData (lib/manager/manager_data.dart)
- Import shared_preferences  
- Add String? companyName
- Load in constructor (await SharedPreferences.getInstance())
- saveCompanyName(String) → set, prefs.setString, notifyListeners()

## Pending:
## 3. [ ] Add Company Settings section (lib/screens/manager_dashboard_screen.dart)
- Import shared_preferences  
- Add String? companyName
- Load in constructor (await SharedPreferences.getInstance())
- saveCompanyName(String) → set, prefs.setString, notifyListeners()

## 3. [ ] Add Company Settings section (lib/screens/manager_dashboard_screen.dart)
- Extend _kSectionTitles (add 'Company Settings')
- Add to _items (icon: Icons.settings)
- case 9: _CompanySettingsPanel(m: _m)

## 4. [ ] Update login_screen.dart header
- Use ManagerData.instance.companyName ?? 'POS System'

## 5. [ ] Update table_selection_screen.dart GgAppHeader
- title: _m.companyName ?? 'POS System'

## 6. [ ] Update pos_order_screen.dart (uses gg_header)
- title: ManagerData.instance.companyName ?? 'POS System'

## 7. [ ] Run `flutter pub get`
## 8. [ ] Test: Save → reactive updates everywhere

