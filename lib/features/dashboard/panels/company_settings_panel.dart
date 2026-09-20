import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../manager/manager_data.dart';
import '../../../services/printer_settings_store.dart';
import '../../../services/windows_printers_service.dart';
import '../../../services/activation_license_controller.dart';
import '../../../services/activation_service.dart';
import '../../../models/sellix_license.dart';
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
import '../../../l10n/tr.dart';

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
  SellixBusinessProfile? _licensedBusiness;

  @override
  void initState() {
    super.initState();
    _syncFromManager();
    widget.m.addListener(_onM);
    _loadPrinters();
    _loadLicensedBusiness();
  }

  Future<void> _loadLicensedBusiness() async {
    final profile = await ActivationService.instance.storedBusinessProfile();
    if (!mounted) return;
    setState(() => _licensedBusiness = profile);
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
      setState(() => _errorMsg = tr.emriKompaniseEshteDetyrueshem);
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
      final result = await ActivationService.instance.replaceLocalLicenseKey(
        key,
      );
      _licenseKeyCtrl.clear();
      await widget.m.reload();
      if (!mounted) return;
      _syncFromManager();
      await _loadLicensedBusiness();
      final name = result.businessName ?? result.business?.name ?? '';
      _toast(
        name.isEmpty
            ? 'Licenca u përditësua.'
            : 'Biznesi u lidh: $name',
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
          ? tr.juFaleminderit
          : _footerCtrl.text.trim(),
      businessAddress: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      businessPhone: _phoneCtrl.text.trim().isEmpty
          ? null
          : _phoneCtrl.text.trim(),
    );
    _toast(tr.cilesimetFaturesURuajten);
  }

  Future<void> _changeAdminPin() async {
    final currentPin = _currentPinCtrl.text.trim();
    final newPin = _newPinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();

    if (currentPin.isEmpty || newPin.isEmpty || confirmPin.isEmpty) {
      setState(() => _pinErrorMsg = tr.gjithaFushatJaneDetyrueshme);
      return;
    }
    if (newPin.length < 4 || !RegExp(r'^\d+$').hasMatch(newPin)) {
      setState(
        () => _pinErrorMsg = tr.pinRiMinimum4ShifraVetem,
      );
      return;
    }
    if (newPin != confirmPin) {
      setState(() => _pinErrorMsg = tr.pinRiKonfirmimiNukPerputhen);
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
        _pinErrorMsg = tr.pinAktualEshteGabuar;
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
          title: _language.t(tr.cilesimetKompanise, 'Company settings'),
          subtitle: _language.t(
            tr.gjithckaNdikonStafiPrinteriFaturatNdare,
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
        PanelSectionLabel(text: _language.t('Printimi', 'Printing')),
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
      title: tr.biznesi,
      subtitle: tr.emriShfaqetFatureDashboard,
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
          if (_licensedBusiness != null) ...[
            const SizedBox(height: 16),
            _licensedRow('NUI', _licensedBusiness!.nui),
            _licensedRow('Sektori', _licensedBusiness!.sector),
            _licensedRow('Qyteti', _licensedBusiness!.city),
            _licensedRow('Nr. fiskal', _licensedBusiness!.fiscalNumber),
            _licensedRow('Nr. TVSH', _licensedBusiness!.vatNumber),
            _licensedRow('Email', _licensedBusiness!.email),
            _licensedRow('Kontakti', _licensedBusiness!.contactPerson),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: tr.ruajEmrin,
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
        tr.gjuhaEkraneveMenaxheritStafit,
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
                  tr.pamjaErretEshteAktive,
                  'Dark appearance is active.',
                )
              : _language.t(
                  tr.zgjidhPamjenErretPerdorimRehatshem,
                  'Choose dark appearance for more comfortable use.',
                ),
          child: ThemeModePicker(
            isDark: isDark,
            onChanged: ThemeModeController.instance.setDark,
            lightLabel: _language.t(tr.modalitetiNdritshem, 'Light mode'),
            darkLabel: _language.t(tr.modalitetiErret, 'Dark mode'),
          ),
        );
      },
    );
  }

  Widget _printerCard() {
    return SettingsCard(
      icon: Icons.print_outlined,
      title: tr.printeri,
      subtitle: tr.printeriWindowsFaturatPos,
      trailing: IconButton(
        tooltip: tr.rifreskoPrinteret,
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
              tr.nukUGjetAsnjePrinterWindows,
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
            description: tr.printimDrejtperdrejteRekomanduar,
            value: widget.m.useEscPos,
            onChanged: (v) => widget.m.saveEscPosSettings(useEscPos: v),
          ),
          const SizedBox(height: 8),
          SettingsCheckTile(
            label: tr.hapSirtarinParave,
            description: tr.pasPagesesSuksesshme,
            value: widget.m.cashDrawerEnabled,
            onChanged: (v) => widget.m.saveEscPosSettings(cashDrawerEnabled: v),
          ),
          const SizedBox(height: 14),
          _fieldLabel(tr.gjeresiaLetres),
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
      title: tr.fatura,
      subtitle: tr.tekstiPrintohetFundFatures,
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
          _fieldLabel(tr.mesazhiFund),
          const SizedBox(height: 8),
          TextField(
            controller: _footerCtrl,
            decoration: inputDeco(tr.juFaleminderit),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: tr.ruajFaturen,
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
      title: tr.licenca,
      subtitle:
          tr.neseKeMarreKeyRiVendose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _liveExpiryRow(),
          TextField(
            controller: _licenseKeyCtrl,
            decoration: inputDeco(
              'SLX-XXXXX-XXXXX-XXXXX-XXXXX',
            ).copyWith(prefixIcon: const Icon(Icons.key_rounded)),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: tr.vazhdoLicencen,
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
      title: tr.siguriaMenaxherit,
      subtitle: tr.ndryshoPinHapDashboardMenaxherit,
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
                  tr.pinPerdorTani,
                ),
                _pinField(_newPinCtrl, 'PIN i ri', 'Minimum 4 shifra'),
                _pinField(
                  _confirmPinCtrl,
                  'Konfirmo PIN-in',
                  tr.riperseritPinRi,
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
                label: tr.ndryshoPin,
                icon: Icons.lock_reset_outlined,
                onPressed: _pinChanging ? null : _changeAdminPin,
              ),
              const SizedBox(width: 10),
              AppButton(
                label: tr.anulo,
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

  /// Days left, straight off [ActivationLicenseController] — the license
  /// heartbeat writes each new expiry there, so an extension granted in the
  /// portal moves this number without a refresh or a restart.
  Widget _liveExpiryRow() {
    return ListenableBuilder(
      listenable: ActivationLicenseController.instance,
      builder: (context, _) {
        final days = ActivationLicenseController.instance.daysRemaining;
        if (days == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _licensedRow(tr.diteTeMbetura, '$days'),
        );
      },
    );
  }

  Widget _licensedRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.mediumGreenText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
          ),
        ],
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
          Icon(Icons.error_outline, color: AppColors.negativeText, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.negativeText, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
