import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../services/printer_settings_store.dart';
import '../../../services/windows_printers_service.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';

class CompanySettingsPanel extends StatefulWidget {
  const CompanySettingsPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<CompanySettingsPanel> createState() => _CompanySettingsPanelState();
}

class _CompanySettingsPanelState extends State<CompanySettingsPanel> {
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
                decoration: inputDeco('Shkruaj emrin e biznesit'),
                style: const TextStyle(fontSize: 15),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 20),
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
