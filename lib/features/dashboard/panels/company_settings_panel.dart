import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../manager/manager_data.dart';
import '../../../services/printer_settings_store.dart';
import '../../../services/windows_printers_service.dart';
import '../../../services/activation_service.dart';
import '../../../services/app_language_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_mode_controller.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../../../shared/widgets/panel_layout.dart';
import '../../../widgets/dashboard/app_button.dart';
import '../widgets/settings/settings_card.dart';
import '../widgets/settings/settings_check_tile.dart';
import '../widgets/settings/language_option_tile.dart';
import '../widgets/settings/theme_mode_picker.dart';

class CompanySettingsPanel extends StatefulWidget {
  const CompanySettingsPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<CompanySettingsPanel> createState() => _CompanySettingsPanelState();
}

class _CompanySettingsPanelState extends State<CompanySettingsPanel> {
  final _language = AppLanguageService.instance;
  final _nameCtrl = TextEditingController();
  String? _errorMsg;
  List<String> _printers = const [];
  String _selectedPrinter = '';
  bool _loadingPrinters = true;

  final _currentPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final _licenseKeyCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _pinErrorMsg;
  bool _pinChanging = false;

  @override
  void initState() {
    super.initState();
    _syncFromManager();
    widget.m.addListener(_onM);
    _loadPrinters();
  }

  void _syncFromManager() {
    _nameCtrl.text = widget.m.companyName ?? '';
    _footerCtrl.text = widget.m.receiptFooter;
    _addressCtrl.text = widget.m.businessAddress ?? '';
    _phoneCtrl.text = widget.m.businessPhone ?? '';
  }

  void _onM() => setState(() {});

  Future<void> _setLanguage(AppLanguage language) async {
    await _language.setLanguage(language);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    _nameCtrl.dispose();
    _currentPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _licenseKeyCtrl.dispose();
    _footerCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error
            ? AppColors.negativeText
            : AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _saveCompany() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMsg = 'Emri i kompanisë është i detyrueshëm.');
      return;
    }
    await widget.m.saveCompanyName(name);
    setState(() => _errorMsg = null);
    _toast('Emri i biznesit u ruajt.');
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
      _toast(
        'Licenca u vazhdua deri më ${license.expiresAt.toLocal().toString().split('.').first}.',
      );
    } catch (error) {
      if (!mounted) return;
      _toast(error.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _savePrinter(String printerName) async {
    await PrinterSettingsStore.saveSelectedPrinterName(printerName);
    if (!mounted) return;
    setState(() => _selectedPrinter = printerName);
    _toast('Printeri u zgjodh: $printerName');
  }

  Future<void> _saveReceipt() async {
    await widget.m.saveEscPosSettings(
      receiptFooter: _footerCtrl.text.trim().isEmpty
          ? 'Ju Faleminderit!'
          : _footerCtrl.text.trim(),
      businessAddress: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      businessPhone: _phoneCtrl.text.trim().isEmpty
          ? null
          : _phoneCtrl.text.trim(),
    );
    _toast('Cilësimet e faturës u ruajtën.');
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
        () => _pinErrorMsg = 'PIN-i i ri: minimum 4 shifra, vetëm numra.',
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
    _toast('PIN-i i administratorit u ndryshua.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          icon: Icons.tune_rounded,
          title: _language.t('Cilësimet e kompanisë', 'Company settings'),
          subtitle: _language.t(
            'Gjithçka që ndikon te stafi, printeri dhe faturat — e ndarë sipas kartave.',
            'Everything affecting staff, printing and receipts — grouped into cards.',
          ),
        ),

        PanelSectionLabel(
          text: _language.t('Biznesi dhe pamja', 'Business & appearance'),
        ),
        PanelColumns(left: _businessCard(), right: _languageCard()),
        const SizedBox(height: 16),
        _themeCard(),

        const SizedBox(height: 28),
        PanelSectionLabel(
          text: _language.t('Printimi', 'Printing'),
        ),
        PanelColumns(left: _printerCard(), right: _receiptCard()),

        const SizedBox(height: 28),
        PanelSectionLabel(
          text: _language.t('Licenca dhe siguria', 'Licence & security'),
        ),
        PanelColumns(left: _licenseCard(), right: _pinCard()),
      ],
    );
  }

  Widget _businessCard() {
    return SettingsCard(
      icon: Icons.storefront_outlined,
      title: 'Biznesi',
      subtitle: 'Emri që shfaqet në faturë dhe në dashboard.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Emri i biznesit'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: inputDeco('p.sh. Restorant Guri'),
            style: const TextStyle(fontSize: 15),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveCompany(),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _errorMsg!),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Ruaj emrin',
              icon: Icons.save_outlined,
              onPressed: _saveCompany,
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageCard() {
    return SettingsCard(
      icon: Icons.language_rounded,
      title: _language.t('Gjuha', 'Language'),
      subtitle: _language.t(
        'Gjuha e ekraneve të menaxherit dhe stafit.',
        'Language used across manager and staff screens.',
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // Two columns of language tiles whenever the card is wide enough.
          final twoUp = c.maxWidth >= 420;
          final tiles = [
            for (final lang in AppLanguage.values)
              LanguageOptionTile(
                language: lang,
                selected: _language.language == lang,
                onTap: () => _setLanguage(lang),
              ),
          ];

          if (!twoUp) {
            return Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  tiles[i],
                ],
              ],
            );
          }

          return Column(
            children: [
              for (var i = 0; i < tiles.length; i += 2) ...[
                if (i > 0) const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: tiles[i]),
                    const SizedBox(width: 8),
                    if (i + 1 < tiles.length)
                      Expanded(child: tiles[i + 1])
                    else
                      const Spacer(),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _themeCard() {
    return ListenableBuilder(
      listenable: ThemeModeController.instance,
      builder: (context, _) {
        final isDark = ThemeModeController.instance.isDark;
        return SettingsCard(
          icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          title: _language.t('Pamja e aplikacionit', 'Application appearance'),
          subtitle: isDark
              ? _language.t(
                  'Pamja e errët është aktive.',
                  'Dark appearance is active.',
                )
              : _language.t(
                  'Zgjidh pamjen e errët për përdorim më të rehatshëm.',
                  'Choose dark appearance for more comfortable use.',
                ),
          child: ThemeModePicker(
            isDark: isDark,
            onChanged: ThemeModeController.instance.setDark,
            lightLabel: _language.t('Modaliteti i ndritshëm', 'Light mode'),
            darkLabel: _language.t('Modaliteti i errët', 'Dark mode'),
          ),
        );
      },
    );
  }

  Widget _printerCard() {
    return SettingsCard(
      icon: Icons.print_outlined,
      title: 'Printeri',
      subtitle: 'Printeri i Windows për faturat POS.',
      trailing: IconButton(
        tooltip: 'Rifresko printerët',
        onPressed: _loadPrinters,
        icon: const Icon(Icons.refresh_outlined, size: 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Printer i zgjedhur'),
          const SizedBox(height: 8),
          if (_loadingPrinters)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
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
            Text(
              'Nuk u gjet asnjë printer Windows.',
              style: TextStyle(fontSize: 13, color: AppColors.lightGreenText),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _printers.contains(_selectedPrinter)
                  ? _selectedPrinter
                  : null,
              decoration: inputDeco('Zgjidh printerin'),
              isExpanded: true,
              items: _printers
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) _savePrinter(v);
              },
            ),
          const SizedBox(height: 14),
          SettingsCheckTile(
            label: 'ESC/POS',
            description: 'Printim i drejtpërdrejtë (i rekomanduar).',
            value: widget.m.useEscPos,
            onChanged: (v) => widget.m.saveEscPosSettings(useEscPos: v),
          ),
          const SizedBox(height: 8),
          SettingsCheckTile(
            label: 'Hap sirtarin e parave',
            description: 'Pas pagesës së suksesshme.',
            value: widget.m.cashDrawerEnabled,
            onChanged: (v) => widget.m.saveEscPosSettings(cashDrawerEnabled: v),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Gjerësia e letrës'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _paperChip(80)),
              const SizedBox(width: 8),
              Expanded(child: _paperChip(58)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paperChip(int mm) {
    final selected = widget.m.paperWidthMm == mm;
    return GestureDetector(
      onTap: () => widget.m.saveEscPosSettings(paperWidthMm: mm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightGreenBg : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primaryGreen
                : AppColors.lightGreenBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${mm}mm',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primaryGreen : AppColors.darkGreenText,
          ),
        ),
      ),
    );
  }

  Widget _receiptCard() {
    return SettingsCard(
      icon: Icons.receipt_long_outlined,
      title: 'Fatura',
      subtitle: 'Teksti që printohet në fund të faturës.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Adresa e biznesit'),
          const SizedBox(height: 8),
          TextField(
            controller: _addressCtrl,
            decoration: inputDeco('Rruga, qyteti'),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Telefoni'),
          const SizedBox(height: 8),
          TextField(controller: _phoneCtrl, decoration: inputDeco('+355 …')),
          const SizedBox(height: 12),
          _fieldLabel('Mesazhi në fund'),
          const SizedBox(height: 8),
          TextField(
            controller: _footerCtrl,
            decoration: inputDeco('Ju Faleminderit!'),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Ruaj faturën',
              icon: Icons.save_outlined,
              onPressed: _saveReceipt,
            ),
          ),
        ],
      ),
    );
  }

  Widget _licenseCard() {
    return SettingsCard(
      icon: Icons.vpn_key_rounded,
      title: 'Licenca',
      subtitle:
          'Nëse ke marrë një key të ri, vendose këtu për ta vazhduar licencën.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _licenseKeyCtrl,
            decoration: inputDeco(
              'POS-LOCAL-...',
            ).copyWith(prefixIcon: const Icon(Icons.key_rounded)),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Vazhdo licencën',
              icon: Icons.autorenew_rounded,
              onPressed: _replaceLicenseKey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinCard() {
    return SettingsCard(
      icon: Icons.lock_outline,
      title: 'Siguria e menaxherit',
      subtitle: 'Ndrysho PIN-in që hap dashboard-in e menaxherit.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final three = c.maxWidth >= 720;
              final fields = [
                _pinField(
                  _currentPinCtrl,
                  'PIN aktual',
                  'PIN-i që përdor tani',
                ),
                _pinField(_newPinCtrl, 'PIN i ri', 'Minimum 4 shifra'),
                _pinField(
                  _confirmPinCtrl,
                  'Konfirmo PIN-in',
                  'Ripërsërit PIN-in e ri',
                  onSubmitted: (_) => _pinChanging ? null : _changeAdminPin(),
                ),
              ];
              if (!three) {
                return Column(
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      fields[i],
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: fields[i]),
                  ],
                ],
              );
            },
          ),
          if (_pinErrorMsg != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _pinErrorMsg!),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              AppButton(
                label: 'Ndrysho PIN-in',
                icon: Icons.lock_reset_outlined,
                onPressed: _pinChanging ? null : _changeAdminPin,
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'Anulo',
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  _currentPinCtrl.clear();
                  _newPinCtrl.clear();
                  _confirmPinCtrl.clear();
                  setState(() => _pinErrorMsg = null);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.mediumGreenText,
      ),
    );
  }

  Widget _pinField(
    TextEditingController controller,
    String label,
    String hint, {
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: true,
          obscuringCharacter: '•',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: inputDeco(hint).copyWith(counterText: ''),
          style: const TextStyle(fontSize: 15, letterSpacing: 4),
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.negativeText.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.negativeText.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.negativeText,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.negativeText,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
