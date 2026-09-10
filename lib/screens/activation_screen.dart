import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/activation_validate_response.dart';
import '../manager/manager_data.dart';
import '../services/activation_error_message.dart';
import '../services/activation_service.dart';
import '../services/background_sync_service.dart';
import '../services/device_transfer_exception.dart';
import '../services/local_tenant_data_service.dart';
import '../services/runtime_config_service.dart';
import 'developer_login_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/open_tables_activation_dialog.dart';
import '../widgets/gg_header.dart';
import '../models/tenant_activation_gate_result.dart';

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
  bool _transferPending = false;
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
        () => _error =
            'Së pari verifikoni çelësin me butonin "Verifiko çelësin".',
      );
      return;
    }
    if (branch.isEmpty) {
      setState(() => _error = 'Ju lutem vendosni kodin e degës.');
      return;
    }

    final newBusinessId = _validated!.businessId;
    if (newBusinessId == null || newBusinessId.isEmpty) {
      setState(() => _error = 'Serveri nuk ktheu businessId. Provoni përsëri.');
      return;
    }

    if (!await _prepareActivationGate(newBusinessId)) {
      return;
    }

    setState(() {
      _activating = true;
      _transferPending = false;
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
      // [ActivationStateController] → [PosSystemApp] home becomes [LoginScreen].
    } on DeviceTransferRequiredException catch (e) {
      if (!mounted) return;
      setState(() {
        _activating = false;
        _transferPending = true;
        _error = null;
      });
      await _showTransferPendingDialog(isDuplicate: e.isDuplicate);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activating = false;
        _error = activationErrorMessage(e);
      });
    }
  }

  Future<bool> _prepareActivationGate(String newBusinessId) async {
    var gate = await LocalTenantDataService.instance.prepareForActivation(
      context: context,
      newBusinessId: newBusinessId,
    );

    while (gate.action == TenantActivationGateAction.openTablesBlocked) {
      if (!mounted) return false;
      final summary = gate.openTablesSummary;
      if (summary == null) return false;

      final confirmed = await showOpenTablesActivationDialog(context, summary);
      if (confirmed != true) return false;

      setState(() {
        _activating = true;
        _error = null;
      });
      try {
        await LocalTenantDataService.instance.closeOpenTablesSafely();
      } catch (e) {
        if (!mounted) return false;
        setState(() {
          _activating = false;
          _error = 'Mbyllja e tavolinave dështoi: $e';
        });
        return false;
      }

      if (!mounted) return false;
      gate = await LocalTenantDataService.instance.prepareForActivation(
        context: context,
        newBusinessId: newBusinessId,
        forceAfterSafeClose: true,
      );
    }

    if (!gate.canProceedToActivation) {
      if (!mounted) return false;
      if (gate.action == TenantActivationGateAction.wipeFailed) {
        setState(() {
          _error =
              'Pastrimi i të dhënave lokale dështoi. Aktivizimi u ndal.\n'
              '${gate.error}';
        });
      }
      return false;
    }

    return true;
  }

  Future<void> _showTransferPendingDialog({required bool isDuplicate}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Kërkohet aprovim nga SuperAdmin'),
        content: Text(
          isDuplicate
              ? 'Kërkesa ekziston dhe është në pritje të aprovimit.'
              : 'Kjo licencë është përdorur më parë në një pajisje tjetër. '
                    'Kërkesa për transferim u dërgua te SuperAdmin. '
                    'Pas aprovimit, provo aktivizimin përsëri.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Në rregull'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _activate();
            },
            child: const Text('Provo përsëri'),
          ),
        ],
      ),
    );
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
    final configBlocked = config.isBlockedInRelease;
    final showLocalhostWarning =
        !configBlocked && (config.isUsingFallback || config.isLocalhost);
    final inputsEnabled = !_busy && !configBlocked;

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
                    const Center(child: GgLogoBox(size: 64, radius: 16)),
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
                      sourceLabel: config.sourceLabel,
                      usingLocalhost: showLocalhostWarning,
                      configBlocked: configBlocked,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _keyController,
                      enabled: inputsEnabled,
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
                      onPressed: inputsEnabled ? _validateKey : null,
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
                        enabled: inputsEnabled,
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
                    if (_transferPending) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mutedOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.mutedOrange.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'Kërkesa për transferim u dërgua te SuperAdmin. '
                          'Pas aprovimit, provo aktivizimin përsëri.',
                          style: TextStyle(
                            color: AppColors.mutedOrange,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
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
                        onPressed: inputsEnabled ? _activate : null,
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
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const DeveloperLoginScreen(),
                              ),
                            ),
                      icon: const Icon(Icons.engineering_outlined),
                      label: const Text('Developer access / Hyrje developer'),
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

class _ApiConfigBanner extends StatelessWidget {
  const _ApiConfigBanner({
    required this.baseUrl,
    required this.sourceLabel,
    required this.usingLocalhost,
    required this.configBlocked,
  });

  final String baseUrl;
  final String sourceLabel;
  final bool usingLocalhost;
  final bool configBlocked;

  @override
  Widget build(BuildContext context) {
    final warn = usingLocalhost || configBlocked;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warn
            ? AppColors.mutedOrange.withValues(alpha: 0.12)
            : AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: warn
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
          const SizedBox(height: 4),
          Text(
            'Burimi: $sourceLabel',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mediumGreenText,
            ),
          ),
          if (configBlocked) ...[
            const SizedBox(height: 8),
            const Text(
              RuntimeConfigService.productionConfigErrorTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.softRed,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              RuntimeConfigService.productionConfigErrorBody,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedOrange,
              ),
            ),
          ] else if (usingLocalhost) ...[
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
