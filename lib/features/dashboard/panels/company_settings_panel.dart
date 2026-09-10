import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../manager/manager_data.dart';
import '../../../services/printer_settings_store.dart';
import '../../../services/windows_printers_service.dart';
import '../../../services/activation_service.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../widgets/settings/settings_card.dart';
import '../widgets/settings/settings_check_tile.dart';

class CompanySettingsPanel extends StatefulWidget {
  const CompanySettingsPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<CompanySettingsPanel> createState() => _CompanySettingsPanelState();
}

class _CompanySettingsPanelState extends State<CompanySettingsPanel> {
  final _nameCtrl = TextEditingController();
  String? _errorMsg;
  List<String> _printers = const [];
  String _selectedPrinter = '';
  bool _loadingPrinters = true;

  // ── admin PIN change ───────────────────────────────────────────────────────
  final _currentPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final _licenseKeyCtrl = TextEditingController();
  String? _pinErrorMsg;
  bool _pinChanging = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.m.companyName ?? '';
    widget.m.addListener(_onM);
    _loadPrinters();
  }

  void _onM() => setState(() {});

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    _nameCtrl.dispose();
    _currentPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _licenseKeyCtrl.dispose();
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

  Future<void> _replaceLicenseKey() async {
    final key = _licenseKeyCtrl.text.trim();
    if (key.isEmpty) return;
    try {
      final license = await ActivationService.instance.replaceLocalLicenseKey(
        key,
      );
      _licenseKeyCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Licenca u vazhdua deri më ${license.expiresAt.toLocal().toString().split('.').first}.',
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.negativeText,
        ),
      );
    }
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

  Future<void> _changeAdminPin() async {
    final currentPin = _currentPinCtrl.text.trim();
    final newPin = _newPinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();

    if (currentPin.isEmpty || newPin.isEmpty || confirmPin.isEmpty) {
      setState(() => _pinErrorMsg = 'Të gjitha fushat janë të detyrueshme.');
      return;
    }
    if (newPin.length < 4 || !RegExp(r'^\d+$').hasMatch(newPin)) {
      setState(
        () => _pinErrorMsg =
            'PIN-i i ri: minimum 4 shifra, vetëm numra (pa kufi maksimal).',
      );
      return;
    }
    if (newPin != confirmPin) {
      setState(() => _pinErrorMsg = 'PIN-i i ri dhe konfirmimi nuk përputhen.');
      return;
    }

    setState(() {
      _pinChanging = true;
      _pinErrorMsg = null;
    });

    final valid = await widget.m.canAccessManagerDashboard(currentPin);
    if (!mounted) return;

    if (!valid) {
      setState(() {
        _pinErrorMsg = 'PIN-i aktual është i gabuar.';
        _pinChanging = false;
      });
      return;
    }

    await widget.m.setAdminPin(newPin);
    if (!mounted) return;

    _currentPinCtrl.clear();
    _newPinCtrl.clear();
    _confirmPinCtrl.clear();
    setState(() {
      _pinChanging = false;
      _pinErrorMsg = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN-i i administratorit u ndryshua me sukses.'),
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
              style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
            ),
          ],
        ),
        const SizedBox(height: 24),

        SettingsCard(
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
                decoration: inputDeco('Shkruaj emrin e biznesit'),
                style: const TextStyle(fontSize: 15),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
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

        SettingsCard(
          icon: Icons.vpn_key_rounded,
          title: 'Licenca',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Keni marrë një key të ri nga Developer Mode? Vendoseni këtu për ta vazhduar licencën.',
                style: TextStyle(color: AppColors.mediumGreenText),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _licenseKeyCtrl,
                decoration: inputDeco(
                  'POS-LOCAL-...',
                ).copyWith(prefixIcon: const Icon(Icons.key_rounded)),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _replaceLicenseKey,
                icon: const Icon(Icons.autorenew_rounded),
                label: const Text('Vazhdo licencën me key'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        SettingsCard(
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
                              decoration: inputDeco('Zgjidh printerin'),
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
              SettingsCheckTile(
                label: 'Printo automatikisht faturat pas pagesës',
              ),
              const SizedBox(height: 8),
              SettingsCheckTile(
                label: 'Dërgo porositë automatikisht te printeri i kuzhinës',
              ),
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
        const SizedBox(height: 20),

        SettingsCard(
          icon: Icons.lock_outline,
          title: 'Ndrysho PIN-in e Administratorit',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'PIN Aktual',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGreenText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _currentPinCtrl,
                obscureText: true,
                obscuringCharacter: '•',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: inputDeco(
                  'Shkruaj PIN-in aktual',
                ).copyWith(counterText: ''),
                style: const TextStyle(fontSize: 15, letterSpacing: 4),
              ),
              const SizedBox(height: 16),
              const Text(
                'PIN-i i Ri',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGreenText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newPinCtrl,
                obscureText: true,
                obscuringCharacter: '•',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: inputDeco(
                  'Minimum 4 shifra, vetëm numra',
                ).copyWith(counterText: ''),
                style: const TextStyle(fontSize: 15, letterSpacing: 4),
              ),
              const SizedBox(height: 16),
              const Text(
                'Konfirmo PIN-in e Ri',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGreenText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPinCtrl,
                obscureText: true,
                obscuringCharacter: '•',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: inputDeco(
                  'Ripërsërit PIN-in e ri',
                ).copyWith(counterText: ''),
                style: const TextStyle(fontSize: 15, letterSpacing: 4),
                onSubmitted: (_) => _pinChanging ? null : _changeAdminPin(),
              ),
              if (_pinErrorMsg != null) ...[
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
                          _pinErrorMsg!,
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _pinChanging ? null : _changeAdminPin,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.primaryGreen
                            .withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: _pinChanging
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Text('Ndrysho PIN-in'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      _currentPinCtrl.clear();
                      _newPinCtrl.clear();
                      _confirmPinCtrl.clear();
                      setState(() => _pinErrorMsg = null);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkGreenText,
                      side: const BorderSide(color: AppColors.lightGreenBorder),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
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
          ),
        ),

        const SizedBox(height: 24),

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
}
