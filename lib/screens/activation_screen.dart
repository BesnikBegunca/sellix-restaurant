import 'package:flutter/material.dart';

import '../services/activation_service.dart';
import '../services/background_sync_service.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';

/// First-run screen shown when the device has not yet been activated.
///
/// Collects an activation key + branch code, calls POST /activation/desktop,
/// then navigates to [LoginScreen] on success.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _keyController    = TextEditingController();
  final _branchController = TextEditingController();
  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key    = _keyController.text.trim();
    final branch = _branchController.text.trim();
    if (key.isEmpty || branch.isEmpty) {
      setState(() => _error = 'Ju lutem plotësoni të gjitha fushat.');
      return;
    }
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      await ActivationService.instance.activateDesktop(
        activationKey: key,
        branchCode:    branch,
      );
      BackgroundSyncService.instance.start();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error   = _friendlyError(e);
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Çelësi i aktivizimit ose kodi i degës është i pasaktë.';
    }
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Failed host lookup')) {
      return 'Nuk mund të lidhemi me serverin. Kontrolloni lidhjen e internetit.';
    }
    return 'Aktivizimi dështoi. Ju lutem provoni përsëri.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.store_rounded,
                          color: AppColors.primaryGreen,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Aktivizimi i Sistemit',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vendosni çelësin e aktivizimit dhe kodin e degës '
                      'për të lidhur këtë terminal me llogarinë tuaj.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.lightGreenText,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _keyController,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'Çelësi i Aktivizimit',
                        hintText: 'p.sh. XXXX-XXXX-XXXX-XXXX',
                        prefixIcon: Icon(Icons.vpn_key_rounded),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _branchController,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'Kodi i Degës',
                        hintText: 'p.sh. MAIN',
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _loading ? null : _activate(),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.negativeBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.softRed.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.softRed,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton(
                      onPressed: _loading ? null : _activate,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Text('Aktivizo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
