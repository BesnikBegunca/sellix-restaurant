import 'package:flutter/material.dart';
import '../manager/manager_data.dart';
import '../screens/audit_log_screen.dart';
import '../screens/sales_history_screen.dart';
import '../theme/app_colors.dart';
import '../features/dashboard/panels/shift_panel.dart';
import '../features/dashboard/panels/waiters_panel.dart';
import '../features/dashboard/panels/expenses_panel.dart';
import '../features/dashboard/panels/profits_panel.dart';
import '../features/dashboard/panels/reports_panel.dart';
import '../features/dashboard/panels/top_employee_panel.dart';
import '../features/dashboard/panels/menu_panel.dart';
import '../features/dashboard/panels/tables_config_panel.dart';
import '../features/dashboard/panels/staff_payroll_panel.dart';
import '../features/dashboard/panels/overview_panel.dart';
import '../features/dashboard/panels/company_settings_panel.dart';
import '../features/dashboard/panels/refund_panel.dart';
import '../features/dashboard/panels/license_panel.dart';
import '../features/dashboard/widgets/manager_side_nav.dart';
import '../features/dashboard/widgets/manager_top_bar.dart';


const _kSectionTitles = <String>[
  'Overview',
  'Shift',
  'Staff',
  'Expenses',
  'Profits',
  'Reports',
  'Leaderboard',
  'Menu',
  'Tavolinat',
  'Cilësimet e Kompanisë',
  'Pagat & Avans',
  'Refund — Porositë e Printuara',
  'Historiku i Shitjeve',
  'Regjistri i Auditit',
  'Licenca',
];

const _kDevSectionTitles = <String>['Licenca'];

/// Dashboard menaxheri (PIN 9999). Seksionet 1–8 sipas kërkesës.
class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({
    super.key,
    this.devModeOnly = false,
    this.initialIndex = 0,
  });

  /// Vetëm paneli i licencës (pas hyrjes Dev Mode kur licenca ka skaduar).
  final bool devModeOnly;
  final int initialIndex;

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final ManagerData _m = ManagerData.instance;
  final TextEditingController _headerSearchController = TextEditingController();
  late int _railIndex;
  bool _sidebarExpanded = true;

  List<String> get _sectionTitles =>
      widget.devModeOnly ? _kDevSectionTitles : _kSectionTitles;

  @override
  void initState() {
    super.initState();
    _railIndex = widget.initialIndex;
    _m.addListener(_onData);
  }

  void _onData() => setState(() {});

  @override
  void dispose() {
    _headerSearchController.dispose();
    _m.removeListener(_onData);
    super.dispose();
  }

  void _exitToLogin() {
    if (_m.devModeSession) {
      _m.endDevModeSession();
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Row(
        children: [
          ClipRect(
            child: ManagerSideNav(
              expanded: _sidebarExpanded,
              selectedIndex: _railIndex,
              devModeOnly: widget.devModeOnly,
              onToggle: () =>
                  setState(() => _sidebarExpanded = !_sidebarExpanded),
              onDestinationSelected: (i) => setState(() => _railIndex = i),
              onLogout: _exitToLogin,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ManagerTopBar(
                  sectionTitle: _sectionTitles[_railIndex],
                  m: _m,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: _buildSection(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    if (widget.devModeOnly) {
      return LicensePanel(
        m: _m,
        onLicenseRenewed: () {
          if (mounted) setState(() {});
        },
      );
    }
    switch (_railIndex) {
      case 0:
        return OverviewPanel(
          m: _m,
          onNavigate: (i) => setState(() => _railIndex = i),
        );
      case 1:
        return ShiftPanel(m: _m);
      case 2:
        return WaitersPanel(m: _m);
      case 3:
        return ExpensesPanel(m: _m);
      case 4:
        return ProfitsPanel(m: _m);
      case 5:
        return ReportsPanel(m: _m);
      case 6:
        return TopEmployeePanel(m: _m);
      case 7:
        return MenuPanel(m: _m);
      case 8:
        return TablesConfigPanel(m: _m);
      case 9:
        return CompanySettingsPanel(m: _m);
      case 10:
        return StaffPayrollPanel(m: _m);
      case 11:
        return RefundPanel(m: _m);
      case 12:
        return const SalesHistoryPanel();
      case 13:
        return const AuditLogPanel();
      case 14:
        return LicensePanel(m: _m);
      default:
        return const SizedBox.shrink();
    }
  }
}

