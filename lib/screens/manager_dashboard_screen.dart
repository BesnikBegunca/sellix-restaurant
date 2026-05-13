import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../manager/manager_data.dart';
import '../screens/sales_history_screen.dart';
import '../services/expenses_pdf_export.dart';
import '../services/manager_summary_pdf.dart';
import '../services/printer_settings_store.dart';
import '../services/receipt_printer.dart';
import '../services/windows_printers_service.dart';
import '../models/mock_data.dart';
import '../theme/app_colors.dart';
import '../utils/image_utils.dart';

/// Të dhënat që barten me drag nga një produkt.
typedef _ProductDrag = ({String fromCatId, ProductItem product});

const _kSectionTitles = <String>[
  'Përmbledhje',
  'Gjendja',
  'Kamarierët',
  'Shpenzime',
  'Fitime',
  'Raporte',
  'Top puntor',
  'Menu',
  'Tavolinat',
  'Company Settings',
  'Pagat & Avans',
  'Historiku i Shitjeve',
];

/// Dashboard menaxheri (PIN 9999). Seksionet 1–8 sipas kërkesës.
class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final ManagerData _m = ManagerData.instance;
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
          _ManagerSideNav(
            expanded: _sidebarExpanded,
            selectedIndex: _railIndex,
            onToggle: () =>
                setState(() => _sidebarExpanded = !_sidebarExpanded),
            onDestinationSelected: (i) => setState(() => _railIndex = i),
            onLogout: _exitToLogin,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ManagerTopBar(sectionTitle: _kSectionTitles[_railIndex]),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
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
          content: Text('Login mode changed to ${newMode == 'PINMODE' ? 'PIN' : 'Name'} Mode'),
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
        content: Text('Printer selected: $printerName'),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildLoginModeOption({
    required String mode,
    required String title,
    required String description,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _changeLoginMode(mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.lightGreenText,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? AppColors.lightGreenBg : AppColors.white,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: mode,
              groupValue: _selectedLoginMode,
              onChanged: (value) {
                if (value != null) _changeLoginMode(value);
              },
              activeColor: AppColors.primaryGreen,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.lightGreenText,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primaryGreen,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('10. Company Settings'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.lightGreenBg.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Këto cilësime përcaktojnë identitetin e kompanisë suaj. Emri dhe logo shfaqen në ekranin e hyrjes dhe në krejt aplikacionin.',
                  style: TextStyle(
                    color: AppColors.mediumGreenText,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Login Mode Section
        _buildSectionCard(
          title: 'Login Mode',
          icon: Icons.security,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select how waiters log into the system:',
                style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
              ),
              const SizedBox(height: 16),
              // PIN Mode Option
              _buildLoginModeOption(
                mode: 'PINMODE',
                title: '🔐 PIN Mode',
                description: 'Waiters enter their PIN (4-6 digits)',
                isSelected: _selectedLoginMode == 'PINMODE',
              ),
              const SizedBox(height: 12),
              // Name Mode Option
              _buildLoginModeOption(
                mode: 'NAMEMODE',
                title: '👤 Name Mode',
                description: 'Waiters select their name from a list',
                isSelected: _selectedLoginMode == 'NAMEMODE',
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        _buildSectionCard(
          title: 'Printers',
          icon: Icons.print,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select Windows printer for POS80 receipts.',
                style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
              ),
              const SizedBox(height: 16),
              if (_loadingPrinters)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else if (_printers.isEmpty)
                const Text(
                  'No Windows printers found.',
                  style: TextStyle(fontSize: 13, color: AppColors.lightGreenText),
                )
              else
                DropdownButtonFormField<String>(
                  value: _printers.contains(_selectedPrinter)
                      ? _selectedPrinter
                      : null,
                  items: _printers
                      .map(
                        (name) => DropdownMenuItem<String>(
                          value: name,
                          child: Text(name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    _savePrinter(v);
                  },
                  decoration: _inputDeco('Select printer'),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _loadPrinters,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Printers'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Company Name Section
        _buildSectionCard(
          title: 'Emri i Kompanisë',
          icon: Icons.business,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: _inputDeco('Shkruani emrin e kompanisë'),
                style: const TextStyle(fontSize: 16),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              Text(
                'Ky emër do të shfaqet në ekranin e hyrjes dhe në titujt e aplikacionit.',
                style: TextStyle(color: AppColors.lightGreenText, fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Company Logo Section
        _buildSectionCard(
          title: 'Logo e Kompanisë',
          icon: Icons.image,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo Preview and Upload Area
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.beige,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle(0.15)),
                ),
                child: Row(
                  children: [
                    // Logo Preview
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: widget.m.companyLogoBytes != null
                          ? Image.memory(
                              widget.m.companyLogoBytes!,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Icon(
                                Icons.business,
                                color: AppColors.mediumGreenText,
                                size: 32,
                              ),
                            ),
                    ),
                    const SizedBox(width: 20),
                    // Upload Controls
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.m.companyLogoBytes != null
                                ? 'Logo është ngarkuar'
                                : 'Nuk ka logo të ngarkuar',
                            style: TextStyle(
                              color: AppColors.darkGreenText,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Logo duhet të jetë në format PNG, JPG ose JPEG. Madhësia ideale është 512x512 piksel.',
                            style: TextStyle(
                              color: AppColors.lightGreenText,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: _pickLogo,
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: Text(
                                  widget.m.companyLogoBytes != null
                                      ? 'Ndrysho logo'
                                      : 'Ngarko logo',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: AppColors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (widget.m.companyLogoBytes != null) ...[
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: _clearLogo,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Fshi'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.negativeText,
                                    side: BorderSide(
                                      color: AppColors.negativeText.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
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
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Save Button
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save, size: 20),
                label: const Text('Ruaj Cilësimet'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.negativeText.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.negativeText.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.negativeText,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: TextStyle(
                            color: AppColors.negativeText,
                            fontSize: 14,
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
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryGreen, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.darkGreenText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(padding: const EdgeInsets.all(20), child: child),
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
    (
      icon: Icons.dashboard_outlined,
      sel: Icons.dashboard,
      label: 'Përmbledhje',
    ),
    (icon: Icons.schedule_outlined, sel: Icons.schedule, label: 'Gjendja'),
    (icon: Icons.badge_outlined, sel: Icons.badge, label: 'Kamarierët'),
    (
      icon: Icons.table_rows_outlined,
      sel: Icons.table_rows,
      label: 'Shpenzime',
    ),
    (icon: Icons.trending_up_outlined, sel: Icons.trending_up, label: 'Fitime'),
    (
      icon: Icons.description_outlined,
      sel: Icons.description,
      label: 'Raporte',
    ),
    (
      icon: Icons.emoji_events_outlined,
      sel: Icons.emoji_events,
      label: 'Top puntor',
    ),
    (icon: Icons.menu_book_outlined, sel: Icons.menu_book, label: 'Menu'),
    (icon: Icons.grid_view_outlined, sel: Icons.grid_view, label: 'Tavolinat'),
    (icon: Icons.settings_outlined, sel: Icons.settings, label: 'Company'),
    (icon: Icons.payments_outlined, sel: Icons.payments, label: 'Pagat'),
    (icon: Icons.history_outlined, sel: Icons.history, label: 'Historiku'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: expanded ? 256 : 72,
      color: AppColors.white,
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Align(
              alignment: expanded ? Alignment.centerRight : Alignment.center,
              child: IconButton(
                tooltip: expanded
                    ? 'Mbyll menunë anësore'
                    : 'Hap menunë anësore',
                onPressed: onToggle,
                icon: Icon(
                  expanded ? Icons.keyboard_double_arrow_left : Icons.menu,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final it = _items[i];
                final sel = i == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: sel ? AppColors.lightGreenBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onDestinationSelected(i),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            SizedBox(
                              width: expanded ? 44 : 56,
                              child: Center(
                                child: Icon(
                                  sel ? it.sel : it.icon,
                                  size: 22,
                                  color: sel
                                      ? AppColors.primaryGreen
                                      : AppColors.mediumGreenText,
                                ),
                              ),
                            ),
                            if (expanded)
                              Expanded(
                                child: Text(
                                  it.label,
                                  style: TextStyle(
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: sel
                                        ? AppColors.darkGreenText
                                        : AppColors.mediumGreenText,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppColors.borderSubtle(0.12)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
            child: expanded
                ? SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text('Dil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: BorderSide(color: AppColors.borderVisible(0.25)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  )
                : Tooltip(
                    message: 'Dil',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onLogout,
                        borderRadius: BorderRadius.circular(12),
                        child: const SizedBox(
                          height: 48,
                          width: 48,
                          child: Icon(
                            Icons.logout,
                            color: AppColors.primaryGreen,
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

class _ManagerTopBar extends StatelessWidget {
  const _ManagerTopBar({required this.sectionTitle});

  final String sectionTitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 0,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderSubtle(0.1)),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'MANAGER',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sectionTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Dashboard menaxheri · POS System',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.lightGreenText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Përmbledhje operacioni',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PIN menaxheri: 9999 · Menu dinamike, tavolina dhe raporte në një vend.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
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
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _StatCard(
              title: 'Gjendja',
              value: m.shiftOpen ? 'E hapur' : 'E mbyllur',
              icon: Icons.schedule,
            ),
            _StatCard(
              title: 'Kamarierë aktivë',
              value: '${m.waiters.length}',
              icon: Icons.badge,
            ),
            _StatCard(
              title: 'Shpenzime totale',
              value: '\$${m.totalExpenses.toStringAsFixed(2)}',
              icon: Icons.payments_outlined,
            ),
            _StatCard(
              title: 'Fitim sot',
              value: '€${m.profitToday.toStringAsFixed(0)}',
              icon: Icons.trending_up,
            ),
            _StatCard(
              title: 'Fitim kjo javë',
              value: '€${m.profitThisWeek.toStringAsFixed(0)}',
              icon: Icons.calendar_view_week_outlined,
            ),
            _StatCard(
              title: 'Top puntor',
              value: top.key == '—' ? '—' : top.key,
              subtitle: top.key == '—'
                  ? null
                  : '\$${top.value.toStringAsFixed(0)}',
              icon: Icons.emoji_events,
            ),
            _StatCard(
              title: 'Tavolina',
              value: '${m.cashierTables.length} · ${m.tablesPerRow}/rresht',
              icon: Icons.grid_view,
            ),
            _StatCard(
              title: 'Tavolina të zëna',
              value: '$occupied / ${m.cashierTables.length}',
              icon: Icons.event_seat_outlined,
            ),
            _StatCard(
              title: 'Hapësirë e hapur',
              value: '\$${openCheck.toStringAsFixed(2)}',
              icon: Icons.receipt_long_outlined,
            ),
            _StatCard(
              title: 'Kategori menuje',
              value: '$categoryCount',
              icon: Icons.category_outlined,
            ),
            _StatCard(
              title: 'Produkte në menu',
              value: '$productCount',
              icon: Icons.inventory_2_outlined,
            ),
            _StatCard(
              title: 'Shitje stafi (sesioni)',
              value: '\$${totalStaffSales.toStringAsFixed(2)}',
              icon: Icons.point_of_sale_outlined,
            ),
          ],
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 920;
            final chartColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OverviewSalesBarsCard(m: m),
                const SizedBox(height: 16),
                _OverviewTrendAndOccupancyCard(m: m, occupied: occupied),
                const SizedBox(height: 16),
                _OverviewActivityCard(m: m),
              ],
            );
            final sideColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OverviewQuickActionsCard(onNavigate: onNavigate),
                const SizedBox(height: 16),
                _OverviewWaitersLeaderboard(m: m),
              ],
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 58, child: chartColumn),
                  const SizedBox(width: 20),
                  Expanded(flex: 42, child: sideColumn),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [chartColumn, const SizedBox(height: 20), sideColumn],
            );
          },
        ),
      ],
    );
  }
}

class _OverviewLiveClockChip extends StatefulWidget {
  @override
  State<_OverviewLiveClockChip> createState() => _OverviewLiveClockChipState();
}

class _OverviewLiveClockChipState extends State<_OverviewLiveClockChip> {
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
    final t =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Material(
      color: AppColors.lightGreenBg,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 20, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.darkGreenText,
                  ),
                ),
                Text(
                  '${now.day}.${now.month}.${now.year}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.lightGreenText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewSalesBarsCard extends StatelessWidget {
  const _OverviewSalesBarsCard({required this.m});

  final ManagerData m;

  @override
  Widget build(BuildContext context) {
    final entries = m.employeeSalesSorted.take(6).toList();
    return _OverviewSectionCard(
      title: 'Shitje sipas kamarierit',
      subtitle:
          'Total i mbledhur nga pagesat në POS (sesioni aktual në memorie).',
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nuk ka shitje të regjistruara ende. Finalizo një pagesë nga kasieri.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mediumGreenText),
                ),
              ),
            )
          : _OverviewSalesBarsInner(entries: entries),
    );
  }
}

class _OverviewSalesBarsInner extends StatelessWidget {
  const _OverviewSalesBarsInner({required this.entries});

  final List<MapEntry<String, double>> entries;

  @override
  Widget build(BuildContext context) {
    final maxV = entries.map((e) => e.value).reduce(math.max);
    const maxBar = 140.0;
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in entries)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '\$${e.value.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 36,
                          height: maxV > 0 ? (e.value / maxV) * maxBar : 4.0,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.mediumGreenText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewTrendAndOccupancyCard extends StatelessWidget {
  const _OverviewTrendAndOccupancyCard({
    required this.m,
    required this.occupied,
  });

  final ManagerData m;
  final int occupied;

  @override
  Widget build(BuildContext context) {
    final n = math.max(m.cashierTables.length, 1);
    final occRatio = (occupied / n).clamp(0.0, 1.0);

    // Real sales per day for the last 7 days (oldest → newest).
    final today = DateTime.now();
    final bars = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final from = DateTime(day.year, day.month, day.day);
      final to = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
      return m.revenueInRange(from, to);
    });
    final hi = bars.fold(0.0, math.max);
    final norm = hi > 0
        ? bars.map((b) => b / hi).toList()
        : List.filled(7, 0.0);

    return _OverviewSectionCard(
      title: 'Trend & kapacitet tavolinash',
      subtitle:
          'Shitjet ditore — 7 ditët e fundit; '
          'shiriti i poshtëm tregon zënien e tavolinave.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 108,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < norm.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: LayoutBuilder(
                                builder: (context, c) {
                                  final maxH = math.max(4.0, c.maxHeight);
                                  final h = 4 + norm[i] * (maxH - 4);
                                  return Container(
                                    width: double.infinity,
                                    height: h.clamp(4.0, maxH),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          AppColors.primaryGreen.withValues(
                                            alpha: 0.85,
                                          ),
                                          AppColors.lightGreenBg,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.1,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Zënia e tavolinave',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: occRatio,
              minHeight: 10,
              backgroundColor: AppColors.lightGreenBg,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$occupied të zëna nga ${m.cashierTables.length} (${(occRatio * 100).toStringAsFixed(0)}%)',
            style: TextStyle(fontSize: 12, color: AppColors.mediumGreenText),
          ),
        ],
      ),
    );
  }
}

class _OverviewActivityCard extends StatelessWidget {
  const _OverviewActivityCard({required this.m});

  final ManagerData m;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    if (m.shiftOpenedAt != null) {
      tiles.add(
        ListTile(
          dense: true,
          leading: Icon(
            Icons.play_circle_outline,
            color: AppColors.primaryGreen,
          ),
          title: const Text('Gjendja u hap'),
          subtitle: Text(
            '${m.shiftOpenedAt}',
            style: TextStyle(fontSize: 12, color: AppColors.lightGreenText),
          ),
        ),
      );
    }
    if (m.shiftClosedAt != null && !m.shiftOpen) {
      tiles.add(
        ListTile(
          dense: true,
          leading: Icon(
            Icons.stop_circle_outlined,
            color: AppColors.mediumGreenText,
          ),
          title: const Text('Gjendja u mbyll'),
          subtitle: Text(
            '${m.shiftClosedAt}',
            style: TextStyle(fontSize: 12, color: AppColors.lightGreenText),
          ),
        ),
      );
    }

    final sortedExp = List<ExpenseRow>.from(m.expenses)
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final e in sortedExp.take(6)) {
      tiles.add(
        ListTile(
          dense: true,
          leading: const Icon(Icons.receipt_outlined, size: 22),
          title: Text(
            e.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${e.type} · ${e.date}',
            style: TextStyle(fontSize: 12, color: AppColors.lightGreenText),
          ),
          trailing: Text(
            '\$${e.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
        ),
      );
    }

    if (tiles.isEmpty) {
      tiles.add(
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Nuk ka aktivitet të fundit. Hap gjendjen ose shto shpenzime për të parë historikun këtu.',
            style: TextStyle(color: AppColors.mediumGreenText),
          ),
        ),
      );
    }

    return _OverviewSectionCard(
      title: 'Aktiviteti i fundit',
      subtitle: 'Shift dhe shpenzime së fundi (sipas të dhënave lokale).',
      child: Column(children: tiles),
    );
  }
}

class _OverviewQuickActionsCard extends StatelessWidget {
  const _OverviewQuickActionsCard({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    void go(int i) => onNavigate(i);

    Widget chip(String label, IconData icon, int section) {
      return ActionChip(
        avatar: Icon(icon, size: 18, color: AppColors.primaryGreen),
        label: Text(label),
        backgroundColor: AppColors.white,
        side: BorderSide(color: AppColors.borderSubtle(0.15)),
        onPressed: () => go(section),
      );
    }

    return _OverviewSectionCard(
      title: 'Veprime të shpejta',
      subtitle: 'Shko direkt te seksioni përkatës në menunë anësore.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('Gjendja', Icons.schedule, 1),
          chip('Kamarierët', Icons.badge_outlined, 2),
          chip('Shpenzime', Icons.table_rows_outlined, 3),
          chip('Fitime', Icons.trending_up, 4),
          chip('Raporte', Icons.description_outlined, 5),
          chip('Top puntor', Icons.emoji_events_outlined, 6),
          chip('Menu', Icons.menu_book_outlined, 7),
          chip('Tavolinat', Icons.grid_view_outlined, 8),
        ],
      ),
    );
  }
}

class _OverviewWaitersLeaderboard extends StatelessWidget {
  const _OverviewWaitersLeaderboard({required this.m});

  final ManagerData m;

  @override
  Widget build(BuildContext context) {
    final rows = m.employeeSalesSorted.take(8).toList();
    return _OverviewSectionCard(
      title: 'Renditja e shitjeve',
      subtitle: 'Kamarierët me shumë shitje të regjistruara në këtë sesion.',
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Ende pa të dhëna shitjesh për stafin.',
                style: TextStyle(color: AppColors.mediumGreenText),
              ),
            )
          : Table(
              columnWidths: const {
                0: FixedColumnWidth(36),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderSubtle(0.12)),
                    ),
                  ),
                  children: [
                    _tblHead('#'),
                    _tblHead('Kamarieri'),
                    _tblHead('Shitje', right: true),
                  ],
                ),
                for (var i = 0; i < rows.length; i++)
                  TableRow(
                    children: [
                      _tblCell('${i + 1}', bold: i == 0),
                      _tblCell(rows[i].key, bold: i == 0),
                      _tblCell(
                        '\$${rows[i].value.toStringAsFixed(2)}',
                        right: true,
                        bold: i == 0,
                      ),
                    ],
                  ),
              ],
            ),
    );
  }

  static Widget _tblHead(String s, {bool right = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        s,
        textAlign: right ? TextAlign.right : TextAlign.start,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.lightGreenText,
        ),
      ),
    );
  }

  static Widget _tblCell(String s, {bool right = false, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        s,
        textAlign: right ? TextAlign.right : TextAlign.start,
        style: TextStyle(
          fontSize: 14,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: AppColors.darkGreenText,
        ),
      ),
    );
  }
}

class _OverviewSectionCard extends StatelessWidget {
  const _OverviewSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.mediumGreenText,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
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
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        elevation: 0,
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderSubtle(0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primaryGreen, size: 28),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.lightGreenText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.mediumGreenText,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftPanel extends StatelessWidget {
  const _ShiftPanel({required this.m});

  final ManagerData m;

  Future<void> _showPrintDialog(BuildContext context) async {
    final sales = m.waiterSales;
    final names = <String>{
      ...m.waiters.map((w) => w.name),
      ...sales.keys,
    }.toList()
      ..sort();
    final waiterTotals = <String, double>{
      for (final name in names) name: (sales[name] ?? 0.0),
    };

    final ok = await ReceiptPrinter.printShiftStatus(
      companyName: m.companyName ?? 'POS System',
      waiterTotals: waiterTotals,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
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

    showDialog(
      context: context,
      builder: (_) => _GjendjaDialog(m: m, isClose: false),
    );
  }

  void _showCloseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _GjendjaDialog(m: m, isClose: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('1. Gjendja (shift)'),
        const SizedBox(height: 8),
        Text(
          'Shtyp gjendjen çdo moment ose mbyll ditën për të resetuar totalet.',
          style: TextStyle(color: AppColors.mediumGreenText),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => _showPrintDialog(context),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Shtyp gjendjen'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: () => _showCloseDialog(context),
              icon: const Icon(Icons.stop),
              label: const Text('Mbyll gjendjen'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkGreenText,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statusi: AKTIV',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
              if (m.shiftClosedAt != null)
                Text(
                  'Mbyllur së fundmi: ${m.shiftClosedAt}',
                  style: const TextStyle(fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Modal that shows all waiter totals.
/// When [isClose] is true it adds a confirm button that finalises and resets.
class _GjendjaDialog extends StatelessWidget {
  const _GjendjaDialog({required this.m, required this.isClose});

  final ManagerData m;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    final sales = m.waiterSales;

    // Union of registered waiters and any name that appears in sales map.
    final names = <String>{
      ...m.waiters.map((w) => w.name),
      ...sales.keys,
    }.toList()..sort();

    final grandTotal = names.fold<double>(0, (s, n) => s + (sales[n] ?? 0));

    return AlertDialog(
      title: Text(
        isClose ? 'Mbyll gjendjen' : 'Gjendja aktuale',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 360,
        child: names.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nuk ka kamarierë të regjistruar.',
                  style: TextStyle(color: AppColors.mediumGreenText),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...names.map(
                    (name) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      trailing: Text(
                        '${(sales[name] ?? 0.0).toStringAsFixed(2)} €',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${grandTotal.toStringAsFixed(2)} €',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  if (isClose)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Pas konfirmimit të gjitha totalet resetohen në 0.00.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mediumGreenText,
                        ),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isClose ? 'Anulo' : 'Mbyll'),
        ),
        if (isClose)
          FilledButton(
            onPressed: () {
              m.closeShift();
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.darkGreenText,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Konfirmo & Reseto'),
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
  String? _errorMsg;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMsg = 'Shkruaj emrin e kamarierit.');
      return;
    }
    if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
      setState(() => _errorMsg = 'PIN duhet të jetë 4–6 shifra.');
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
    _nameCtrl.clear();
    _pinCtrl.clear();
    setState(() => _errorMsg = null);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('2. Kamarierët'),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _nameCtrl,
                decoration: _inputDeco('Emri i kamarierit'),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _pinCtrl,
                decoration: _inputDeco('PIN (4–6 shifra)'),
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FilledButton(
                onPressed: _add,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
                child: const Text('Shto'),
              ),
            ),
          ],
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMsg!,
            style: const TextStyle(color: AppColors.negativeText, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        if (m.waiters.isEmpty)
          Text(
            'Nuk ka kamarierë të regjistruar.',
            style: TextStyle(color: AppColors.lightGreenText),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle(0.12)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: m.waiters.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: AppColors.borderSubtle(0.08)),
              itemBuilder: (context, i) {
                final w = m.waiters[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.lightGreenBg,
                    child: Text(
                      w.name.isNotEmpty ? w.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  title: Text(
                    w.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  subtitle: Text(
                    'PIN: ${w.pin}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.lightGreenText,
                      letterSpacing: 2,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => m.removeWaiterAt(i),
                    color: AppColors.negativeText,
                  ),
                );
              },
            ),
          ),
      ],
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

  static double _sumType(Iterable<ExpenseRow> rows, String type) =>
      rows.where((e) => e.type == type).fold<double>(0, (s, e) => s + e.amount);

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

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final filtered = _filtered(m.expenses);
    final totalAll = m.expenses.fold<double>(0, (s, e) => s + e.amount);
    final totalFiltered = filtered.fold<double>(0, (s, e) => s + e.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 32,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shpenzime & rroga',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ndjek transaksionet, filtro sipas llojit, kërko dhe eksporto raport PDF.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ExpenseKpiCard(
              title: 'Total i regjistruar',
              value: '\$${totalAll.toStringAsFixed(2)}',
              subtitle: '${m.expenses.length} transaksione',
              icon: Icons.savings_outlined,
            ),
            _ExpenseKpiCard(
              title: 'Në pamje (filtër)',
              value: '\$${totalFiltered.toStringAsFixed(2)}',
              subtitle: '${filtered.length} rreshta',
              icon: Icons.visibility_outlined,
            ),
            _ExpenseKpiCard(
              title: 'Rrogë (kumulativ)',
              value: '\$${_sumType(m.expenses, 'Rrogë').toStringAsFixed(2)}',
              icon: Icons.payments_outlined,
            ),
            _ExpenseKpiCard(
              title: 'Shpenzime (kumulativ)',
              value: '\$${_sumType(m.expenses, 'Shpenzim').toStringAsFixed(2)}',
              icon: Icons.shopping_cart_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ExpenseTypeDistributionBar(expenses: m.expenses),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppColors.borderSubtle(0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final wideToolbar = c.maxWidth >= 720;
                    final title = Text(
                      'Regjistri',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    );
                    final addBtn = FilledButton.icon(
                      onPressed: () => _openAddDialog(context),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Shto transaksion'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    );
                    final pdfBtn = OutlinedButton.icon(
                      onPressed: filtered.isEmpty
                          ? null
                          : () => _exportPdf(context, printDialog: false),
                      icon: const Icon(Icons.download_outlined, size: 20),
                      label: const Text('Shkarko PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    );
                    final printBtn = OutlinedButton.icon(
                      onPressed: filtered.isEmpty
                          ? null
                          : () => _exportPdf(context, printDialog: true),
                      icon: const Icon(Icons.print_outlined, size: 20),
                      label: const Text('Printo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGreenText,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    );
                    if (wideToolbar) {
                      return Row(
                        children: [
                          title,
                          const Spacer(),
                          addBtn,
                          const SizedBox(width: 10),
                          pdfBtn,
                          const SizedBox(width: 8),
                          printBtn,
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [addBtn, pdfBtn, printBtn],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'PDF përfshin vetëm rreshtat që shfaqen sipas filtrave aktualë.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.lightGreenText,
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, c) {
                    final narrow = c.maxWidth < 720;
                    return Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: narrow ? double.infinity : 260,
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Kërko përshkrim, lloj ose shumë…',
                              prefixIcon: const Icon(Icons.search, size: 22),
                              filled: true,
                              fillColor: AppColors.beige,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.borderSubtle(0.15),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.borderSubtle(0.15),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primaryGreen,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: narrow ? double.infinity : 200,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Lloji',
                              filled: true,
                              fillColor: AppColors.beige,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.borderSubtle(0.15),
                                ),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _typeFilter,
                                isExpanded: true,
                                hint: const Text('Të gjitha'),
                                items: const [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Të gjitha'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Shpenzim',
                                    child: Text('Shpenzim'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Rrogë',
                                    child: Text('Rrogë'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Bonus',
                                    child: Text('Bonus'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _typeFilter = v),
                              ),
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<_ExpSort>(
                            segments: const [
                              ButtonSegment(
                                value: _ExpSort.dateDesc,
                                label: Text('Data ↓'),
                                tooltip: 'Data më e re fillim',
                              ),
                              ButtonSegment(
                                value: _ExpSort.dateAsc,
                                label: Text('Data ↑'),
                              ),
                              ButtonSegment(
                                value: _ExpSort.amountDesc,
                                label: Text('Shuma ↓'),
                              ),
                              ButtonSegment(
                                value: _ExpSort.amountAsc,
                                label: Text('Shuma ↑'),
                              ),
                            ],
                            selected: {_sort},
                            onSelectionChanged: (s) =>
                                setState(() => _sort = s.first),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (filtered.isEmpty)
                  _ExpensesEmptyState(onAdd: () => _openAddDialog(context))
                else
                  LayoutBuilder(
                    builder: (context, c) {
                      final tableWidth = math.max(560.0, c.maxWidth);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: tableWidth,
                            maxWidth: tableWidth,
                          ),
                          child: _ExpensesDataTable(
                            rows: filtered,
                            fmtDate: _fmtDate,
                            typeColor: _typeAccent,
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

  Color _typeAccent(String type) {
    switch (type) {
      case 'Rrogë':
        return AppColors.primaryGreen;
      case 'Bonus':
        return AppColors.darkerGreenHover;
      case 'Shpenzim':
        return AppColors.mediumGreenText;
      default:
        return AppColors.lightGreenText;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

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

class _ExpenseKpiCard extends StatelessWidget {
  const _ExpenseKpiCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 212,
      child: Card(
        elevation: 0,
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderSubtle(0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primaryGreen, size: 22),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'KPI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: AppColors.lightGreenText),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreenText,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mediumGreenText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseTypeDistributionBar extends StatelessWidget {
  const _ExpenseTypeDistributionBar({required this.expenses});

  final List<ExpenseRow> expenses;

  @override
  Widget build(BuildContext context) {
    final roga = _ExpensesPanelState._sumType(expenses, 'Rrogë');
    final shpenz = _ExpensesPanelState._sumType(expenses, 'Shpenzim');
    final bonus = _ExpensesPanelState._sumType(expenses, 'Bonus');
    final t = roga + shpenz + bonus;
    if (t <= 0) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderSubtle(0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.pie_chart_outline, color: AppColors.lightGreenText),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Shto transaksione për të parë shpërndarjen sipas llojit (Rrogë / Shpenzim / Bonus).',
                  style: TextStyle(color: AppColors.mediumGreenText),
                ),
              ),
            ],
          ),
        ),
      );
    }

    int flex(double part) => math.max(1, (part / t * 1000).round());

    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shpërndarja sipas llojit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Përqindje e shumës totale të regjistruar',
              style: TextStyle(fontSize: 12, color: AppColors.lightGreenText),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    Expanded(
                      flex: flex(roga),
                      child: Container(color: AppColors.primaryGreen),
                    ),
                    Expanded(
                      flex: flex(shpenz),
                      child: Container(
                        color: AppColors.mediumGreenText.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: flex(bonus),
                      child: Container(color: AppColors.darkerGreenHover),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _legendDot(AppColors.primaryGreen, 'Rrogë', roga, t),
                _legendDot(
                  AppColors.mediumGreenText.withValues(alpha: 0.65),
                  'Shpenzim',
                  shpenz,
                  t,
                ),
                _legendDot(AppColors.darkerGreenHover, 'Bonus', bonus, t),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _legendDot(Color c, String label, double amt, double total) {
    final pct = total > 0 ? (amt / total * 100) : 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '$label · ${pct.toStringAsFixed(0)}% (\$${amt.toStringAsFixed(2)})',
          style: TextStyle(fontSize: 12, color: AppColors.mediumGreenText),
        ),
      ],
    );
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

class _ExpensesDataTable extends StatelessWidget {
  const _ExpensesDataTable({
    required this.rows,
    required this.fmtDate,
    required this.typeColor,
    required this.onDelete,
  });

  final List<ExpenseRow> rows;
  final String Function(DateTime) fmtDate;
  final Color Function(String) typeColor;
  final void Function(ExpenseRow) onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(color: AppColors.lightGreenBg),
            child: const Row(
              children: [
                SizedBox(width: 120, child: Text('Lloji')),
                Expanded(
                  child: Text(
                    'Përshkrimi',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Shuma',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: 110, child: Text('Data')),
                SizedBox(width: 52),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderSubtle(0.08),
            ),
            itemBuilder: (context, i) {
              final e = rows[i];
              final stripe = i.isEven ? AppColors.white : AppColors.beige;
              return Material(
                color: stripe,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            side: BorderSide(color: typeColor(e.type)),
                            backgroundColor: typeColor(
                              e.type,
                            ).withValues(alpha: 0.12),
                            label: Text(
                              e.type,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: typeColor(e.type),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8, top: 2),
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
                        width: 100,
                        child: Text(
                          '\$${e.amount.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            fmtDate(e.date),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mediumGreenText,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          tooltip: 'Fshi rreshtin',
                          icon: Icon(
                            Icons.delete_outline,
                            color: AppColors.negativeText.withValues(
                              alpha: 0.85,
                            ),
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
  int _tab = 0;

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

  @override
  Widget build(BuildContext context) {
    final m = widget.m;

    // Revenue (shitjet nga kamarierët)
    final revDay = m.revenueToday;
    final revWeek = m.revenueThisWeek;
    final revMonth = m.revenueThisMonth;

    // Expenses (shpenzimet) për periudhën
    final expDay = m.expensesToday;
    final expWeek = m.expensesThisWeek;
    final expMonth = m.expensesThisMonth;

    // Profit = revenue – expenses
    final profDay = m.profitToday;
    final profWeek = m.profitThisWeek;
    final profMonth = m.profitThisMonth;

    final labels = ['Sot', 'Kjo javë', 'Ky muaj'];
    final revenues = [revDay, revWeek, revMonth];
    final expenses = [expDay, expWeek, expMonth];
    final profits = [profDay, profWeek, profMonth];

    // Normalise bar heights by the largest revenue value.
    final maxRev = revenues.fold(0.0, math.max);
    final norm = maxRev > 0
        ? revenues.map((v) => v / maxRev).toList()
        : [0.0, 0.0, 0.0];

    final selProfit = profits[_tab];
    final selRev = revenues[_tab];
    final selExp = expenses[_tab];
    final profitColor = selProfit >= 0
        ? AppColors.primaryGreen
        : AppColors.negativeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── header ────────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.trending_up,
                size: 32,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fitime & performanca',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fitimi real bazuar në shitjet e kamarierëve minus shpenzimet e regjistruara.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // ── KPI tiles ─────────────────────────────────────────────────────
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ProfitKpiTile(
              label: 'Fitim sot',
              value:
                  '${profDay >= 0 ? '' : '-'}€${profDay.abs().toStringAsFixed(2)}',
              icon: Icons.today_outlined,
              highlight: _tab == 0,
              positive: profDay >= 0,
              onTap: () => setState(() => _tab = 0),
            ),
            _ProfitKpiTile(
              label: 'Fitim kjo javë',
              value:
                  '${profWeek >= 0 ? '' : '-'}€${profWeek.abs().toStringAsFixed(2)}',
              icon: Icons.date_range_outlined,
              highlight: _tab == 1,
              positive: profWeek >= 0,
              onTap: () => setState(() => _tab = 1),
            ),
            _ProfitKpiTile(
              label: 'Fitim ky muaj',
              value:
                  '${profMonth >= 0 ? '' : '-'}€${profMonth.abs().toStringAsFixed(2)}',
              icon: Icons.calendar_month_outlined,
              highlight: _tab == 2,
              positive: profMonth >= 0,
              onTap: () => setState(() => _tab = 2),
            ),
            _ProfitKpiTile(
              label: 'Shitje totale (sesion)',
              value:
                  '€${m.waiterSales.values.fold(0.0, (s, v) => s + v).toStringAsFixed(2)}',
              icon: Icons.point_of_sale_outlined,
              highlight: false,
              positive: true,
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── detail card ───────────────────────────────────────────────────
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppColors.borderSubtle(0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // period selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    segments: [
                      for (var i = 0; i < 3; i++)
                        ButtonSegment<int>(value: i, label: Text(labels[i])),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                ),
                const SizedBox(height: 24),

                // big profit number
                Text(
                  'Fitimi — ${labels[_tab]}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mediumGreenText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${selProfit >= 0 ? '' : '-'}€${selProfit.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    color: profitColor,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 20),

                // revenue vs expenses row
                Row(
                  children: [
                    Expanded(
                      child: _ProfitStatCell(
                        label: 'Shitje',
                        value: '€${selRev.toStringAsFixed(2)}',
                        icon: Icons.arrow_upward_rounded,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfitStatCell(
                        label: 'Shpenzime',
                        value: '€${selExp.toStringAsFixed(2)}',
                        icon: Icons.arrow_downward_rounded,
                        color: AppColors.negativeText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfitStatCell(
                        label: 'Transaksione',
                        value:
                            '${m.salesHistory.where(_inPeriod(_tab)).length}',
                        icon: Icons.receipt_outlined,
                        color: AppColors.mediumGreenText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // bar chart (revenue per period)
                Text(
                  'Shitjet sipas periudhës',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.lightGreenText,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '€${revenues[i].toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkGreenText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      width: 40,
                                      height: 12 + norm[i] * 72,
                                      decoration: BoxDecoration(
                                        color: _tab == i
                                            ? AppColors.primaryGreen
                                            : AppColors.primaryGreen.withValues(
                                                alpha: 0.35,
                                              ),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(8),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  labels[i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.mediumGreenText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // ── breakdown table ────────────────────────────────────────────────
        Card(
          elevation: 0,
          color: AppColors.beige,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.borderSubtle(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: [
                    _profitTblHead('Metrika'),
                    _profitTblHead('Vlera', right: true),
                  ],
                ),
                _profitTblRow('Shitje sot', '€${revDay.toStringAsFixed(2)}'),
                _profitTblRow(
                  'Shitje kjo javë',
                  '€${revWeek.toStringAsFixed(2)}',
                ),
                _profitTblRow(
                  'Shitje ky muaj',
                  '€${revMonth.toStringAsFixed(2)}',
                ),
                _profitTblRow('Shpenzime sot', '€${expDay.toStringAsFixed(2)}'),
                _profitTblRow(
                  'Shpenzime kjo javë',
                  '€${expWeek.toStringAsFixed(2)}',
                ),
                _profitTblRow(
                  'Shpenzime ky muaj',
                  '€${expMonth.toStringAsFixed(2)}',
                ),
                _profitTblRow(
                  'Fitim sot',
                  '${profDay >= 0 ? '' : '-'}€${profDay.abs().toStringAsFixed(2)}',
                ),
                _profitTblRow(
                  'Fitim kjo javë',
                  '${profWeek >= 0 ? '' : '-'}€${profWeek.abs().toStringAsFixed(2)}',
                ),
                _profitTblRow(
                  'Fitim ky muaj',
                  '${profMonth >= 0 ? '' : '-'}€${profMonth.abs().toStringAsFixed(2)}',
                ),
                _profitTblRow(
                  'Transaksione gjithsej',
                  '${m.salesHistory.length}',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Returns a predicate that checks whether a [SaleRow] falls in period [tab].
  bool Function(SaleRow) _inPeriod(int tab) {
    final now = DateTime.now();
    final DateTime from;
    switch (tab) {
      case 1:
        from = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        break;
      case 2:
        from = DateTime(now.year, now.month, 1);
        break;
      default:
        from = DateTime(now.year, now.month, now.day);
    }
    return (s) => !s.timestamp.isBefore(from);
  }

  static Widget _profitTblHead(String s, {bool right = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        s,
        textAlign: right ? TextAlign.right : TextAlign.start,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.lightGreenText,
        ),
      ),
    );
  }

  static TableRow _profitTblRow(String a, String b) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            a,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.darkGreenText,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            b,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfitKpiTile extends StatelessWidget {
  const _ProfitKpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.highlight,
    required this.positive,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;
  final bool positive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final valueColor = positive
        ? AppColors.primaryGreen
        : AppColors.negativeText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: highlight ? AppColors.lightGreenBg : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight
                  ? AppColors.primaryGreen.withValues(alpha: 0.45)
                  : AppColors.borderSubtle(0.12),
              width: highlight ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: valueColor, size: 22),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.lightGreenText),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Prek për të zgjedhur',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.mediumGreenText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfitStatCell extends StatelessWidget {
  const _ProfitStatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mediumGreenText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
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
      SnackBar(
        content: const Text(
          'CSV u kopjua në clipboard — ngjite në Excel ose në një skedar .csv',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryGreen,
      ),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eksport CSV'),
        content: SizedBox(
          width: 480,
          height: 280,
          child: SingleChildScrollView(
            child: SelectableText(
              csv,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mbyll'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final recentExp = List<ExpenseRow>.from(m.expenses)
      ..sort((a, b) => b.date.compareTo(a.date));
    final preview = recentExp.take(8).toList();
    final sales = m.employeeSalesSorted.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 32,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Raporte & eksporte',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gjenero PDF përmbledhës, printo ose eksporto shpenzimet si CSV për Excel.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ReportStatChip(
              icon: Icons.picture_as_pdf_outlined,
              label: 'PDF',
              value: 'Raport i plotë',
            ),
            _ReportStatChip(
              icon: Icons.table_chart_outlined,
              label: 'CSV',
              value: '${m.expenses.length} rreshta',
            ),
            _ReportStatChip(
              icon: Icons.groups_outlined,
              label: 'Kamarierë',
              value: '${m.waiters.length}',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppColors.borderSubtle(0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Veprime',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGreenText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PDF përfshin fitime (demo), tavolina, shift, shpenzime dhe shitje stafi.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mediumGreenText,
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth > 560;
                    if (wide) {
                      return Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => _pdf(printOnly: false),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Shkarko PDF'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () => _exportCsv(context),
                            icon: const Icon(Icons.table_chart_outlined),
                            label: const Text('Eksport CSV (Excel)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () => _pdf(printOnly: true),
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('Printo PDF'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.darkGreenText,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _pdf(printOnly: false),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Shkarko PDF'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _exportCsv(context),
                          icon: const Icon(Icons.table_chart_outlined),
                          label: const Text('Eksport CSV'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pdf(printOnly: true),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Printo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.darkGreenText,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final twoCol = c.maxWidth > 900;
            final left = Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.borderSubtle(0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Parapamje shpenzimesh (8 të fundit)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (preview.isEmpty)
                      Text(
                        'Nuk ka shpenzime. Shto nga seksioni Shpenzime.',
                        style: TextStyle(color: AppColors.mediumGreenText),
                      )
                    else
                      ...preview.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.darkGreenText,
                                  ),
                                ),
                              ),
                              Text(
                                '\$${e.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkGreenText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
            final right = Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.borderSubtle(0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.point_of_sale_outlined,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Shitje stafi (sesion)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (sales.isEmpty)
                      Text(
                        'Ende pa shitje të regjistruara.',
                        style: TextStyle(color: AppColors.mediumGreenText),
                      )
                    else
                      ...sales.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.darkGreenText,
                                  ),
                                ),
                              ),
                              Text(
                                '\$${e.value.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
            if (twoCol) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 16),
                  Expanded(child: right),
                ],
              );
            }
            return Column(children: [left, const SizedBox(height: 16), right]);
          },
        ),
      ],
    );
  }
}

class _ReportStatChip extends StatelessWidget {
  const _ReportStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppColors.lightGreenText),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
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
    final top = m.topEmployee;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('6. Realizimi sipas puntorëve'),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: AppColors.lightGreenBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 48,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Më shumë realizim',
                      style: TextStyle(color: AppColors.mediumGreenText),
                    ),
                    Text(
                      top.key,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    Text(
                      '\$${top.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (m.employeeSalesSorted.isEmpty)
          Text(
            'Asnjë shitje e regjistruar ende.',
            style: TextStyle(color: AppColors.lightGreenText),
          )
        else ...[
          const Text(
            'Të gjithë:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          ...m.employeeSalesSorted.map(
            (e) => ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: AppColors.lightGreenBg,
                radius: 16,
                child: Text(
                  e.key.isNotEmpty ? e.key[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              title: Text(e.key),
              trailing: Text(
                '\$${e.value.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ),
        ],
      ],
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

  @override
  void initState() {
    super.initState();
    _count = widget.m.tableCount.toDouble();
    _perRow = widget.m.tablesPerRow.toDouble();
    widget.m.addListener(_onM);
  }

  void _onM() => setState(() {});

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
    final rows = (n / pr).ceil();
    final occupied = m.cashierTables.where((t) => t.occupied).length;
    final openTotal = m.cashierTables.fold<double>(
      0,
      (s, t) => s + (t.currentTotal ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                size: 32,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tavolinat & rrjeti i kasës',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ruajtja rindërton listën 1…N. Kamarieri mund të shtojë tavolina me “+” nga ekrani i tavolinave.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _TableStatPill(
              icon: Icons.event_seat_outlined,
              label: 'Tavolina (aktualisht)',
              value: '${m.cashierTables.length}',
            ),
            _TableStatPill(
              icon: Icons.event_available_outlined,
              label: 'Të zëna',
              value: '$occupied',
            ),
            _TableStatPill(
              icon: Icons.event_busy_outlined,
              label: 'Të lira',
              value: '${m.cashierTables.length - occupied}',
            ),
            _TableStatPill(
              icon: Icons.receipt_outlined,
              label: 'Hapësirë e hapur',
              value: '\$${openTotal.toStringAsFixed(2)}',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppColors.borderSubtle(0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cilësimet e rrjetit',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGreenText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Parapamja poshtë përdor vlerat e zgjedhura (para ruajtjes). Rreshta të parashikuar në grid: $rows.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mediumGreenText,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Numri i tavolinave',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                    inactiveTrackColor: AppColors.borderSubtle(0.15),
                    thumbColor: AppColors.primaryGreen,
                    overlayColor: AppColors.primaryGreen.withValues(
                      alpha: 0.12,
                    ),
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
                    Text(
                      'Tavolina për rresht',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                    inactiveTrackColor: AppColors.borderSubtle(0.15),
                    thumbColor: AppColors.primaryGreen,
                    overlayColor: AppColors.primaryGreen.withValues(
                      alpha: 0.12,
                    ),
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
                FilledButton.icon(
                  onPressed: () {
                    m.setTableLayout(
                      count: _count.round(),
                      perRow: _perRow.round(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Cilësimet e tavolinave u ruajtën.',
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Ruaj cilësimet'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Parapamje e shpërndarjes ($n tavolina · $pr kolona)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.darkGreenText,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: AppColors.beige,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.borderSubtle(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, c) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: pr.clamp(2, 12),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: n,
                  itemBuilder: (context, i) {
                    final id = i + 1;
                    TableInfo? info;
                    try {
                      info = m.cashierTables.firstWhere((t) => t.id == id);
                    } catch (_) {
                      info = null;
                    }
                    final occ = info?.occupied ?? false;
                    return Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: occ
                            ? AppColors.primaryGreen.withValues(alpha: 0.2)
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: occ
                              ? AppColors.primaryGreen
                              : AppColors.borderSubtle(0.15),
                          width: occ ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$id',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                          if (occ)
                            Text(
                              '\$${(info?.currentTotal ?? 0).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Statusi aktual i tavolinave',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.darkGreenText,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.borderSubtle(0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 520),
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(
                    AppColors.lightGreenBg,
                  ),
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Gjendja')),
                    DataColumn(label: Text('Total'), numeric: true),
                  ],
                  rows: [
                    for (final t in m.cashierTables)
                      DataRow(
                        cells: [
                          DataCell(Text('${t.id}')),
                          DataCell(
                            Row(
                              children: [
                                Icon(
                                  t.occupied
                                      ? Icons.circle
                                      : Icons.circle_outlined,
                                  size: 12,
                                  color: t.occupied
                                      ? AppColors.primaryGreen
                                      : AppColors.lightGreenText,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.occupied ? 'E zënë' : 'E lirë',
                                  style: TextStyle(
                                    color: t.occupied
                                        ? AppColors.darkGreenText
                                        : AppColors.mediumGreenText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              t.currentTotal != null
                                  ? '\$${t.currentTotal!.toStringAsFixed(2)}'
                                  : '—',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TableStatPill extends StatelessWidget {
  const _TableStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppColors.lightGreenText),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
            ],
          ),
        ],
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('11. Pagat & Avans'),
        const SizedBox(height: 12),
        _buildMonthNav(),
        const SizedBox(height: 16),
        if (m.waiters.isEmpty)
          _buildEmptyState()
        else
          ...m.waiters.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WaiterSummaryCard(
                waiter: w,
                m: m,
                viewMonth: _viewMonth,
                onTap: () => setState(() => _selectedWaiter = w),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMonthNav() {
    return Row(
      children: [
        IconButton(
          onPressed: () => setState(
            () => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1),
          ),
          icon: const Icon(Icons.chevron_left),
          color: AppColors.primaryGreen,
        ),
        Text(
          '${_monthNames[_viewMonth.month - 1]} ${_viewMonth.year}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.darkGreenText,
          ),
        ),
        IconButton(
          onPressed: () => setState(
            () => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1),
          ),
          icon: const Icon(Icons.chevron_right),
          color: AppColors.primaryGreen,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle()),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.badge_outlined,
              size: 48,
              color: AppColors.lightGreenText,
            ),
            const SizedBox(height: 12),
            Text(
              'Nuk ka kamarierë të regjistruar.',
              style: TextStyle(color: AppColors.mediumGreenText, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Shko te "Kamarierët" për të shtuar punonjës.',
              style: TextStyle(color: AppColors.lightGreenText, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────── Waiter Summary Card (list view) ─────────────────────

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

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle()),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                radius: 24,
                child: Text(
                  waiter.name.isNotEmpty ? waiter.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiter.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rate > 0
                          ? '€${rate.toStringAsFixed(2)}/ditë'
                          : 'Pa pagë të caktuar',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mediumGreenText,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(
                    '$worked ditë',
                    Icons.calendar_today_outlined,
                    AppColors.primaryGreen,
                  ),
                  _chip(
                    '€${gross.toStringAsFixed(0)} bruto',
                    Icons.account_balance_wallet_outlined,
                    AppColors.darkGreenText,
                  ),
                  if (totalAdv > 0)
                    _chip(
                      '-€${totalAdv.toStringAsFixed(0)} avans',
                      Icons.money_off_outlined,
                      AppColors.negativeText,
                    ),
                  _chip(
                    '€${net.toStringAsFixed(0)} mbetet',
                    Icons.check_circle_outline,
                    net >= 0 ? AppColors.primaryGreen : AppColors.negativeText,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.mediumGreenText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => widget.onMonthChanged(
                      DateTime(month.year, month.month - 1),
                    ),
                    icon: const Icon(Icons.chevron_left),
                    color: AppColors.primaryGreen,
                  ),
                  Text(
                    '${_monthNames[month.month - 1]} ${month.year}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
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
                          prefixText: '€',
                        ),
                        onSubmitted: (_) => _saveRate(),
                      ),
                    )
                  else
                    Text(
                      rate > 0
                          ? '€${rate.toStringAsFixed(2)}/ditë'
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
                    '€${gross.toStringAsFixed(2)}',
                    Icons.account_balance_wallet_outlined,
                  ),
                  _payKpi(
                    'Avanse',
                    '€${totalAdv.toStringAsFixed(2)}',
                    Icons.money_off_outlined,
                    negative: true,
                  ),
                  _payKpi(
                    'Mbetet',
                    '€${net.toStringAsFixed(2)}',
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
              '€${a.amount.toStringAsFixed(2)}',
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
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.darkGreenText,
    ),
  );
}

InputDecoration _inputDeco(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.borderVisible(0.2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.borderVisible(0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
