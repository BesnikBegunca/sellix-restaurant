import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../manager/manager_data.dart';
import '../screens/audit_log_screen.dart';
import '../screens/sales_history_screen.dart';
import '../services/expenses_pdf_export.dart';
import '../services/manager_summary_pdf.dart';
import '../services/printer_settings_store.dart';
import '../services/receipt_printer.dart';
import '../services/windows_printers_service.dart';
import '../models/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/image_utils.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/gg_header.dart';

/// Të dhënat që barten me drag nga një produkt.
typedef _ProductDrag = ({String fromCatId, ProductItem product});

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
  'Historiku i Shitjeve',
  'Regjistri i Auditit',
];

/// Dashboard menaxheri (PIN 9999). Seksionet 1–8 sipas kërkesës.
class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final ManagerData _m = ManagerData.instance;
  final TextEditingController _headerSearchController = TextEditingController();
  int _railIndex = 0;
  bool _sidebarExpanded = true;

  @override
  void initState() {
    super.initState();
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
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Row(
        children: [
          ClipRect(
            child: _ManagerSideNav(
              expanded: _sidebarExpanded,
              selectedIndex: _railIndex,
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
                _ManagerTopBar(
                  sectionTitle: _kSectionTitles[_railIndex],
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
    switch (_railIndex) {
      case 0:
        return _OverviewPanel(
          m: _m,
          onNavigate: (i) => setState(() => _railIndex = i),
        );
      case 1:
        return _ShiftPanel(m: _m);
      case 2:
        return _WaitersPanel(m: _m);
      case 3:
        return _ExpensesPanel(m: _m);
      case 4:
        return _ProfitsPanel(m: _m);
      case 5:
        return _ReportsPanel(m: _m);
      case 6:
        return _TopEmployeePanel(m: _m);
      case 7:
        return _MenuPanel(m: _m);
      case 8:
        return _TablesConfigPanel(m: _m);
      case 9:
        return _CompanySettingsPanel(m: _m);
      case 10:
        return _StaffPayrollPanel(m: _m);
      case 11:
        return const SalesHistoryPanel();
      case 12:
        return const AuditLogPanel();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _CompanySettingsPanel extends StatefulWidget {
  const _CompanySettingsPanel({required this.m});

  final ManagerData m;

  @override
  State<_CompanySettingsPanel> createState() => _CompanySettingsPanelState();
}

class _CompanySettingsPanelState extends State<_CompanySettingsPanel> {
  final _nameCtrl = TextEditingController();
  String? _errorMsg;
  late String _selectedLoginMode;
  List<String> _printers = const [];
  String _selectedPrinter = '';
  bool _loadingPrinters = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.m.companyName ?? '';
    _selectedLoginMode = widget.m.loginMode;
    widget.m.addListener(_onM);
    _loadPrinters();
  }

  void _onM() => setState(() {
    _selectedLoginMode = widget.m.loginMode;
  });

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMsg = 'Emri i kompanisë është i detyrueshëm.');
      return;
    }
    await widget.m.saveCompanyName(name);
    setState(() => _errorMsg = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cilësimet e kompanisë u ruajtën.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null || bytes.isEmpty) return;
    await widget.m.saveCompanyLogo(bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo e kompanisë u ruajt.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  Future<void> _clearLogo() async {
    await widget.m.clearCompanyLogo();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo e kompanisë u fshi.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  Future<void> _changeLoginMode(String newMode) async {
    await widget.m.setLoginMode(newMode);
    setState(() => _selectedLoginMode = newMode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mënyra e hyrjes u ndryshua në ${newMode == 'PINMODE' ? 'PIN' : 'Emër'}'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadPrinters() async {
    setState(() => _loadingPrinters = true);
    final selected = await PrinterSettingsStore.loadSelectedPrinterName();
    final printers = await WindowsPrintersService.listInstalledPrinters();
    if (!mounted) return;
    setState(() {
      _printers = printers;
      _selectedPrinter = selected;
      _loadingPrinters = false;
    });
  }

  Future<void> _savePrinter(String printerName) async {
    await PrinterSettingsStore.saveSelectedPrinterName(printerName);
    if (!mounted) return;
    setState(() => _selectedPrinter = printerName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Printeri u zgjodh: $printerName'),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── page header ───────────────────────────────────────────────────
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cilësimet e Kompanisë',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.darkGreenText,
                height: 1.1,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Menaxho informacionin e biznesit dhe preferencat',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.lightGreenText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Business Information card ──────────────────────────────────────
        _buildSettingsCard(
          icon: Icons.grid_view_rounded,
          title: 'Informacioni i Biznesit',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Emri i Biznesit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGreenText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: _inputDeco('Shkruaj emrin e biznesit'),
                style: const TextStyle(fontSize: 15),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 20),
              // Logo row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightGreenBorder),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: widget.m.companyLogoBytes != null
                        ? Image.memory(
                            widget.m.companyLogoBytes!,
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.business,
                            color: AppColors.mediumGreenText,
                            size: 28,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.m.companyLogoBytes != null
                              ? 'Logo e Kompanisë'
                              : 'Nuk ka logo',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'PNG, JPG or JPEG. Recommended 512×512 px.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.lightGreenText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickLogo,
                              icon: const Icon(
                                Icons.upload_outlined,
                                size: 15,
                              ),
                              label: Text(
                                widget.m.companyLogoBytes != null
                                    ? 'Ndrysho logon'
                                    : 'Ngarko logon',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                                side: const BorderSide(
                                  color: AppColors.primaryGreen,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (widget.m.companyLogoBytes != null) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: _clearLogo,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 15,
                                ),
                                label: const Text('Hiq'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.negativeText,
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.negativeText.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.negativeText.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.negativeText,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: const TextStyle(
                            color: AppColors.negativeText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Login Mode card ────────────────────────────────────────────────
        _buildSettingsCard(
          icon: Icons.security_outlined,
          title: 'Mënyra e Hyrjes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select how staff log into the system:',
                style: TextStyle(fontSize: 13, color: AppColors.lightGreenText),
              ),
              const SizedBox(height: 14),
              _buildLoginModeTile(
                mode: 'PINMODE',
                title: 'Mënyra PIN',
                subtitle: 'Waiters enter their 4–6 digit PIN',
              ),
              const SizedBox(height: 8),
              _buildLoginModeTile(
                mode: 'NAMEMODE',
                title: 'Mënyra me Emër',
                subtitle: 'Kamarierët zgjedhin emrin nga lista',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Printer Settings card ──────────────────────────────────────────
        _buildSettingsCard(
          icon: Icons.print_outlined,
          title: 'Cilësimet e Printerit',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Printer i Faturave',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mediumGreenText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_loadingPrinters)
                            const SizedBox(
                              height: 48,
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                            )
                          else if (_printers.isEmpty)
                            const Text(
                              'No printers found.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.lightGreenText,
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: _printers.contains(_selectedPrinter)
                                  ? _selectedPrinter
                                  : null,
                              decoration: _inputDeco('Zgjidh printerin'),
                              isExpanded: true,
                              items: _printers
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(
                                        p,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) _savePrinter(v);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildCheckTile(label: 'Printo automatikisht faturat pas pagesës'),
              const SizedBox(height: 8),
              _buildCheckTile(label: 'Dërgo porositë automatikisht te printeri i kuzhinës'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loadPrinters,
                  icon: const Icon(Icons.refresh_outlined, size: 16),
                  label: const Text('Rifresko Printerët'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── bottom action buttons ─────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Ruaj Ndryshimet'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                _nameCtrl.text = widget.m.companyName ?? '';
                setState(() => _errorMsg = null);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkGreenText,
                side: const BorderSide(color: AppColors.lightGreenBorder),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('Anulo'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreenText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildLoginModeTile({
    required String mode,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedLoginMode == mode;
    return GestureDetector(
      onTap: () => _changeLoginMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lightGreenBg
              : const Color(0xFFF7FAF7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primaryGreen.withValues(alpha: 0.35)
                : AppColors.lightGreenBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryGreen : AppColors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selected
                      ? AppColors.primaryGreen
                      : AppColors.lightGreenBorder,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.primaryGreen
                      : AppColors.darkGreenText,
                ),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mediumGreenText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckTile({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: true,
              onChanged: (_) {},
              activeColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.lightGreenBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.darkGreenText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerSideNav extends StatelessWidget {
  const _ManagerSideNav({
    required this.expanded,
    required this.selectedIndex,
    required this.onToggle,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final bool expanded;
  final int selectedIndex;
  final VoidCallback onToggle;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

  static const _items = <({IconData icon, IconData sel, String label})>[
    (icon: Icons.dashboard_outlined, sel: Icons.dashboard,      label: 'Përmbledhje'),
    (icon: Icons.schedule_outlined,  sel: Icons.schedule,       label: 'Gjendja'),
    (icon: Icons.badge_outlined,     sel: Icons.badge,          label: 'Kamarierët'),
    (icon: Icons.table_rows_outlined,sel: Icons.table_rows,     label: 'Shpenzime'),
    (icon: Icons.trending_up_outlined,sel: Icons.trending_up,   label: 'Fitime'),
    (icon: Icons.description_outlined,sel: Icons.description,   label: 'Raporte'),
    (icon: Icons.emoji_events_outlined,sel: Icons.emoji_events, label: 'Top puntor'),
    (icon: Icons.menu_book_outlined, sel: Icons.menu_book,      label: 'Menu'),
    (icon: Icons.grid_view_outlined, sel: Icons.grid_view,      label: 'Tavolinat'),
    (icon: Icons.settings_outlined,  sel: Icons.settings,       label: 'Cilësimet'),
    (icon: Icons.payments_outlined,  sel: Icons.payments,       label: 'Pagat'),
    (icon: Icons.history_outlined,   sel: Icons.history,        label: 'Historiku'),
    (icon: Icons.security_outlined,  sel: Icons.security,       label: 'Audit'),
  ];

  @override
  Widget build(BuildContext context) {
    final m = ManagerData.instance;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: expanded ? 256 : 80,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          right: BorderSide(color: AppColors.lightGreenBorder),
        ),
      ),
      child: ClipRect(
      child: Column(
        children: [
          // ── Brand / toggle bar ────────────────────────────────────────────
          SizedBox(
            height: 80,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (expanded) ...[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.restaurant,
                        color: AppColors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Menaxher POS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreenText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: expanded ? 'Mbyll' : 'Hap',
                    onPressed: onToggle,
                    icon: Icon(
                      expanded
                          ? Icons.keyboard_double_arrow_left
                          : Icons.menu,
                      size: 20,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1, color: AppColors.lightGreenBorder),

          // ── Nav items ─────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final it = _items[i];
                final sel = i == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _SideNavItem(
                    icon: sel ? it.sel : it.icon,
                    label: it.label,
                    selected: sel,
                    expanded: expanded,
                    onTap: () => onDestinationSelected(i),
                  ),
                );
              },
            ),
          ),

          // ── Logout ────────────────────────────────────────────────────────
          const Divider(height: 1, thickness: 1, color: AppColors.lightGreenBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            child: expanded
                ? SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Dil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.mediumGreenText,
                        side: const BorderSide(color: AppColors.lightGreenBorder),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : Tooltip(
                    message: 'Dil',
                    child: InkWell(
                      onTap: onLogout,
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: Icon(
                          Icons.logout,
                          size: 20,
                          color: AppColors.mediumGreenText,
                        ),
                      ),
                    ),
                  ),
          ),
          ],
      ),
      ), // ClipRect
    );
  }
}

/// Single sidebar navigation item with premium active-state indicator bar.
class _SideNavItem extends StatefulWidget {
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final showBg = active || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: showBg ? AppColors.lightGreenBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // ── Left indicator bar (active only) ──────────────────────────
              if (active)
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

              // ── Row content ───────────────────────────────────────────────
              Row(
                children: [
                  SizedBox(
                    width: widget.expanded ? 44 : 56,
                    child: Center(
                      child: Icon(
                        widget.icon,
                        size: 20,
                        color: active
                            ? AppColors.primaryGreen
                            : AppColors.mediumGreenText,
                      ),
                    ),
                  ),
                  if (widget.expanded)
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w500,
                          color: active
                              ? AppColors.primaryGreen
                              : AppColors.mediumGreenText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerTopBar extends StatefulWidget {
  const _ManagerTopBar({required this.sectionTitle, required this.m});

  final String sectionTitle;
  final ManagerData m;

  @override
  State<_ManagerTopBar> createState() => _ManagerTopBarState();
}

class _ManagerTopBarState extends State<_ManagerTopBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.lightGreenBorder),
        ),
      ),
      child: Row(
        children: [
          // ── Page title ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.sectionTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGreenText,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Manager Dashboard · POS System',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.lightGreenText,
                  ),
                ),
              ],
            ),
          ),

          // ── Right chips ─────────────────────────────────────────────────
          _ShiftStatusChip(open: widget.m.shiftOpen),
          const SizedBox(width: 12),
          _TopBarChip(
            icon: Icons.schedule_outlined,
            label: timeStr,
            sublabel: dateStr,
          ),
          const SizedBox(width: 12),
          _TopBarManagerBadge(),
        ],
      ),
    );
  }
}

class _ShiftStatusChip extends StatelessWidget {
  const _ShiftStatusChip({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: open
            ? AppColors.primaryGreen.withValues(alpha: 0.08)
            : AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: open
              ? AppColors.primaryGreen.withValues(alpha: 0.25)
              : AppColors.lightGreenBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: open ? AppColors.primaryGreen : AppColors.lightGreenText,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            open ? 'Gjendja e hapur' : 'Gjendja e mbyllur',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: open ? AppColors.primaryGreen : AppColors.lightGreenText,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarChip extends StatelessWidget {
  const _TopBarChip({
    required this.icon,
    required this.label,
    this.sublabel,
  });

  final IconData icon;
  final String label;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightGreenBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.mediumGreenText),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                  height: 1.1,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.lightGreenText,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBarManagerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.manage_accounts, size: 16, color: AppColors.white),
          SizedBox(width: 7),
          Text(
            'MENAXHER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerBusinessPill extends StatelessWidget {
  const _ManagerBusinessPill({required this.managerData});

  final ManagerData managerData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppTokens.controlRadius),
        border: Border.all(color: AppColors.lightGreenBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 20,
            color: AppColors.mutedGray.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              managerData.companyName ?? 'Main location',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.charcoalText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerShiftPill extends StatelessWidget {
  const _ManagerShiftPill({required this.managerData});

  final ManagerData managerData;

  @override
  Widget build(BuildContext context) {
    final open = managerData.shiftOpen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.softGreenTint,
        borderRadius: BorderRadius.circular(AppTokens.controlRadius),
        border: Border.all(color: AppColors.lightGreenBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 20,
            color: AppColors.deepForestGreen,
          ),
          const SizedBox(width: 8),
          Text(
            open ? 'Shift open' : 'Shift closed',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.charcoalText,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.m, required this.onNavigate});

  final ManagerData m;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final top = m.topEmployee;
    final productCount = m.categories.fold<int>(
      0,
      (s, c) => s + c.products.length,
    );
    final categoryCount = m.categories.length;
    final occupied = m.cashierTables.where((t) => t.occupied).length;
    final totalTables = m.cashierTables.length;
    final freeTables = totalTables - occupied;
    final occPct = totalTables > 0
        ? (occupied / totalTables * 100).toStringAsFixed(0)
        : '0';
    final totalStaffSales = m.waiterSales.values.fold<double>(
      0,
      (a, b) => a + b,
    );
    final openCheck = m.cashierTables.fold<double>(
      0,
      (s, t) => s + (t.currentTotal ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Pasqyra',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreenText,
                      height: 1.15,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Real-time operational insights',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.lightGreenText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _OverviewLiveClockChip(),
          ],
        ),
        const SizedBox(height: 24),

        // ── KPI Row 1 ───────────────────────────────────────────────────────
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Gjendja e Turnit',
                  value: m.shiftOpen ? 'Hapur' : 'Mbyllur',
                  icon: Icons.schedule_outlined,
                  accentColor: m.shiftOpen
                      ? AppColors.primaryGreen
                      : AppColors.lightGreenText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Kamarierë Aktivë',
                  value: '${m.waiters.length}',
                  icon: Icons.people_outline,
                  badge: m.waiters.isNotEmpty ? '+${m.waiters.length}' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Shpenzime Sot',
                  value: '${m.totalExpenses.toStringAsFixed(0)}€',
                  icon: Icons.payments_outlined,
                  accentColor: AppColors.softRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Fitim Ditor',
                  value: '${m.profitToday.toStringAsFixed(0)}€',
                  icon: Icons.trending_up,
                  accentColor: AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Fitim Javor',
                  value: '${m.profitThisWeek.toStringAsFixed(0)}€',
                  icon: Icons.trending_up_outlined,
                  accentColor: AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Punonjësi Më i Mirë',
                  value: top.key == '—' ? '—' : top.key,
                  subtitle: top.key == '—'
                      ? null
                      : '${top.value.toStringAsFixed(0)}€',
                  icon: Icons.emoji_events_outlined,
                  accentColor: AppColors.warmGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── KPI Row 2 ───────────────────────────────────────────────────────
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Tavolina të Lira',
                  value: '$freeTables',
                  icon: Icons.table_restaurant_outlined,
                  accentColor: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Tavolina të Zëna',
                  value: '$occupied',
                  icon: Icons.event_seat_outlined,
                  accentColor: AppColors.mutedOrange,
                  badge: totalTables > 0 ? '$occPct%' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Bilanci i Hapur',
                  value: '${openCheck.toStringAsFixed(0)}€',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Kategoritë e Menusë',
                  value: '$categoryCount',
                  icon: Icons.restaurant_menu_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Produktet',
                  value: '$productCount',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Shitjet e Stafit',
                  value: '${totalStaffSales.toStringAsFixed(0)}€',
                  icon: Icons.point_of_sale_outlined,
                  accentColor: AppColors.warmGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Charts ──────────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _WeeklySalesTrendChart(m: m)),
            const SizedBox(width: 16),
            Expanded(child: _TableOccupancyChart(m: m, occupied: occupied)),
          ],
        ),
        const SizedBox(height: 20),

        // ── Bottom 3-column section ──────────────────────────────────────────
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _TopPerformerCard(m: m)),
              const SizedBox(width: 16),
              Expanded(child: _QuickActionsCard(onNavigate: onNavigate)),
              const SizedBox(width: 16),
              Expanded(child: _TodaySummaryCard(m: m)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Top Performer card ─────────────────────────────────────────────────────

class _TopPerformerCard extends StatelessWidget {
  const _TopPerformerCard({required this.m});
  final ManagerData m;

  @override
  Widget build(BuildContext context) {
    final top = m.topEmployee;
    final hasData = top.key != '—' && top.value > 0;

    // Count orders from this waiter today
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final topOrders = hasData
        ? m.salesHistory
              .where(
                (s) =>
                    s.waiterName == top.key &&
                    !s.timestamp.isBefore(todayStart) &&
                    !s.timestamp.isAfter(todayEnd),
              )
              .length
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Performuesi Kryesor',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (!hasData)
            Expanded(
              child: Center(
                child: Text(
                  'Nuk ka të dhëna ende.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.lightGreenText,
                  ),
                ),
              ),
            )
          else ...[
            // Avatar + name row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      top.key.length >= 2
                          ? top.key.split(' ').map((w) => w[0]).take(2).join()
                          : top.key[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      top.key,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const Text(
                      'Kamarier',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightGreenText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.lightGreenBorder),
            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shitje',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${top.value.toStringAsFixed(0)}€',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Porosi',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$topOrders',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Quick Actions card (3 big buttons) ────────────────────────────────────

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Veprime të Shpejta',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 16),
          _BigActionButton(
            icon: Icons.schedule_outlined,
            label: 'Mbyll Turnin',
            onTap: () => onNavigate(1),
          ),
          const SizedBox(height: 10),
          _BigActionButton(
            icon: Icons.attach_money,
            label: 'Shto Shpenzim',
            onTap: () => onNavigate(3),
          ),
          const SizedBox(height: 10),
          _BigActionButton(
            icon: Icons.bar_chart_outlined,
            label: 'Shiko Raportet',
            onTap: () => onNavigate(5),
          ),
        ],
      ),
    );
  }
}

class _BigActionButton extends StatefulWidget {
  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_BigActionButton> createState() => _BigActionButtonState();
}

class _BigActionButtonState extends State<_BigActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.lightGreenBg
                : const Color(0xFFEEF3EE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: AppColors.primaryGreen),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGreenText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Today's Summary card ──────────────────────────────────────────────────

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.m});
  final ManagerData m;

  static String _fmtHour(int h) {
    final amPm = h >= 12 ? 'PM' : 'AM';
    final display = h == 0 ? 12 : h > 12 ? h - 12 : h;
    return '$display:00 $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final todaySales = m.salesHistory
        .where(
          (s) =>
              !s.timestamp.isBefore(todayStart) &&
              !s.timestamp.isAfter(todayEnd),
        )
        .toList();

    final totalOrders = todaySales.length;
    final totalRevenue = m.revenueToday;
    final avgOrder = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    // Find peak hour
    final hourCounts = <int, int>{};
    for (final s in todaySales) {
      hourCounts[s.timestamp.hour] = (hourCounts[s.timestamp.hour] ?? 0) + 1;
    }
    final peakHour = hourCounts.isEmpty
        ? null
        : hourCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Summary",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'Porosi Gjithsej',
            value: '$totalOrders',
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Porosia Mesatare',
            value: '${avgOrder.toStringAsFixed(2)}€',
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Ora Kulmore',
            value: peakHour != null ? _fmtHour(peakHour) : '—',
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.lightGreenBorder),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Të Ardhura Gjithsej',
            value: '${totalRevenue.toStringAsFixed(2)}€',
            bold: true,
            valueColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: bold ? AppColors.darkGreenText : AppColors.lightGreenText,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.darkGreenText,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────

class _OverviewLiveClockChip extends StatefulWidget {
  @override
  State<_OverviewLiveClockChip> createState() => _OverviewLiveClockChipState();
}

class _OverviewLiveClockChipState extends State<_OverviewLiveClockChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    final t =
        '${displayHour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $amPm';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ora Aktuale',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.lightGreenText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreenText,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly Sales Trend — fl_chart BarChart ─────────────────────────────────

class _WeeklySalesTrendChart extends StatelessWidget {
  const _WeeklySalesTrendChart({required this.m});
  final ManagerData m;

  static const _dayAbbr = ['Hën', 'Mar', 'Mër', 'Enj', 'Pre', 'Sht', 'Die'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // Revenue for each of the last 7 days (oldest → newest)
    final dailyRevenue = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return m.revenueInRange(
        DateTime(day.year, day.month, day.day),
        DateTime(day.year, day.month, day.day, 23, 59, 59, 999),
      );
    });
    final maxY = dailyRevenue.fold(0.0, math.max);
    final interval = maxY > 0 ? (maxY / 4).ceilToDouble() : 1000.0;
    final chartMax = maxY > 0 ? (interval * 4) : 4000.0;

    final barGroups = List.generate(7, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: dailyRevenue[i],
            color: AppColors.primaryGreen,
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: chartMax,
              color: AppColors.lightGreenBg.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    });

    final labels = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return _dayAbbr[day.weekday - 1];
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trendi Javor i Shitjeve',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMax,
                barGroups: barGroups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.lightGreenBorder,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          labels[v.toInt()],
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.mediumGreenText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: interval,
                      getTitlesWidget: (v, _) => Text(
                        v >= 1000
                            ? '${(v / 1000).toStringAsFixed(0)}k'
                            : v.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primaryGreen,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${rod.toY.toStringAsFixed(0)}€',
                      const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Table Occupancy Today — fl_chart LineChart ─────────────────────────────

class _TableOccupancyChart extends StatelessWidget {
  const _TableOccupancyChart({required this.m, required this.occupied});
  final ManagerData m;
  final int occupied;

  @override
  Widget build(BuildContext context) {
    final total = math.max(m.cashierTables.length, 1);
    final now = DateTime.now();
    final currentHour = now.hour.clamp(8, 22);

    // Generate a plausible occupancy curve for today based on current occupied count.
    // Peak around lunch (13) and dinner (19).
    double occupancyAt(int hour) {
      const lunchPeak = 13.0;
      const dinnerPeak = 19.0;
      final lunchWeight = math.exp(-math.pow(hour - lunchPeak, 2) / 8.0);
      final dinnerWeight = math.exp(-math.pow(hour - dinnerPeak, 2) / 8.0);
      final base = math.max(lunchWeight, dinnerWeight);
      final scale = occupied > 0 ? occupied.toDouble() : total * 0.4;
      return (base * scale).clamp(0.0, total.toDouble());
    }

    // Hours from 12 to current or 21
    final endHour = math.max(currentHour, 12);
    final spots = <FlSpot>[];
    for (var h = 12; h <= endHour; h++) {
      spots.add(FlSpot((h - 12).toDouble(), occupancyAt(h)));
    }

    final maxY = (total * 1.1).ceilToDouble();
    final yInterval = total > 0 ? (total / 4).ceilToDouble() : 5.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zënia e Tavolinave Sot',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 240,
            child: spots.length < 2
                ? Center(
                    child: Text(
                      'No occupancy data yet.',
                      style: TextStyle(color: AppColors.lightGreenText),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (endHour - 12).toDouble(),
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: AppColors.primaryGreen,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.primaryGreen,
                              strokeWidth: 2,
                              strokeColor: AppColors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.06,
                            ),
                          ),
                        ),
                      ],
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: yInterval,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.lightGreenBorder,
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 2,
                            getTitlesWidget: (v, _) {
                              final h = v.toInt() + 12;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '$h:00',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.mediumGreenText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            interval: yInterval,
                            getTitlesWidget: (v, _) => Text(
                              v.toStringAsFixed(0),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.lightGreenText,
                              ),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppColors.primaryGreen,
                          tooltipRoundedRadius: 8,
                          getTooltipItems: (spots) => spots
                              .map(
                                (s) => LineTooltipItem(
                                  '${s.y.toStringAsFixed(0)} tables',
                                  const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.accentColor,
    this.badge,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? accentColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primaryGreen;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Icon + optional badge ────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Label ────────────────────────────────────────────────────────
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.lightGreenText,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // ── Value ────────────────────────────────────────────────────────
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreenText,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.mediumGreenText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShiftPanel extends StatelessWidget {
  const _ShiftPanel({required this.m});

  final ManagerData m;

  Future<void> _showPrintDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ShiftStatusReport report;
    try {
      report = await m.computeShiftStatusReport();
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Nuk u lexua gjendja: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.darkGreenText,
          ),
        );
      }
      return;
    }

    final waiterTotals = report.waiterGrandTotalsForPrint();
    final ok = await ReceiptPrinter.printShiftStatus(
      companyName: m.companyName ?? 'POS System',
      waiterTotals: waiterTotals,
      summaryPaid: report.grandPaid,
      summaryOpen: report.grandOpen,
      reportTime: report.generatedAt,
    );

    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Gjendja u dërgua në printer.'
                : 'Nuk u printua. Zgjidh printerin te Company Settings > Printers.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok
              ? AppColors.primaryGreen
              : AppColors.darkGreenText,
        ),
      );
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => _GjendjaDialog(
          m: m,
          isClose: false,
          initialReport: report,
        ),
      );
    }
  }

  void _showCloseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _GjendjaDialog(m: m, isClose: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = m.shiftOpen;
    final openedAt = m.shiftOpenedAt;
    final closedAt = m.shiftClosedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Gjendja'),
        const SizedBox(height: 6),
        const Text(
          'Hap, shtyp ose mbyll turne operative.',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 28),

        // ── Large status card ────────────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 700;
            final statusCard = Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOpen
                      ? AppColors.primaryGreen.withValues(alpha: 0.3)
                      : AppColors.lightGreenBorder,
                  width: isOpen ? 1.5 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isOpen
                          ? AppColors.primaryGreen.withValues(alpha: 0.1)
                          : AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isOpen ? Icons.play_circle_outline : Icons.stop_circle_outlined,
                      size: 32,
                      color: isOpen
                          ? AppColors.primaryGreen
                          : AppColors.lightGreenText,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? AppColors.primaryGreen.withValues(alpha: 0.12)
                                    : AppColors.lightGreenBg,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isOpen
                                          ? AppColors.primaryGreen
                                          : AppColors.lightGreenText,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isOpen ? 'E HAPUR' : 'E MBYLLUR',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isOpen
                                          ? AppColors.primaryGreen
                                          : AppColors.lightGreenText,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOpen ? 'Gjendja aktive' : 'Gjendja e mbyllur',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isOpen && openedAt != null
                              ? 'Hapur: ${_fmtDateTime(openedAt)}'
                              : closedAt != null
                                  ? 'Mbyllur: ${_fmtDateTime(closedAt)}'
                                  : 'Nuk ka informacion shift.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.lightGreenText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            final actions = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => _showPrintDialog(context),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Shtyp gjendjen'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _showCloseDialog(context),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Mbyll gjendjen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.softRed,
                    side: BorderSide(
                      color: AppColors.softRed.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: statusCard),
                  const SizedBox(width: 24),
                  SizedBox(width: 220, child: actions),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [statusCard, const SizedBox(height: 20), actions],
            );
          },
        ),

        // ── Session KPIs ────────────────────────────────────────────────
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              title: 'Shitje (sesioni)',
              value: '${m.waiterSales.values.fold(0.0, (a, b) => a + b).toStringAsFixed(0)}€',
              icon: Icons.point_of_sale_outlined,
              accentColor: AppColors.warmGold,
            ),
            _StatCard(
              title: 'Shpenzime',
              value: '${m.totalExpenses.toStringAsFixed(0)}€',
              icon: Icons.payments_outlined,
              accentColor: AppColors.softRed,
            ),
            _StatCard(
              title: 'Fitim neto',
              value: '${m.profitToday.toStringAsFixed(0)}€',
              icon: Icons.trending_up,
              accentColor: AppColors.primaryGreen,
            ),
            _StatCard(
              title: 'Staf aktiv',
              value: '${m.waiters.length}',
              icon: Icons.badge_outlined,
            ),
          ],
        ),
      ],
    );
  }

  static String _fmtDateTime(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';
    final t = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    return '$d  $t';
  }
}

/// Modal që tregon totalet sipas kamarierit (paguar + hapur).
/// Kur [isClose] është true, shton konfirmim për mbylljen përfundimtare të shift-it.
class _GjendjaDialog extends StatefulWidget {
  const _GjendjaDialog({
    required this.m,
    required this.isClose,
    this.initialReport,
  });

  final ManagerData m;
  final bool isClose;
  final ShiftStatusReport? initialReport;

  @override
  State<_GjendjaDialog> createState() => _GjendjaDialogState();
}

class _GjendjaDialogState extends State<_GjendjaDialog> {
  ShiftStatusReport? _report;
  Object? _loadError;
  bool _loading = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    if (_report == null) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    try {
      final r = await widget.m.computeShiftStatusReport();
      if (!mounted) return;
      setState(() {
        _report = r;
        _loadError = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  String _fmtTime(DateTime t) {
    final d = t.day.toString().padLeft(2, '0');
    final mo = t.month.toString().padLeft(2, '0');
    final h = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$d.$mo.${t.year} $h:$mi:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AlertDialog(
        title: Text(
          widget.isClose ? 'Mbyll gjendjen' : 'Gjendja aktuale',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const SizedBox(
          width: 280,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anulo'),
          ),
        ],
      );
    }

    if (_loadError != null) {
      return AlertDialog(
        title: const Text('Gabim'),
        content: Text('$_loadError'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mbyll'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _loadError = null;
              });
              _load();
            },
            child: const Text('Riprovo'),
          ),
        ],
      );
    }

    final report = _report!;
    final names = report.byWaiter.keys.toList()..sort();
    final grandPaid = report.grandPaid;
    final grandOpen = report.grandOpen;
    final grandTotal = report.grandTotal;
    final shiftLine = report.shiftId != null
        ? 'Shift #${report.shiftId} · aktiv'
        : 'Pa shift aktiv në DB';

    return AlertDialog(
      title: Text(
        widget.isClose ? 'Mbyll gjendjen' : 'Gjendja aktuale',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                shiftLine,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mediumGreenText,
                ),
              ),
              Text(
                'Përditësuar: ${_fmtTime(report.generatedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mediumGreenText,
                ),
              ),
              const SizedBox(height: 12),
              if (names.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Nuk ka shitje të regjistruara për shift-in dhe as porosi të hapura në tavolina.',
                    style: TextStyle(color: AppColors.mediumGreenText),
                  ),
                )
              else
                ...names.map((name) {
                  final w = report.byWaiter[name]!;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(name),
                    subtitle: Text(
                      'Paguar: ${w.paidTotal.toStringAsFixed(2)}€ · '
                      'Hapur: ${w.openTotal.toStringAsFixed(2)}€ · '
                      'Porosi: ${w.paidOrderCount} paguar, ${w.openOrderCount} hapur',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.mediumGreenText,
                      ),
                    ),
                    trailing: Text(
                      '${w.grandTotal.toStringAsFixed(2)}€',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paguar (gjithsej)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                  Text(
                    '${grandPaid.toStringAsFixed(2)}€',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hapur / pa paguar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                  Text(
                    '${grandOpen.toStringAsFixed(2)}€',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Totali',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${grandTotal.toStringAsFixed(2)}€',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (widget.isClose)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Ky është veprim përfundimtar: ruhet snapshot-i i shift-it, '
                    'mbyllen porositë e hapura në tavolina dhe nis shift i ri. '
                    'Nuk mund të kthehet mbrapsht.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.darkGreenText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _closing ? null : () => Navigator.of(context).pop(),
          child: Text(widget.isClose ? 'Anulo' : 'Mbyll'),
        ),
        if (widget.isClose)
          FilledButton(
            onPressed: (_closing || _loading)
                ? null
                : () async {
                    setState(() => _closing = true);
                    final messenger = ScaffoldMessenger.of(context);
                    final closureReport = _report!;
                    try {
                      await widget.m.closeShift();
                      if (!context.mounted) return;

                      final waiterTotals =
                          closureReport.waiterGrandTotalsForPrint();
                      final printed = await ReceiptPrinter.printShiftStatus(
                        companyName:
                            widget.m.companyName ?? 'POS System',
                        waiterTotals: waiterTotals,
                        summaryPaid: closureReport.grandPaid,
                        summaryOpen: closureReport.grandOpen,
                        reportTime: closureReport.generatedAt,
                      );

                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            printed
                                ? 'Shift-i u mbyll. Përmbledhja e të gjithë '
                                    'punonjësve u printua (si te “Shtyp gjendjen”).'
                                : 'Shift-i u mbyll, por përmbledhja nuk u printua. '
                                    'Kontrollo printerin te Company Settings > Printers.',
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: printed
                              ? AppColors.primaryGreen
                              : AppColors.darkGreenText,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Mbyllja dështoi (shift-i mbeti aktiv): $e',
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.darkGreenText,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _closing = false);
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.darkGreenText,
              foregroundColor: AppColors.white,
            ),
            child: _closing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Konfirmo mbylljen'),
          ),
      ],
    );
  }
}

class _WaitersPanel extends StatefulWidget {
  const _WaitersPanel({required this.m});

  final ManagerData m;

  @override
  State<_WaitersPanel> createState() => _WaitersPanelState();
}

class _WaitersPanelState extends State<_WaitersPanel> {
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  String? _errorMsg;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMsg = 'Shkruaj emrin e kamarierit.');
      return;
    }
    if (pin.length < 4 || !RegExp(r'^\d+$').hasMatch(pin)) {
      setState(
        () => _errorMsg =
            'PIN: minimum 4 shifra, vetëm numra (gjatësia e lirë).',
      );
      return;
    }
    if (pin == '9999') {
      setState(() => _errorMsg = 'PIN 9999 është rezervuar për menaxherin.');
      return;
    }
    if (widget.m.waiters.any((w) => w.pin == pin)) {
      setState(() => _errorMsg = 'Ky PIN ekziston tashmë.');
      return;
    }
    widget.m.addWaiter(name, pin);
    final salary = double.tryParse(
          _salaryCtrl.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
    if (salary > 0) {
      widget.m.setSalary(name, salary);
    }
    _nameCtrl.clear();
    _pinCtrl.clear();
    _salaryCtrl.clear();
    setState(() => _errorMsg = null);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Menaxhimi i Kamarierëve'),
        const SizedBox(height: 6),
        const Text(
          'Menaxho anëtarët e stafit dhe kodet e hyrjes',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        // ── Add New Waiter card ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightGreenBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shto Kamarier të Ri',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreenText,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: _inputDeco('Emri i Plotë'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _pinCtrl,
                      decoration: _inputDeco('Kodi PIN'),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _salaryCtrl,
                      decoration: _inputDeco('Rroga (€/ditë)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Shto Kamarier'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.softRed.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppColors.softRed,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _errorMsg!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.softRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Waiter grid ───────────────────────────────────────────────────
        _WaiterList(
          waiters: m.waiters,
          waiterSales: m.waiterSales,
          onRemove: (i) => m.removeWaiterAt(i),
          m: m,
        ),
      ],
    );
  }
}

class _WaiterList extends StatelessWidget {
  const _WaiterList({
    required this.waiters,
    required this.waiterSales,
    required this.onRemove,
    required this.m,
  });
  final List<dynamic> waiters;
  final Map<String, double> waiterSales;
  final void Function(int) onRemove;
  final ManagerData m;

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    if (waiters.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.lightGreenBorder),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.badge_outlined,
              size: 48,
              color: AppColors.lightGreenBorder,
            ),
            SizedBox(height: 16),
            Text(
              'Nuk ka kamarierë ende',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGreenText,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Add a waiter using the form above.',
              style: TextStyle(fontSize: 13, color: AppColors.lightGreenText),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 4.5,
      ),
      itemCount: waiters.length,
      itemBuilder: (context, i) {
        final w = waiters[i];
        final name = w.name as String;
        final pin = w.pin as String;
        final salary = m.getSalary(name);
        final initials = _initials(name);

        return _WaiterGridCard(
          initials: initials,
          name: name,
          pin: pin,
          salary: salary,
          onDelete: () => onRemove(i),
        );
      },
    );
  }
}

class _WaiterGridCard extends StatefulWidget {
  const _WaiterGridCard({
    required this.initials,
    required this.name,
    required this.pin,
    required this.salary,
    required this.onDelete,
  });
  final String initials;
  final String name;
  final String pin;
  final double salary;
  final VoidCallback onDelete;

  @override
  State<_WaiterGridCard> createState() => _WaiterGridCardState();
}

class _WaiterGridCardState extends State<_WaiterGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? AppColors.primaryGreen.withValues(alpha: 0.4)
                : AppColors.lightGreenBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? AppColors.primaryGreen.withValues(alpha: 0.06)
                  : const Color(0x08000000),
              blurRadius: _hovered ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.initials,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Name + PIN
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreenText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PIN: ${widget.pin}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
            // Salary badge
            if (widget.salary > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.salary.toStringAsFixed(0)}€/d',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Delete button (always visible but subtle, red on hover)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _hovered ? 1.0 : 0.35,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _hovered
                      ? AppColors.softRed.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: _hovered
                        ? AppColors.softRed
                        : AppColors.mediumGreenText,
                  ),
                  onPressed: widget.onDelete,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpensesPanel extends StatefulWidget {
  const _ExpensesPanel({required this.m});

  final ManagerData m;

  @override
  State<_ExpensesPanel> createState() => _ExpensesPanelState();
}

enum _ExpSort { dateDesc, dateAsc, amountDesc, amountAsc }

class _ExpensesPanelState extends State<_ExpensesPanel> {
  final _searchCtrl = TextEditingController();
  String? _typeFilter;
  _ExpSort _sort = _ExpSort.dateDesc;

  @override
  void initState() {
    super.initState();
    widget.m.addListener(_onM);
    _searchCtrl.addListener(_onM);
  }

  void _onM() => setState(() {});

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ExpenseRow> _filtered(List<ExpenseRow> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = all.where((e) {
      if (_typeFilter != null && e.type != _typeFilter) return false;
      if (q.isEmpty) return true;
      return e.description.toLowerCase().contains(q) ||
          e.type.toLowerCase().contains(q) ||
          e.amount.toString().contains(q);
    }).toList();

    switch (_sort) {
      case _ExpSort.dateDesc:
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
      case _ExpSort.dateAsc:
        list.sort((a, b) => a.date.compareTo(b.date));
        break;
      case _ExpSort.amountDesc:
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case _ExpSort.amountAsc:
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }
    return list;
  }

  int _indexInManager(ExpenseRow row) => widget.m.expenses.indexOf(row);

  Future<void> _exportPdf(
    BuildContext context, {
    required bool printDialog,
  }) async {
    final rows = _filtered(widget.m.expenses);
    if (rows.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Nuk ka rreshta për eksport — shto ose ndrysho filtrat.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.negativeText,
        ),
      );
      return;
    }
    final bytes = await buildExpensesPdfBytes(rows: rows);
    if (!context.mounted) return;
    if (printDialog) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'shpenzime_pos_system_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    }
  }

  static const _monthsEn = [
    'Jan', 'Feb', 'Mars', 'Apr', 'Maj', 'Qer',
    'Kor', 'Gus', 'Sht', 'Tet', 'Nën', 'Dhj',
  ];

  String _fmtDateLong(DateTime d) =>
      '${_monthsEn[d.month - 1]} ${d.day}, ${d.year}';

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final filtered = _filtered(m.expenses);
    final totalAll = m.expenses.fold<double>(0, (s, e) => s + e.amount);
    final types = m.expenses.map((e) => e.type).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Shpenzime'),
        const SizedBox(height: 6),
        const Text(
          'Ndjek, filtro dhe eksporto transaksionet operative.',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        // ── KPI row ──────────────────────────────────────────────────────
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Shpenzime Gjithsej',
                  value: '${totalAll.toStringAsFixed(2)}€',
                  icon: Icons.attach_money,
                  accentColor: AppColors.softRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: "Today's Expenses",
                  value: '${m.expensesToday.toStringAsFixed(2)}€',
                  icon: Icons.trending_down_outlined,
                  accentColor: AppColors.softRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Transaksione',
                  value: '${m.expenses.length}',
                  icon: Icons.receipt_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Këtë Muaj',
                  value: '${m.expensesThisMonth.toStringAsFixed(0)}€',
                  icon: Icons.calendar_month_outlined,
                  accentColor: AppColors.warmGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Main card ────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightGreenBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row
                Row(
                  children: [
                    const Text(
                      'Të gjitha transaksionet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: filtered.isEmpty
                          ? null
                          : () => _exportPdf(context, printDialog: false),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Eksporto PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGreenText,
                        side: const BorderSide(
                          color: AppColors.lightGreenBorder,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: filtered.isEmpty
                          ? null
                          : () => _exportPdf(context, printDialog: true),
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Shtyp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGreenText,
                        side: const BorderSide(
                          color: AppColors.lightGreenBorder,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _openAddDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Shto Shpenzim'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Full-width search
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.lightGreenText,
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.lightGreenBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.lightGreenBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    hintStyle: const TextStyle(
                      color: AppColors.lightGreenText,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ExpenseFilterChip(
                        label: 'Të gjitha',
                        selected: _typeFilter == null,
                        onTap: () => setState(() => _typeFilter = null),
                      ),
                      for (final t in types) ...[
                        const SizedBox(width: 8),
                        _ExpenseFilterChip(
                          label: t,
                          selected: _typeFilter == t,
                          onTap: () => setState(() => _typeFilter = t),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Table
                if (filtered.isEmpty)
                  _ExpensesEmptyState(onAdd: () => _openAddDialog(context))
                else
                  LayoutBuilder(
                    builder: (context, c) {
                      final tableWidth = math.max(640.0, c.maxWidth);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: tableWidth,
                            maxWidth: tableWidth,
                          ),
                          child: _ExpensesDataTable(
                            rows: filtered,
                            fmtDate: _fmtDateLong,
                            onDelete: (row) {
                              final i = _indexInManager(row);
                              if (i >= 0) m.removeExpenseAt(i);
                            },
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openAddDialog(BuildContext context) async {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    var selType = 'Shpenzim';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Shto shpenzim / rrogë'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InputDecorator(
                  decoration: _inputDeco('Lloji'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Shpenzim',
                          child: Text('Shpenzim'),
                        ),
                        DropdownMenuItem(value: 'Rrogë', child: Text('Rrogë')),
                        DropdownMenuItem(value: 'Bonus', child: Text('Bonus')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setSt(() => selType = v);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: _inputDeco('Përshkrimi'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  decoration: _inputDeco('Shuma (USD)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anulo'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ruaj'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true && context.mounted) {
      final a = double.tryParse(amtCtrl.text.trim()) ?? 0;
      if (a > 0 && descCtrl.text.trim().isNotEmpty) {
        widget.m.addExpense(
          ExpenseRow(
            type: selType,
            description: descCtrl.text.trim(),
            amount: a,
          ),
        );
      }
    }
    descCtrl.dispose();
    amtCtrl.dispose();
  }
}

class _ExpensesEmptyState extends StatelessWidget {
  const _ExpensesEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle(0.08)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: AppColors.lightGreenText.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Nuk ka rreshta që përputhen me filtrat',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Zbraz kërkimin, zgjidh “Të gjitha” te lloji, ose shto një transaksion të ri.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.mediumGreenText),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Shto transaksion'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseFilterChip extends StatelessWidget {
  const _ExpenseFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : AppColors.lightGreenBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.white : AppColors.darkGreenText,
          ),
        ),
      ),
    );
  }
}

class _ExpensesDataTable extends StatelessWidget {
  const _ExpensesDataTable({
    required this.rows,
    required this.fmtDate,
    required this.onDelete,
  });

  final List<ExpenseRow> rows;
  final String Function(DateTime) fmtDate;
  final void Function(ExpenseRow) onDelete;

  Color _categoryColor(String type) {
    switch (type) {
      case 'Rrogë':
        return const Color(0xFF2E7D32);
      case 'Bonus':
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF6A1B9A);
    }
  }

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.lightGreenText,
      letterSpacing: 0.6,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(color: AppColors.lightGreenBg),
            child: const Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text('DATA', style: headerStyle),
                ),
                SizedBox(
                  width: 130,
                  child: Text('KATEGORIA', style: headerStyle),
                ),
                Expanded(
                  child: Text('PËRSHKRIMI', style: headerStyle),
                ),
                SizedBox(
                  width: 140,
                  child: Text('MËNYRA E PAGESËS', style: headerStyle),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'SHUMA',
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                SizedBox(width: 52),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.lightGreenBorder,
            ),
            itemBuilder: (context, i) {
              final e = rows[i];
              final catColor = _categoryColor(e.type);
              return Material(
                color: AppColors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          fmtDate(e.date),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mediumGreenText,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 130,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: catColor.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Text(
                            e.type,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: catColor,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            e.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.darkGreenText,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: Text(
                          '—',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mediumGreenText,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          '${e.amount.toStringAsFixed(2)}€',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.negativeText,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        child: IconButton(
                          tooltip: 'Fshi rreshtin',
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.negativeText.withValues(alpha: 0.7),
                          ),
                          onPressed: () => onDelete(e),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfitsPanel extends StatefulWidget {
  const _ProfitsPanel({required this.m});
  final ManagerData m;

  @override
  State<_ProfitsPanel> createState() => _ProfitsPanelState();
}

class _ProfitsPanelState extends State<_ProfitsPanel> {
  int _tab = 1; // 0=Daily, 1=Weekly, 2=Monthly

  @override
  void initState() {
    super.initState();
    widget.m.addListener(_onM);
  }

  void _onM() => setState(() {});

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    super.dispose();
  }

  List<FlSpot> _buildSpots(ManagerData m) {
    final today = DateTime.now();
    switch (_tab) {
      case 0: // Daily — hourly today
        return List.generate(12, (i) {
          final h = (today.hour - 11 + i).clamp(0, 23);
          final from = DateTime(today.year, today.month, today.day, h);
          final to = DateTime(today.year, today.month, today.day, h, 59, 59);
          final p = m.revenueInRange(from, to) - m.expensesInRange(from, to);
          return FlSpot(i.toDouble(), p);
        });
      case 2: // Monthly — last 30 days
        return List.generate(30, (i) {
          final day = today.subtract(Duration(days: 29 - i));
          final from = DateTime(day.year, day.month, day.day);
          final to = DateTime(day.year, day.month, day.day, 23, 59, 59);
          final p = m.revenueInRange(from, to) - m.expensesInRange(from, to);
          return FlSpot(i.toDouble(), p);
        });
      default: // Weekly — last 7 days
        return List.generate(7, (i) {
          final day = today.subtract(Duration(days: 6 - i));
          final from = DateTime(day.year, day.month, day.day);
          final to = DateTime(day.year, day.month, day.day, 23, 59, 59);
          final p = m.revenueInRange(from, to) - m.expensesInRange(from, to);
          return FlSpot(i.toDouble(), p);
        });
    }
  }

  String _xLabel(int i) {
    final today = DateTime.now();
    const dayAbbr = ['Hën', 'Mar', 'Mër', 'Enj', 'Pre', 'Sht', 'Die'];
    switch (_tab) {
      case 0:
        final h = (today.hour - 11 + i).clamp(0, 23);
        return '$h:00';
      case 2:
        final day = today.subtract(Duration(days: 29 - i));
        return '${day.day}';
      default:
        final day = today.subtract(Duration(days: 6 - i));
        return dayAbbr[day.weekday - 1];
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;

    final profDay = m.profitToday;
    final profWeek = m.profitThisWeek;
    final profMonth = m.profitThisMonth;
    final totalSales = m.revenueThisMonth;

    final selRevenues = [m.revenueToday, m.revenueThisWeek, m.revenueThisMonth];
    final selExpenses = [m.expensesToday, m.expensesThisWeek, m.expensesThisMonth];
    final selProfits = [profDay, profWeek, profMonth];
    final selRev = selRevenues[_tab];
    final selExp = selExpenses[_tab];
    final selProfit = selProfits[_tab];

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final avgDaily = _tab == 0
        ? profDay
        : _tab == 1
            ? profWeek / 7
            : profMonth / daysInMonth;
    final margin = selRev > 0 ? (selProfit / selRev * 100) : 0.0;

    final spots = _buildSpots(m);
    final yValues = spots.map((s) => s.y).toList();
    final maxY = yValues.isEmpty ? 0.0 : yValues.reduce(math.max);
    final minY = yValues.isEmpty ? 0.0 : yValues.reduce(math.min);
    final chartMaxY = math.max(maxY * 1.15, 100.0);
    final chartMinY = math.min(minY * 1.1, 0.0);
    final yInterval = math.max((chartMaxY - chartMinY) / 4, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Fitime'),
        const SizedBox(height: 6),
        const Text(
          'Fitimi neto = shitje – shpenzime, sipas periudhës.',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        // ── KPI row ──────────────────────────────────────────────────────
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Fitim Ditor',
                  value: '${profDay.toStringAsFixed(0)}€',
                  icon: Icons.attach_money,
                  accentColor: AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Fitim Javor',
                  value: '${profWeek.toStringAsFixed(0)}€',
                  icon: Icons.trending_up_outlined,
                  accentColor: AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Fitim Mujor',
                  value: '${profMonth.toStringAsFixed(0)}€',
                  icon: Icons.calendar_month_outlined,
                  accentColor: AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Shitje Gjithsej',
                  value: '${totalSales.toStringAsFixed(0)}€',
                  icon: Icons.bar_chart_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Main card ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightGreenBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: line chart ────────────────────────────────────────
              Expanded(
                flex: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Trendi i Fitimit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        const Spacer(),
                        // Tab toggle
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              for (final entry in [
                                (0, 'Ditore'),
                                (1, 'Javore'),
                                (2, 'Mujore'),
                              ])
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _tab = entry.$1),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _tab == entry.$1
                                          ? AppColors.primaryGreen
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      entry.$2,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _tab == entry.$1
                                            ? AppColors.white
                                            : AppColors.mediumGreenText,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 320,
                      child: LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: (spots.length - 1).toDouble(),
                          minY: chartMinY,
                          maxY: chartMaxY,
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              curveSmoothness: 0.3,
                              color: AppColors.primaryGreen,
                              barWidth: 2.5,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (_, __, ___, ____) =>
                                    FlDotCirclePainter(
                                  radius: 4,
                                  color: AppColors.primaryGreen,
                                  strokeWidth: 2,
                                  strokeColor: AppColors.white,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.05,
                                ),
                              ),
                            ),
                          ],
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: yInterval,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: AppColors.lightGreenBorder,
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ),
                          ),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: _tab == 2 ? 5 : 1,
                                getTitlesWidget: (v, _) => Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _xLabel(v.toInt()),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.mediumGreenText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 52,
                                interval: yInterval,
                                getTitlesWidget: (v, _) => Text(
                                  v >= 1000
                                      ? '${(v / 1000).toStringAsFixed(0)}k'
                                      : v.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.lightGreenText,
                                  ),
                                ),
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => AppColors.primaryGreen,
                              tooltipRoundedRadius: 8,
                              getTooltipItems: (spots) => spots
                                  .map(
                                    (s) => LineTooltipItem(
                                      '${s.y.toStringAsFixed(0)}€',
                                      const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // ── Right: stat cards ────────────────────────────────────────
              SizedBox(
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Average Daily
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreenBg.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mesatare Ditore',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mediumGreenText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${avgDaily.toStringAsFixed(0)}€',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Breakdown
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.lightGreenBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ndarja',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ProfitBreakdownRow(
                            label: 'Të Ardhura',
                            value: '${selRev.toStringAsFixed(0)}€',
                          ),
                          const SizedBox(height: 10),
                          _ProfitBreakdownRow(
                            label: 'Kosto',
                            value: selExp > 0
                                ? '-${selExp.toStringAsFixed(0)}€'
                                : '0€',
                            valueColor: selExp > 0
                                ? AppColors.softRed
                                : AppColors.darkGreenText,
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.lightGreenBg.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _ProfitBreakdownRow(
                              label: 'Fitim Neto',
                              value: '${selProfit.toStringAsFixed(0)}€',
                              valueColor: AppColors.primaryGreen,
                              bold: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Margin
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreenBg.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Marzhi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${margin.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGreen,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                selRev > 0 ? '+${margin.toStringAsFixed(1)}%' : '—',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfitBreakdownRow extends StatelessWidget {
  const _ProfitBreakdownRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: bold ? AppColors.darkGreenText : AppColors.lightGreenText,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.darkGreenText,
          ),
        ),
      ],
    );
  }
}

class _ReportsPanel extends StatefulWidget {
  const _ReportsPanel({required this.m});

  final ManagerData m;

  @override
  State<_ReportsPanel> createState() => _ReportsPanelState();
}

class _ReportsPanelState extends State<_ReportsPanel> {
  @override
  void initState() {
    super.initState();
    widget.m.addListener(_onM);
  }

  void _onM() => setState(() {});

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    super.dispose();
  }

  Future<void> _pdf({required bool printOnly}) async {
    final bytes = await buildManagerSummaryPdfBytes(widget.m);
    if (!mounted) return;
    if (printOnly) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'raport_pos_system_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    }
  }

  String _buildExpensesCsv() {
    final b = StringBuffer();
    b.writeln('Lloji,Përshkrimi,Shuma,Data');
    for (final e in widget.m.expenses) {
      final desc = e.description.replaceAll('"', '""').replaceAll('\n', ' ');
      b.writeln(
        '"${e.type}","$desc",${e.amount.toStringAsFixed(2)},${e.date.toIso8601String()}',
      );
    }
    return b.toString();
  }

  Future<void> _exportCsv(BuildContext context) async {
    final csv = _buildExpensesCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV u kopjua në clipboard'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _expensesPdf(
    BuildContext context, {
    required bool printOnly,
  }) async {
    final rows = widget.m.expenses;
    if (rows.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nuk ka shpenzime për eksport.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.negativeText,
        ),
      );
      return;
    }
    final bytes = await buildExpensesPdfBytes(rows: rows);
    if (!context.mounted) return;
    if (printOnly) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'expenses_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    }
  }

  static const _rMonths = [
    'Jan', 'Feb', 'Mars', 'Apr', 'Maj', 'Qer',
    'Kor', 'Gus', 'Sht', 'Tet', 'Nën', 'Dhj',
  ];

  String _fmtDay(DateTime d) => '${_rMonths[d.month - 1]} ${d.day}, ${d.year}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekNum = ((now.difference(DateTime(now.year, 1, 1)).inDays +
                DateTime(now.year, 1, 1).weekday - 1) /
            7)
        .ceil();
    final yesterday = now.subtract(const Duration(days: 1));

    final recentItems = <({String title, String subtitle, VoidCallback onDownload, VoidCallback onPrint})>[
      (
        title: 'Raporti Ditor - ${_fmtDay(now)}',
        subtitle: 'Sot · ~245 KB',
        onDownload: () => _pdf(printOnly: false),
        onPrint: () => _pdf(printOnly: true),
      ),
      (
        title: 'Përmbledhja Javore - Java $weekNum',
        subtitle: '${_fmtDay(yesterday)} · ~890 KB',
        onDownload: () => _pdf(printOnly: false),
        onPrint: () => _pdf(printOnly: true),
      ),
      (
        title: 'Përmbledhje Shpenzimesh',
        subtitle: '${_fmtDay(now)} · ~120 KB',
        onDownload: () => _expensesPdf(context, printOnly: false),
        onPrint: () => _expensesPdf(context, printOnly: true),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Raporte'),
        const SizedBox(height: 6),
        const Text(
          'Gjenero dhe eksporto raporte biznesi',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        // Row 1: Daily Sales + Staff Performance
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ReportCard(
                  icon: Icons.attach_money_outlined,
                  title: 'Raporti i Shitjeve Ditore',
                  subtitle: "Complete breakdown of today's sales",
                  onExport: () => _pdf(printOnly: false),
                  onPrint: () => _pdf(printOnly: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ReportCard(
                  icon: Icons.people_outline,
                  title: 'Performanca e Stafit',
                  subtitle: 'Shitjet dhe statistikat individuale të kamarierëve',
                  onExport: () => _pdf(printOnly: false),
                  onPrint: () => _pdf(printOnly: true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Row 2: Expense Summary + Inventory Report
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ReportCard(
                  icon: Icons.description_outlined,
                  title: 'Përmbledhje Shpenzimesh',
                  subtitle: 'Të gjitha shpenzimet të kategorizuara dhe totalizuara',
                  onExport: () => _expensesPdf(context, printOnly: false),
                  onPrint: () => _expensesPdf(context, printOnly: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ReportCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Raporti i Inventarit',
                  subtitle: 'Nivelet aktuale të stokut dhe përdorimi',
                  onExport: () => _exportCsv(context),
                  onPrint: () => _pdf(printOnly: true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Recent Reports card
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightGreenBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Raportet e Fundit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreenText,
                  ),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < recentItems.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.lightGreenBorder,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recentItems[i].title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkGreenText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                recentItems[i].subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mediumGreenText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Shkarko',
                          icon: const Icon(
                            Icons.download_outlined,
                            size: 20,
                            color: AppColors.mediumGreenText,
                          ),
                          onPressed: recentItems[i].onDownload,
                        ),
                        IconButton(
                          tooltip: 'Shtyp',
                          icon: const Icon(
                            Icons.print_outlined,
                            size: 20,
                            color: AppColors.mediumGreenText,
                          ),
                          onPressed: recentItems[i].onPrint,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onExport,
    required this.onPrint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onExport;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mediumGreenText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Eksporto PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text('Shtyp'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkGreenText,
                  side: const BorderSide(color: AppColors.lightGreenBorder),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopEmployeePanel extends StatelessWidget {
  const _TopEmployeePanel({required this.m});

  final ManagerData m;

  @override
  Widget build(BuildContext context) {
    final sorted = m.employeeSalesSorted;

    if (sorted.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Realizimi sipas punëtorëve'),
          const SizedBox(height: 8),
          const Text(
            'Statistikat e shitjeve sipas punonjësve',
            style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
          ),
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.lightGreenBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    size: 36,
                    color: AppColors.lightGreenText,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Asnjë shitje e regjistruar ende.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.mediumGreenText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Shitjet do të shfaqen këtu pasi të regjistroni shitjet e para.',
                  style: TextStyle(fontSize: 13, color: AppColors.lightGreenText),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final top = sorted.first;
    final maxSales = top.value > 0 ? top.value : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Realizimi sipas punëtorëve'),
        const SizedBox(height: 4),
        const Text(
          'Statistikat e shitjeve sipas punonjësve',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        // ── Trophy hero card ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.warmGold.withValues(alpha: 0.12),
                AppColors.warmGold.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.warmGold.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.warmGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 34,
                  color: AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Punëtori më i mirë',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightGreenText,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      top.key,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreenText,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${top.value.toStringAsFixed(2)}€',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warmGold,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'totale',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.lightGreenText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Leaderboard ──────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightGreenBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(17),
                  ),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 36),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'PUNËTORI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.lightGreenText,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'SHITJET',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.lightGreenText,
                          letterSpacing: 0.6,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < sorted.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: AppColors.lightGreenBorder),
                _TopEmployeeRow(
                  rank: i + 1,
                  name: sorted[i].key,
                  sales: sorted[i].value,
                  maxSales: maxSales,
                  isLast: i == sorted.length - 1,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TopEmployeeRow extends StatelessWidget {
  const _TopEmployeeRow({
    required this.rank,
    required this.name,
    required this.sales,
    required this.maxSales,
    required this.isLast,
  });

  final int rank;
  final String name;
  final double sales;
  final double maxSales;
  final bool isLast;

  Color get _rankColor {
    if (rank == 1) return AppColors.warmGold;
    if (rank == 2) return const Color(0xFF9E9E9E);
    if (rank == 3) return const Color(0xFFCD7F32);
    return AppColors.lightGreenText;
  }

  @override
  Widget build(BuildContext context) {
    final progress = maxSales > 0 ? sales / maxSales : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(17))
            : BorderRadius.zero,
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _rankColor.withValues(alpha: rank <= 3 ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _rankColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar + name + progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: AppColors.lightGreenBg,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rank == 1
                          ? AppColors.warmGold
                          : AppColors.primaryGreen.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Sales value
          SizedBox(
            width: 100,
            child: Text(
              '${sales.toStringAsFixed(2)}€',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: rank == 1 ? AppColors.warmGold : AppColors.darkGreenText,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image source picker (assets OR file from PC) ────────────────────────────

/// Shows a small dialog asking whether to pick from app assets or upload from
/// the PC. Returns the chosen path, '' to clear, or null if cancelled.
Future<String?> _showImageSourcePicker(
  BuildContext context,
  String? current,
) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'Zgjidh burimin e fotos',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Nga asetat e aplikacionit'),
            subtitle: const Text('Foto të parakonfighuruara'),
            onTap: () => Navigator.pop(ctx, 'assets'),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Ngarko nga kompjuteri'),
            subtitle: const Text('PNG, JPG, WEBP…'),
            onTap: () => Navigator.pop(ctx, 'pc'),
          ),
          if (current != null && current.isNotEmpty)
            ListTile(
              leading: Icon(
                Icons.hide_image_outlined,
                color: AppColors.negativeText,
              ),
              title: Text(
                'Hiq foton',
                style: TextStyle(color: AppColors.negativeText),
              ),
              onTap: () => Navigator.pop(ctx, 'clear'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Anulo'),
        ),
      ],
    ),
  );
  if (choice == null) return null;
  if (choice == 'clear') return '';
  if (choice == 'assets') {
    if (!context.mounted) return null;
    return _showAssetPicker(context, current);
  }
  // 'pc'
  return pickAndCopyImageFromPC();
}

// ── Asset image picker (dynamic — reads AssetManifest at runtime) ──────────

const _kImageExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'};

String _assetLabel(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

Future<List<String>> _loadImageAssets() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifest.listAssets().where((a) {
    if (!a.startsWith('assets/images/')) return false;
    final lower = a.toLowerCase();
    return _kImageExtensions.any((ext) => lower.endsWith(ext));
  }).toList()..sort();
}

Future<String?> _showAssetPicker(BuildContext context, String? current) async {
  final assets = await _loadImageAssets();
  if (!context.mounted) return null;

  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zgjidh foton',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 400),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _AssetPickerThumb(
                      path: null,
                      label: 'Pa foto',
                      selected: current == null,
                      onTap: () => Navigator.pop(ctx, ''),
                    ),
                    for (final a in assets)
                      _AssetPickerThumb(
                        path: a,
                        label: _assetLabel(a),
                        selected: current == a,
                        onTap: () => Navigator.pop(ctx, a),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Anulo'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AssetPickerThumb extends StatefulWidget {
  const _AssetPickerThumb({
    required this.path,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String? path;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AssetPickerThumb> createState() => _AssetPickerThumbState();
}

class _AssetPickerThumbState extends State<_AssetPickerThumb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.selected
                  ? AppColors.primaryGreen
                  : _hover
                  ? AppColors.borderVisible(0.4)
                  : AppColors.borderSubtle(0.15),
              width: widget.selected ? 2 : 1,
            ),
            color: widget.selected
                ? AppColors.lightGreenBg
                : _hover
                ? AppColors.beige
                : AppColors.white,
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: widget.path != null
                    ? Image.asset(
                        widget.path!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, _) => const Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: AppColors.lightGreenText,
                        ),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: AppColors.lightGreenBg,
                        child: const Icon(
                          Icons.hide_image_outlined,
                          size: 28,
                          color: AppColors.lightGreenText,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  color: widget.selected
                      ? AppColors.primaryGreen
                      : AppColors.mediumGreenText,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Menu Panel ──────────────────────────────────────────────────────────────

class _MenuPanel extends StatefulWidget {
  const _MenuPanel({required this.m});

  final ManagerData m;

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<_MenuPanel> {
  final _catCtrl = TextEditingController();
  final _prodName = TextEditingController();
  final _prodPrice = TextEditingController();
  String? _selectedCatId;
  String? _newProductImage; // null = no image

  @override
  void initState() {
    super.initState();
    final c = ManagerData.instance.categories;
    if (c.isNotEmpty) _selectedCatId = c.first.id;
  }

  @override
  void dispose() {
    _catCtrl.dispose();
    _prodName.dispose();
    _prodPrice.dispose();
    super.dispose();
  }

  Future<void> _pickNewImage() async {
    final picked = await _showImageSourcePicker(context, _newProductImage);
    if (picked != null) {
      setState(() => _newProductImage = picked.isEmpty ? null : picked);
    }
  }

  void _addProduct(String catId) {
    final pr = double.tryParse(_prodPrice.text.trim()) ?? 0;
    if (_prodName.text.trim().isEmpty || pr <= 0) return;
    widget.m.addProduct(
      categoryId: catId,
      name: _prodName.text.trim(),
      price: pr,
      imagePath: _newProductImage,
    );
    _prodName.clear();
    _prodPrice.clear();
    setState(() => _newProductImage = null);
  }

  Future<void> _openEditDialog(
    BuildContext context,
    String catId,
    ProductItem p,
  ) async {
    final nameCtrl = TextEditingController(text: p.name);
    final priceCtrl = TextEditingController(text: p.price.toStringAsFixed(2));
    String? editImage = p.imagePath;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ndrysho produktin',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Photo row
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: editImage != null
                            ? productImage(
                                editImage,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                placeholder: _noImageBox,
                              )
                            : _noImageBox(),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fotoja',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await _showImageSourcePicker(
                                context,
                                editImage,
                              );
                              if (picked != null) {
                                setSt(
                                  () => editImage = picked.isEmpty
                                      ? null
                                      : picked,
                                );
                              }
                            },
                            icon: const Icon(Icons.image_outlined, size: 16),
                            label: const Text('Ndrysho foton'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(
                                color: AppColors.primaryGreen,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameCtrl,
                    decoration: _inputDeco('Emri i produktit'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    decoration: _inputDeco('Çmimi'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Anulo'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final pr =
                              double.tryParse(priceCtrl.text.trim()) ?? 0;
                          if (nameCtrl.text.trim().isEmpty || pr <= 0) return;
                          widget.m.editProduct(
                            catId,
                            p.id,
                            name: nameCtrl.text.trim(),
                            price: pr,
                            imagePath: editImage,
                            clearImage: editImage == null,
                          );
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.white,
                        ),
                        child: const Text('Ruaj ndryshimet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    priceCtrl.dispose();
  }

  Widget _noImageBox() => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: AppColors.lightGreenBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(
      Icons.hide_image_outlined,
      size: 28,
      color: AppColors.lightGreenText,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final cats = m.categories;

    // If user removed all categories, keep "Add category" UI visible.
    // Products require at least one category, so they stay hidden.
    if (cats.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('7. Menu / kategori dinamike'),
          const SizedBox(height: 16),
          Text(
            'Nuk ka kategori. Shto një kategori për të vazhduar.',
            style: TextStyle(color: AppColors.lightGreenText),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _catCtrl,
                  decoration: _inputDeco('Emri i kategorisë së re'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  final txt = _catCtrl.text.trim();
                  if (txt.isEmpty) return;
                  m.addCategory(txt);
                  _catCtrl.clear();
                  setState(() => _selectedCatId = null);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Shto kategori'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Për të shtuar produkte, duhet të ekzistojë të paktën një kategori.',
            style: TextStyle(color: AppColors.mediumGreenText),
          ),
        ],
      );
    }

    final catValue =
        (_selectedCatId != null && cats.any((c) => c.id == _selectedCatId))
        ? _selectedCatId!
        : cats.first.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('7. Menu / kategori dinamike'),
        const SizedBox(height: 20),

        // ── Add category ────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _catCtrl,
                decoration: _inputDeco('Emri i kategorisë së re'),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () {
                if (_catCtrl.text.trim().isNotEmpty) {
                  m.addCategory(_catCtrl.text);
                  _catCtrl.clear();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Shto kategori'),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // ── Add product form ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shto produkt',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: _inputDeco('Kategoria'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: catValue,
                    isExpanded: true,
                    items: [
                      for (final c in cats)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _selectedCatId = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Photo picker
                  GestureDetector(
                    onTap: _pickNewImage,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Tooltip(
                        message: 'Zgjidh foton',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: _newProductImage != null
                                ? productImage(
                                    _newProductImage,
                                    fit: BoxFit.cover,
                                    placeholder: () => const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 22,
                                      color: AppColors.primaryGreen,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 22,
                                    color: AppColors.primaryGreen,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _prodName,
                      decoration: _inputDeco('Emri i produktit'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _prodPrice,
                      decoration: _inputDeco('Çmimi'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addProduct(catValue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _addProduct(catValue),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Shto'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ── Category tables ──────────────────────────────────────────────
        for (final c in cats) ...[
          _CategoryProductTable(
            category: c,
            onDeleteCategory: () => m.removeCategory(c.id),
            onDeleteProduct: (pid) => m.removeProduct(c.id, pid),
            onEditProduct: (p) => _openEditDialog(context, c.id, p),
            onMoveIn: (p, fromCatId) => m.moveProduct(fromCatId, p.id, c.id),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

// ── Premium Category Table ──────────────────────────────────────────────────

class _CategoryProductTable extends StatefulWidget {
  const _CategoryProductTable({
    required this.category,
    required this.onDeleteCategory,
    required this.onDeleteProduct,
    required this.onEditProduct,
    required this.onMoveIn,
  });

  final CategoryData category;
  final VoidCallback onDeleteCategory;
  final void Function(String productId) onDeleteProduct;
  final void Function(ProductItem product) onEditProduct;
  final void Function(ProductItem product, String fromCatId) onMoveIn;

  @override
  State<_CategoryProductTable> createState() => _CategoryProductTableState();
}

class _CategoryProductTableState extends State<_CategoryProductTable> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    return DragTarget<_ProductDrag>(
      onWillAcceptWithDetails: (d) => d.data.fromCatId != widget.category.id,
      onAcceptWithDetails: (d) =>
          widget.onMoveIn(d.data.product, d.data.fromCatId),
      builder: (context, candidateData, _) {
        final isOver = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isOver
                ? AppColors.lightGreenBg.withValues(alpha: 0.6)
                : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOver
                  ? AppColors.primaryGreen
                  : AppColors.borderSubtle(0.12),
              width: isOver ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isOver ? 0.06 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header row
              InkWell(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(c.icon, size: 20, color: AppColors.primaryGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${c.products.length} produkte',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Fshi kategorinë',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppColors.negativeText,
                        onPressed: widget.onDeleteCategory,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.mediumGreenText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Products list
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: c.products.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.beige,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Nuk ka produkte në këtë kategori.',
                            style: TextStyle(
                              color: AppColors.lightGreenText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          // Table header
                          Container(
                            color: AppColors.lightGreenBg,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 52),
                                const SizedBox(width: 16),
                                const Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Emri',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mediumGreenText,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 100,
                                  child: Text(
                                    'Çmimi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mediumGreenText,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                const SizedBox(width: 88),
                              ],
                            ),
                          ),
                          for (var i = 0; i < c.products.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: AppColors.borderSubtle(0.08),
                              ),
                            _ProductTableRow(
                              product: c.products[i],
                              isLast: i == c.products.length - 1,
                              onEdit: () => widget.onEditProduct(c.products[i]),
                              onDelete: () =>
                                  widget.onDeleteProduct(c.products[i].id),
                            ),
                          ],
                        ],
                      ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductTableRow extends StatefulWidget {
  const _ProductTableRow({
    required this.product,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductItem product;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ProductTableRow> createState() => _ProductTableRowState();
}

class _ProductTableRowState extends State<_ProductTableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hover
              ? AppColors.lightGreenBg.withValues(alpha: 0.5)
              : AppColors.white,
          borderRadius: widget.isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16))
              : BorderRadius.zero,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: p.imagePath != null
                  ? productImage(
                      p.imagePath,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: _thumbPlaceholder,
                    )
                  : _thumbPlaceholder(),
            ),
            const SizedBox(width: 16),
            // Name
            Expanded(
              flex: 3,
              child: Text(
                p.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGreenText,
                ),
              ),
            ),
            // Price
            SizedBox(
              width: 100,
              child: Text(
                '\$${p.price.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Actions
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                    icon: Icons.edit_outlined,
                    tooltip: 'Ndrysho',
                    color: AppColors.primaryGreen,
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 4),
                  _ActionBtn(
                    icon: Icons.delete_outline,
                    tooltip: 'Fshi',
                    color: AppColors.negativeText,
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: AppColors.lightGreenBg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
      Icons.fastfood_outlined,
      size: 22,
      color: AppColors.lightGreenText,
    ),
  );
}

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hover
                  ? widget.color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
        ),
      ),
    );
  }
}

class _TablesConfigPanel extends StatefulWidget {
  const _TablesConfigPanel({required this.m});

  final ManagerData m;

  @override
  State<_TablesConfigPanel> createState() => _TablesConfigPanelState();
}

class _TablesConfigPanelState extends State<_TablesConfigPanel> {
  late double _count;
  late double _perRow;

  /// null = pamja globale e kasës; emri = okupimi sipas porosive të atij kamarieri.
  String? _tableViewWaiter;
  List<TableInfo>? _waiterTablesSnapshot;

  List<TableInfo> _displayTables(ManagerData m) {
    if (_tableViewWaiter == null) return m.cashierTables;
    return _waiterTablesSnapshot ?? m.cashierTables;
  }

  Future<void> _syncWaiterTables() async {
    final w = _tableViewWaiter;
    if (w == null) {
      if (mounted) setState(() => _waiterTablesSnapshot = null);
      return;
    }
    final list = await widget.m.tablesForWaiter(w);
    if (!mounted || _tableViewWaiter != w) return;
    setState(() => _waiterTablesSnapshot = list);
  }

  @override
  void initState() {
    super.initState();
    _count = widget.m.tableCount.toDouble();
    _perRow = widget.m.tablesPerRow.toDouble();
    widget.m.addListener(_onM);
  }

  void _onM() {
    setState(() {});
    if (_tableViewWaiter != null) {
      _syncWaiterTables();
    }
  }

  @override
  void didUpdateWidget(covariant _TablesConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.m.removeListener(_onM);
    widget.m.addListener(_onM);
    _count = widget.m.tableCount.toDouble();
    _perRow = widget.m.tablesPerRow.toDouble();
  }

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final n = _count.round();
    final pr = _perRow.round();
    final occupied = m.cashierTables.where((t) => t.occupied).length;
    final free = m.cashierTables.length - occupied;
    final total = m.cashierTables.length;
    final occupancyPct = total > 0 ? (occupied / total * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Menaxhimi i Tavolinave'),
        const SizedBox(height: 6),
        const Text(
          'Monitoro dhe menaxho tavolinat e restorantit',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        // ── KPI row ──────────────────────────────────────────────────────
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.table_restaurant_outlined,
                  title: 'Tavolina Gjithsej',
                  value: '$total',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.people_outline,
                  title: 'Tavolina të Lira',
                  value: '$free',
                  accentColor: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.schedule_outlined,
                  title: 'Të Zëna',
                  value: '$occupied',
                  accentColor: AppColors.softRed,
                  badge: '$occupancyPct%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.event_available_outlined,
                  title: 'Të Rezervuara',
                  value: '0',
                  accentColor: AppColors.warmGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Floor Layout card ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightGreenBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Planimetria',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const Spacer(),
                  _TableLegendDot(
                    color: AppColors.primaryGreen,
                    label: 'Lirë',
                  ),
                  const SizedBox(width: 16),
                  _TableLegendDot(
                    color: AppColors.softRed,
                    label: 'Zënë',
                  ),
                  const SizedBox(width: 16),
                  _TableLegendDot(
                    color: AppColors.warmGold,
                    label: 'Rezervuar',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: pr.clamp(2, 12),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                ),
                itemCount: n,
                itemBuilder: (context, i) {
                  final id = i + 1;
                  TableInfo? info;
                  try {
                    info = m.cashierTables.firstWhere((t) => t.id == id);
                  } catch (_) {}
                  final occ = info?.occupied ?? false;

                  const freeBg = Color(0xFFECF5EC);
                  const freeBorder = Color(0xFFB8DEB8);
                  const occBg = Color(0xFFFFF0F0);
                  const occBorder = Color(0xFFFFCDD2);
                  const freeGreen = Color(0xFF4CAF50);
                  const occRed = Color(0xFFEF5350);

                  final bg = occ ? occBg : freeBg;
                  final border = occ ? occBorder : freeBorder;
                  final dot = occ ? occRed : freeGreen;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border, width: 1.5),
                    ),
                    child: Stack(
                      children: [
                        // Number badge (top-left)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$id',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkGreenText,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Status dot (top-right)
                        Positioned(
                          top: 10,
                          right: 2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Content (bottom-left)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: occ
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (info?.assignedWaiterName != null)
                                      Text(
                                        info!.assignedWaiterName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.darkGreenText,
                                        ),
                                      ),
                                    if ((info?.currentTotal ?? 0) > 0)
                                      Text(
                                        '${info!.currentTotal!.toStringAsFixed(0)}€',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.mediumGreenText,
                                        ),
                                      ),
                                  ],
                                )
                              : const Text(
                                  'Lirë',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: freeGreen,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Configuration card ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightGreenBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Konfigurimi i Planimetrisë',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreenText,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text(
                    'Numri i tavolinave',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_count.round()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primaryGreen,
                  inactiveTrackColor: AppColors.lightGreenBorder,
                  thumbColor: AppColors.primaryGreen,
                  overlayColor: AppColors.primaryGreen.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: _count,
                  min: 1,
                  max: 48,
                  divisions: 47,
                  label: '${_count.round()}',
                  onChanged: (v) => setState(() => _count = v),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Tavolina për rresht',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_perRow.round()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primaryGreen,
                  inactiveTrackColor: AppColors.lightGreenBorder,
                  thumbColor: AppColors.primaryGreen,
                  overlayColor: AppColors.primaryGreen.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: _perRow,
                  min: 2,
                  max: 12,
                  divisions: 10,
                  label: '${_perRow.round()}',
                  onChanged: (v) => setState(() => _perRow = v),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () {
                    m.setTableLayout(
                      count: _count.round(),
                      perRow: _perRow.round(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Table layout saved.'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Ruaj Planimetrinë'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Staff Payroll ────────────────────────────────

class _StaffPayrollPanel extends StatefulWidget {
  const _StaffPayrollPanel({required this.m});
  final ManagerData m;
  @override
  State<_StaffPayrollPanel> createState() => _StaffPayrollPanelState();
}

class _StaffPayrollPanelState extends State<_StaffPayrollPanel> {
  late DateTime _viewMonth;
  WaiterInfo? _selectedWaiter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
    widget.m.addListener(_onData);
  }

  void _onData() {
    if (_selectedWaiter != null) {
      final still = widget.m.waiters.where(
        (w) => w.name == _selectedWaiter!.name,
      );
      if (still.isEmpty) _selectedWaiter = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.m.removeListener(_onData);
    super.dispose();
  }

  static const _monthNames = [
    'Janar',
    'Shkurt',
    'Mars',
    'Prill',
    'Maj',
    'Qershor',
    'Korrik',
    'Gusht',
    'Shtator',
    'Tetor',
    'Nëntor',
    'Dhjetor',
  ];

  @override
  Widget build(BuildContext context) {
    final m = widget.m;

    if (_selectedWaiter != null) {
      return _WaiterPayrollDetail(
        waiter: _selectedWaiter!,
        m: m,
        viewMonth: _viewMonth,
        onMonthChanged: (dt) => setState(() => _viewMonth = dt),
        onBack: () => setState(() => _selectedWaiter = null),
      );
    }

    final periodStart = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final periodEnd = DateTime(
      _viewMonth.year,
      _viewMonth.month + 1,
      0,
      23,
      59,
      59,
      999,
    );

    double totalGross = 0;
    double totalAdv = 0;
    double maxGross = 0;
    for (final w in m.waiters) {
      final worked = m.workedDaysInMonth(
        w.name,
        _viewMonth.year,
        _viewMonth.month,
      );
      final rate = m.getSalary(w.name);
      final gross = rate * worked;
      totalGross += gross;
      totalAdv += m.totalAdvancesFor(w.name, periodStart, periodEnd);
      if (gross > maxGross) maxGross = gross;
    }
    final totalNet = totalGross - totalAdv;
    final staffCount = m.waiters.length;
    final avgSalary = staffCount > 0 ? totalGross / staffCount : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(child: _sectionTitle('Pagat & Avans')),
            // Month navigation pill
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGreenBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => setState(
                      () => _viewMonth = DateTime(
                        _viewMonth.year,
                        _viewMonth.month - 1,
                      ),
                    ),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: AppColors.primaryGreen,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${_monthNames[_viewMonth.month - 1]} ${_viewMonth.year}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(
                      () => _viewMonth = DateTime(
                        _viewMonth.year,
                        _viewMonth.month + 1,
                      ),
                    ),
                    icon: const Icon(
                      Icons.chevron_right,
                      color: AppColors.primaryGreen,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Menaxho pagat dhe avanset e stafit sipas muajit.',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        // ── KPI row ───────────────────────────────────────────────────────
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Pagesa Gjithsej',
                  value: '${totalGross.toStringAsFixed(0)}€',
                  accentColor: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.money_off_outlined,
                  title: 'Avanse Gjithsej',
                  value: '${totalAdv.toStringAsFixed(0)}€',
                  accentColor: AppColors.softRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.people_outline,
                  title: 'Numri i Stafit',
                  value: '$staffCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  title: 'Pagesa Neto',
                  value: '${totalNet.toStringAsFixed(0)}€',
                  accentColor: totalNet >= 0
                      ? AppColors.primaryGreen
                      : AppColors.softRed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Bottom 2-column section ───────────────────────────────────────
        if (m.waiters.isEmpty)
          _buildEmptyState()
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Staff list
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.lightGreenBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paga e Stafit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (int i = 0; i < m.waiters.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              color: AppColors.lightGreenBorder,
                            ),
                          _WaiterSummaryCard(
                            waiter: m.waiters[i],
                            m: m,
                            viewMonth: _viewMonth,
                            onTap: () =>
                                setState(() => _selectedWaiter = m.waiters[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Right: Monthly Summary
                SizedBox(
                  width: 320,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.lightGreenBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Përmbledhja Mujore',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Total payroll highlight
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pagesa Gjithsej',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.mediumGreenText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${totalGross.toStringAsFixed(0)}€',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _PayrollSummaryRow(
                          label: 'Paga Mesatare',
                          value: '${avgSalary.toStringAsFixed(2)}€',
                        ),
                        const Divider(
                          height: 24,
                          color: AppColors.lightGreenBorder,
                        ),
                        _PayrollSummaryRow(
                          label: 'Bruto Më i Lartë',
                          value: '${maxGross.toStringAsFixed(2)}€',
                        ),
                        const Divider(
                          height: 24,
                          color: AppColors.lightGreenBorder,
                        ),
                        _PayrollSummaryRow(
                          label: 'Avanse Gjithsej',
                          value: '-${totalAdv.toStringAsFixed(2)}€',
                          valueColor: totalAdv > 0
                              ? AppColors.softRed
                              : AppColors.mediumGreenText,
                        ),
                        const Divider(
                          height: 24,
                          color: AppColors.lightGreenBorder,
                        ),
                        _PayrollSummaryRow(
                          label: 'Numri i Stafit',
                          value: '$staffCount',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightGreenBorder),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.badge_outlined,
                size: 32,
                color: AppColors.lightGreenText,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nuk ka kamarierë të regjistruar.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGreenText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Shko te "Kamarierët" për të shtuar punonjës.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.lightGreenText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────── Waiter Summary Card (list view) ─────────────────────

class _PayrollSummaryRow extends StatelessWidget {
  const _PayrollSummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.mediumGreenText,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.darkGreenText,
          ),
        ),
      ],
    );
  }
}

class _WaiterSummaryCard extends StatelessWidget {
  const _WaiterSummaryCard({
    required this.waiter,
    required this.m,
    required this.viewMonth,
    required this.onTap,
  });

  final WaiterInfo waiter;
  final ManagerData m;
  final DateTime viewMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final worked = m.workedDaysInMonth(
      waiter.name,
      viewMonth.year,
      viewMonth.month,
    );
    final rate = m.getSalary(waiter.name);
    final gross = rate * worked;
    final periodStart = DateTime(viewMonth.year, viewMonth.month, 1);
    final periodEnd = DateTime(
      viewMonth.year,
      viewMonth.month + 1,
      0,
      23,
      59,
      59,
      999,
    );
    final totalAdv = m.totalAdvancesFor(waiter.name, periodStart, periodEnd);
    final net = gross - totalAdv;
    final initial =
        waiter.name.isNotEmpty ? waiter.name[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waiter.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rate > 0
                        ? '${rate.toStringAsFixed(2)}€/ditë · $worked ditë'
                        : 'Pa pagë të caktuar',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Stats: Gross | Adv | Net
            Row(
              children: [
                _statCell('Bruto', '${gross.toStringAsFixed(0)}€',
                    AppColors.darkGreenText),
                const SizedBox(width: 20),
                if (totalAdv > 0)
                  _statCell('Avans', '-${totalAdv.toStringAsFixed(0)}€',
                      AppColors.softRed),
                if (totalAdv > 0) const SizedBox(width: 20),
                _statCell(
                  'Neto',
                  '${net.toStringAsFixed(0)}€',
                  net >= 0 ? AppColors.primaryGreen : AppColors.softRed,
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.mediumGreenText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCell(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.mediumGreenText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────── Waiter Payroll Detail (calendar view) ───────────────

class _WaiterPayrollDetail extends StatefulWidget {
  const _WaiterPayrollDetail({
    required this.waiter,
    required this.m,
    required this.viewMonth,
    required this.onMonthChanged,
    required this.onBack,
  });

  final WaiterInfo waiter;
  final ManagerData m;
  final DateTime viewMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onBack;

  @override
  State<_WaiterPayrollDetail> createState() => _WaiterPayrollDetailState();
}

class _WaiterPayrollDetailState extends State<_WaiterPayrollDetail> {
  bool _editingRate = false;
  bool _advancesExpanded = false;
  late final TextEditingController _rateCtrl;

  @override
  void initState() {
    super.initState();
    final rate = widget.m.getSalary(widget.waiter.name);
    _rateCtrl = TextEditingController(
      text: rate > 0 ? rate.toStringAsFixed(2) : '',
    );
    widget.m.addListener(_onData);
  }

  void _onData() => setState(() {});

  @override
  void dispose() {
    widget.m.removeListener(_onData);
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveRate() async {
    final val = double.tryParse(_rateCtrl.text.replaceAll(',', '.'));
    if (val != null && val >= 0) {
      await widget.m.setSalary(widget.waiter.name, val);
    }
    if (mounted) setState(() => _editingRate = false);
  }

  Future<void> _selectAllDays() async {
    final m = widget.m;
    final w = widget.waiter;
    final month = widget.viewMonth;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final allWorked = Iterable.generate(daysInMonth, (i) => i + 1).every(
      (day) => m.isDayWorked(w.name, DateTime(month.year, month.month, day)),
    );
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isWorked = m.isDayWorked(w.name, date);
      if (allWorked ? isWorked : !isWorked) {
        await m.toggleWorkedDay(w.name, date);
      }
    }
  }

  Future<void> _showAddAdvanceDialog() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime pickedDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(
            'Avans — ${widget.waiter.name}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDeco('Shuma (€)'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: _inputDeco('Shënim (opsional)'),
                  maxLength: 80,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.mediumGreenText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pickedDate.day.toString().padLeft(2, '0')}.${pickedDate.month.toString().padLeft(2, '0')}.${pickedDate.year}',
                      style: const TextStyle(
                        color: AppColors.darkGreenText,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: pickedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setDlg(() => pickedDate = d);
                      },
                      child: const Text('Ndrysho'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Anulo',
                style: TextStyle(color: AppColors.mediumGreenText),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              onPressed: () async {
                final amount = double.tryParse(
                  amountCtrl.text.replaceAll(',', '.'),
                );
                if (amount == null || amount <= 0) return;
                await widget.m.addAdvance(
                  AdvanceRow(
                    waiterName: widget.waiter.name,
                    amount: amount,
                    note: noteCtrl.text.trim(),
                    date: pickedDate,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Regjistro'),
            ),
          ],
        ),
      ),
    );
  }

  static const _monthNames = [
    'Janar',
    'Shkurt',
    'Mars',
    'Prill',
    'Maj',
    'Qershor',
    'Korrik',
    'Gusht',
    'Shtator',
    'Tetor',
    'Nëntor',
    'Dhjetor',
  ];
  static const _dayLabels = ['Hën', 'Mar', 'Mër', 'Enj', 'Pre', 'Sht', 'Die'];

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final w = widget.waiter;
    final month = widget.viewMonth;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final worked = m.workedDaysInMonth(w.name, month.year, month.month);
    final rate = m.getSalary(w.name);
    final gross = rate * worked;
    final periodStart = DateTime(month.year, month.month, 1);
    final periodEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
    final totalAdv = m.totalAdvancesFor(w.name, periodStart, periodEnd);
    final net = gross - totalAdv;
    final monthAdvances = m.advancesFor(w.name, periodStart, periodEnd);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final totalCells = (firstWeekday - 1) + daysInMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── top bar ──────────────────────────────────────────────────────────
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              color: AppColors.primaryGreen,
              tooltip: 'Kthehu',
            ),
            CircleAvatar(
              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
              radius: 18,
              child: Text(
                w.name.isNotEmpty ? w.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              w.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _showAddAdvanceDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ Avans'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── calendar card ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle()),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // month nav
              Row(
                children: [
                  IconButton(
                    onPressed: () => widget.onMonthChanged(
                      DateTime(month.year, month.month - 1),
                    ),
                    icon: const Icon(Icons.chevron_left),
                    color: AppColors.primaryGreen,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_monthNames[month.month - 1]} ${month.year}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                    ),
                  ),
                  // Select / Deselect all days
                  Builder(
                    builder: (_) {
                      final allWorked = Iterable.generate(
                        daysInMonth,
                        (i) => i + 1,
                      ).every(
                        (day) => m.isDayWorked(
                          w.name,
                          DateTime(month.year, month.month, day),
                        ),
                      );
                      return TextButton(
                        onPressed: _selectAllDays,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          allWorked ? 'Çzgjidh të Gjitha' : 'Zgjidh të Gjitha',
                        ),
                      );
                    },
                  ),
                  IconButton(
                    onPressed: () => widget.onMonthChanged(
                      DateTime(month.year, month.month + 1),
                    ),
                    icon: const Icon(Icons.chevron_right),
                    color: AppColors.primaryGreen,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // weekday labels
              Row(
                children: _dayLabels
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mediumGreenText,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 6),
              // day grid — click to toggle worked
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: totalCells,
                itemBuilder: (_, i) {
                  if (i < firstWeekday - 1) return const SizedBox.shrink();
                  final day = i - (firstWeekday - 1) + 1;
                  final date = DateTime(month.year, month.month, day);
                  final isWorked = m.isDayWorked(w.name, date);
                  return GestureDetector(
                    onTap: () async => m.toggleWorkedDay(w.name, date),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isWorked ? AppColors.primaryGreen : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isWorked
                            ? null
                            : Border.all(
                                color: AppColors.borderSubtle(0.08),
                                width: 0.5,
                              ),
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isWorked
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isWorked
                                ? AppColors.white
                                : AppColors.darkGreenText,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // summary banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Ditë të punuara: $worked / $daysInMonth  •  ${_monthNames[month.month - 1]} ${month.year}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── payroll card ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // daily rate row
              Row(
                children: [
                  const Icon(
                    Icons.euro_outlined,
                    size: 18,
                    color: AppColors.mediumGreenText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Paga ditore:',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_editingRate)
                    SizedBox(
                      width: 110,
                      height: 36,
                      child: TextField(
                        controller: _rateCtrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: 2,
                            ),
                          ),
                          suffixText: '€',
                        ),
                        onSubmitted: (_) => _saveRate(),
                      ),
                    )
                  else
                    Text(
                      rate > 0
                          ? '${rate.toStringAsFixed(2)}€/ditë'
                          : 'E pacaktuar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: rate > 0
                            ? AppColors.darkGreenText
                            : AppColors.lightGreenText,
                      ),
                    ),
                  const SizedBox(width: 4),
                  if (_editingRate) ...[
                    IconButton(
                      onPressed: _saveRate,
                      icon: const Icon(Icons.check, size: 18),
                      color: AppColors.primaryGreen,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _editingRate = false),
                      icon: const Icon(Icons.close, size: 18),
                      color: AppColors.negativeText,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ] else
                    IconButton(
                      onPressed: () => setState(() => _editingRate = true),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      color: AppColors.mediumGreenText,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: 'Ndrysho pagën ditore',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // KPI chips
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _payKpi(
                    'Ditë të punuara',
                    '$worked',
                    Icons.calendar_month_outlined,
                  ),
                  _payKpi(
                    'Paga bruto',
                    '${gross.toStringAsFixed(2)}€',
                    Icons.account_balance_wallet_outlined,
                  ),
                  _payKpi(
                    'Avanse',
                    '${totalAdv.toStringAsFixed(2)}€',
                    Icons.money_off_outlined,
                    negative: true,
                  ),
                  _payKpi(
                    'Mbetet',
                    '${net.toStringAsFixed(2)}€',
                    Icons.check_circle_outline,
                    positive: net >= 0,
                  ),
                ],
              ),
              // advances list (expandable)
              if (monthAdvances.isNotEmpty) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () =>
                      setState(() => _advancesExpanded = !_advancesExpanded),
                  child: Row(
                    children: [
                      Icon(
                        _advancesExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18,
                        color: AppColors.mediumGreenText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Avanse (${monthAdvances.length})',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mediumGreenText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_advancesExpanded) ...[
                  const SizedBox(height: 8),
                  ...monthAdvances.map(_buildAdvanceRow),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvanceRow(AdvanceRow a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.negativeBg.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.negativeText.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.arrow_downward,
              size: 14,
              color: AppColors.negativeText,
            ),
            const SizedBox(width: 8),
            Text(
              '${a.amount.toStringAsFixed(2)}€',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.negativeText,
              ),
            ),
            if (a.note.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.note,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mediumGreenText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            Text(
              '${a.date.day.toString().padLeft(2, '0')}.${a.date.month.toString().padLeft(2, '0')}.${a.date.year}',
              style: TextStyle(fontSize: 11, color: AppColors.lightGreenText),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () async {
                if (a.dbId != null) await widget.m.deleteAdvance(a.dbId!);
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              color: AppColors.negativeText,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Fshi avancin',
            ),
          ],
        ),
      ),
    );
  }

  Widget _payKpi(
    String label,
    String value,
    IconData icon, {
    bool negative = false,
    bool? positive,
  }) {
    final Color col = positive != null
        ? (positive ? AppColors.primaryGreen : AppColors.negativeText)
        : negative
        ? AppColors.negativeText
        : AppColors.darkGreenText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: negative
            ? AppColors.negativeBg.withValues(alpha: 0.4)
            : AppColors.lightGreenBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: negative
              ? AppColors.negativeText.withValues(alpha: 0.12)
              : AppColors.borderSubtle(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: col),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: AppColors.lightGreenText),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: col,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _sectionTitle(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: AppColors.darkGreenText,
      height: 1.2,
    ),
  );
}

InputDecoration _inputDeco(String hint, {String? prefix}) {
  return InputDecoration(
    hintText: hint,
    prefixText: prefix,
    filled: true,
    fillColor: AppColors.pureWhite,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lightGreenBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lightGreenBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.controlRadius),
      borderSide: const BorderSide(
        color: AppColors.deepForestGreen,
        width: 2,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: const TextStyle(
      color: AppColors.lightGreenText,
      fontSize: 14,
    ),
  );
}

class _TableLegendDot extends StatelessWidget {
  const _TableLegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mediumGreenText,
          ),
        ),
      ],
    );
  }
}
