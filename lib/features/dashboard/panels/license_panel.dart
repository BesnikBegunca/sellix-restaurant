import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../services/license_service.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../../../screens/login_screen.dart';
import '../../../screens/waiter_selection_screen.dart';

class LicensePanel extends StatefulWidget {
  const LicensePanel({
    super.key,
    required this.m,
    this.onLicenseRenewed,
  });

  final ManagerData m;
  final VoidCallback? onLicenseRenewed;

  @override
  State<LicensePanel> createState() => _LicensePanelState();
}

class _LicensePanelState extends State<LicensePanel> {
  bool _extending = false;

  @override
  void initState() {
    super.initState();
    widget.m.addListener(_onM);
  }

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    super.dispose();
  }

  void _onM() => setState(() {});

  Future<void> _extend(Duration duration, String label) async {
    setState(() => _extending = true);
    try {
      await widget.m.extendLicense(duration);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Licenca u zgjat me $label.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      if (widget.m.isLicenseValid) {
        widget.onLicenseRenewed?.call();
        if (widget.m.devModeSession && mounted) {
          widget.m.endDevModeSession();
          final mode = widget.m.loginMode;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => mode == 'NAMEMODE'
                  ? const WaiterSelectionScreen()
                  : const LoginScreen(),
            ),
            (_) => false,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _extending = false);
    }
  }

  Future<void> _openDevAuth() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DevAuthDialog(),
    );
    if (ok == true && mounted) {
      widget.m.startDevModeSession();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final valid = m.isLicenseValid;
    final exp = m.licenseExpiresAt;
    final canExtend = m.devModeSession && !_extending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle('Licenca'),
        const SizedBox(height: 8),
        const Text(
          'Menaxhoni skadimin e licencës së aplikacionit POS.',
          style: TextStyle(fontSize: 14, color: AppColors.mediumGreenText),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      valid ? Icons.verified : Icons.warning_amber_rounded,
                      color: valid
                          ? AppColors.primaryGreen
                          : AppColors.negativeText,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        LicenseService.statusLabel(valid, exp),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!m.devModeSession) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _openDevAuth,
                    icon: const Icon(Icons.developer_mode, size: 18),
                    label: const Text('Hyr Dev Mode për zgjatje'),
                  ),
                ],
                if (m.devModeSession) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Dev Mode aktiv — zgjidhni kohëzgjatjen e zgjatjes:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final opt in LicenseService.extensionOptions)
                        FilledButton.tonal(
                          onPressed: canExtend
                              ? () => _extend(opt.duration, opt.label)
                              : null,
                          child: Text(opt.label),
                        ),
                    ],
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

class _DevAuthDialog extends StatefulWidget {
  const _DevAuthDialog();

  @override
  State<_DevAuthDialog> createState() => _DevAuthDialogState();
}

class _DevAuthDialogState extends State<_DevAuthDialog> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!LicenseService.instance.validateDevCredentials(
      _userCtrl.text,
      _passCtrl.text,
    )) {
      setState(() => _error = 'Përdoruesi ose fjalëkalimi i gabuar.');
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dev Mode'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _userCtrl,
              decoration: inputDeco('Përdoruesi'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: inputDeco('Fjalëkalimi'),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.negativeText,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anulo'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Konfirmo'),
        ),
      ],
    );
  }
}
