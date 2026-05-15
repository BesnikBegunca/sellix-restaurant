import 'package:flutter/material.dart';

import '../manager/manager_data.dart';
import '../services/license_service.dart';
import '../theme/app_colors.dart';
import 'manager_dashboard_screen.dart';

/// Hyrje vetëm për Dev Mode kur licenca ka skaduar (admin / admin).
class DevModeLoginScreen extends StatefulWidget {
  const DevModeLoginScreen({super.key});

  @override
  State<DevModeLoginScreen> createState() => _DevModeLoginScreenState();
}

class _DevModeLoginScreenState extends State<DevModeLoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final user = _userCtrl.text;
    final pass = _passCtrl.text;
    if (!LicenseService.instance.validateDevCredentials(user, pass)) {
      setState(() => _error = 'Kredencialet Dev Mode janë të gabuara.');
      return;
    }
    setState(() => _error = null);
    ManagerData.instance.startDevModeSession();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const ManagerDashboardScreen(
          devModeOnly: true,
          initialIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.developer_mode,
                      color: AppColors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Dev Mode',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ManagerData.instance.isLicenseValid
                        ? 'Hyrje për menaxhimin e licencës.'
                        : 'Licenca ka skaduar. Hyni për ta zgjatur.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _userCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Përdoruesi',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Fjalëkalimi',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.negativeText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _submit,
                            child: const Text('Hyr në Dev Mode'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
