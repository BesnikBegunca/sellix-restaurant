import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/activation_validate_response.dart';
import '../manager/manager_data.dart';
import '../services/activation_error_message.dart';
import '../services/activation_service.dart';
import '../services/background_sync_service.dart';
import '../services/local_tenant_data_service.dart';
import '../services/runtime_config_service.dart';
import '../theme/app_colors.dart';
import '../widgets/tenant_data_conflict_dialog.dart';
import 'login_screen.dart';

/// First-run screen shown when the device has not yet been activated.
///
/// Flow: validate activation key → confirm business/branch → activate desktop.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _keyController = TextEditingController();
  final _branchController = TextEditingController();

  bool _validating = false;
  bool _activating = false;
  String? _error;
  ActivationValidateResponse? _validated;

  bool get _busy => _validating || _activating;

  @override
  void dispose() {
    _keyController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  Future<void> _validateKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Ju lutem vendosni çelësin e aktivizimit.');
      return;
    }
    setState(() {
      _validating = true;
      _error = null;
      _validated = null;
    });
    try {
      final result = await ActivationService.instance.validateActivationKey(
        activationKey: key,
      );
      if (!mounted) return;
      setState(() {
        _validated = result;
        _validating = false;
        if (result.branchCode != null && result.branchCode!.isNotEmpty) {
          _branchController.text = result.branchCode!;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validating = false;
        _error = activationErrorMessage(e);
      });
    }
  }

  Future<void> _activate() async {
    final key = _keyController.text.trim();
    final branch = _branchController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Ju lutem vendosni çelësin e aktivizimit.');
      return;
    }
    if (_validated == null) {
      setState(
        () => _error = 'Së pari verifikoni çelësin me butonin "Verifiko çelësin".',
      );
      return;
    }
    if (branch.isEmpty) {
      setState(() => _error = 'Ju lutem vendosni kodin e degës.');
      return;
    }

    final newBusinessId = _validated!.businessId;
    if (newBusinessId == null || newBusinessId.isEmpty) {
      setState(
        () => _error = 'Serveri nuk ktheu businessId. Provoni përsëri.',
      );
      return;
    }

    final conflict =
        await LocalTenantDataService.instance.detectConflict(newBusinessId);
    if (conflict != null) {
      if (!mounted) return;
      final wipe = await showTenantDataConflictDialog(context, conflict);
      if (wipe == null) return;
      if (wipe) {
        await LocalTenantDataService.instance.clearLocalBusinessData();
      }
    }

    setState(() {
      _activating = true;
      _error = null;
    });
    try {
      await ActivationService.instance.activateDesktop(
        activationKey: key,
        branchCode: branch,
        businessName: _validated!.businessName,
      );
      await ManagerData.instance.reload();
      BackgroundSyncService.instance.start();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activating = false;
        _error = activationErrorMessage(e);
      });
    }
  }

  Future<void> _resetLocalActivation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rivendos aktivizimin lokal?'),
        content: const Text(
          'Fshin token-at dhe metadata e sinkronizimit. '
          'Të dhënat lokale të shitjeve nuk preken.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulo'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rivendos'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    BackgroundSyncService.instance.stop();
    await ActivationService.instance.resetLocalActivation();
    if (!mounted) return;
    setState(() {
      _validated = null;
      _error = null;
      _keyController.clear();
      _branchController.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktivizimi lokal u rivendos.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = RuntimeConfigService.instance;
    final usingLocalhost = config.isUsingFallback;

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
                      'Verifikoni çelësin, konfirmoni biznesin, pastaj aktivizoni terminalin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.lightGreenText,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ApiConfigBanner(
                      baseUrl: config.apiBaseUrl,
                      usingLocalhost: usingLocalhost,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _keyController,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Çelësi i Aktivizimit',
                        hintText: 'p.sh. POS-XXXX-XXXX-XXXX',
                        prefixIcon: Icon(Icons.vpn_key_rounded),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _busy ? null : _validateKey(),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : _validateKey,
                      child: _validating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Verifiko çelësin'),
                    ),
                    if (_validated != null) ...[
                      const SizedBox(height: 16),
                      _ValidationSummaryCard(validation: _validated!),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _branchController,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Kodi i Degës',
                          hintText: 'p.sh. MAIN (nga paneli admin)',
                          prefixIcon: Icon(Icons.business_rounded),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _busy ? null : _activate(),
                      ),
                    ],
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
                    if (_validated != null)
                      ElevatedButton(
                        onPressed: _busy ? null : _activate,
                        child: _activating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text('Aktivizo terminalin'),
                      ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: _busy ? null : _resetLocalActivation,
                        child: const Text('Rivendos aktivizimin lokal'),
                      ),
                    ],
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

class _ApiConfigBanner extends StatelessWidget {
  const _ApiConfigBanner({
    required this.baseUrl,
    required this.usingLocalhost,
  });

  final String baseUrl;
  final bool usingLocalhost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: usingLocalhost
            ? AppColors.mutedOrange.withValues(alpha: 0.12)
            : AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: usingLocalhost
              ? AppColors.mutedOrange.withValues(alpha: 0.4)
              : AppColors.lightGreenBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'API: $baseUrl',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: AppColors.darkGreenText,
            ),
          ),
          if (usingLocalhost) ...[
            const SizedBox(height: 8),
            const Text(
              'Po përdoret localhost API. Production key nuk do të funksionojë.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedOrange,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ValidationSummaryCard extends StatelessWidget {
  const _ValidationSummaryCard({required this.validation});

  final ActivationValidateResponse validation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightGreenBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Çelësi u verifikua',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 10),
          _row('Biznesi', validation.businessName ?? '—'),
          _row('Dega', validation.branchName ?? '—'),
          _row('Licenca', validation.licenseStatus ?? '—'),
          if (validation.licenseExpiresAt != null)
            _row('Skadon', validation.licenseExpiresAt!),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mediumGreenText,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
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
}
