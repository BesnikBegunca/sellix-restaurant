import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../manager/manager_data.dart';
import '../models/activation_validate_response.dart';
import '../models/sellix_license.dart';
import '../models/tenant_activation_gate_result.dart';
import '../services/activation_error_message.dart';
import '../services/activation_service.dart';
import '../services/background_sync_service.dart';
import '../services/license_heartbeat_service.dart';
import '../services/local_tenant_data_service.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_pin_setup_dialog.dart';
import '../widgets/gg_header.dart';
import '../widgets/open_tables_activation_dialog.dart';

/// Search key → business preview → Continue / Pastro dhe vazhdo.
class ActivationKeyForm extends StatefulWidget {
  const ActivationKeyForm({
    super.key,
    this.showLogo = true,
    this.title = 'Aktivizimi i Sistemit',
    this.subtitle,
  });

  final bool showLogo;
  final String title;
  final String? subtitle;

  @override
  State<ActivationKeyForm> createState() => _ActivationKeyFormState();
}

class _ActivationKeyFormState extends State<ActivationKeyForm> {
  final _keyController = TextEditingController();

  bool _validating = false;
  bool _activating = false;
  String? _error;
  ActivationValidateResponse? _validated;

  bool get _busy => _validating || _activating;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _validateKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = tr.juLutemVendosniCelesinAktivizimit);
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
    if (key.isEmpty) {
      setState(() => _error = tr.juLutemVendosniCelesinAktivizimit);
      return;
    }
    if (_validated == null) {
      setState(() => _error = tr.pariVerifikoniCelesinButoninVerifikoCelesin);
      return;
    }

    final newBusinessId = _validated!.businessId;
    if (newBusinessId == null || newBusinessId.isEmpty) {
      setState(() => _error = tr.serveriNukKtheuBusinessidProvoniPerseri);
      return;
    }

    try {
      if (!await _prepareActivationGate(newBusinessId)) {
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = activationErrorMessage(e));
      return;
    }

    setState(() {
      _activating = true;
      _error = null;
    });
    var persisted = false;
    try {
      await ActivationService.instance.activateDesktop(
        activationKey: key,
        branchCode: _validated!.branchCode ?? 'MAIN',
        businessName: _validated!.businessName,
        business: _validated!.business,
        license: _validated!.license,
        liftUi: false,
      );
      persisted = true;
      await ManagerData.instance.reload();
      if (mounted) {
        await showAdminPinSetupDialog(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activating = false;
        _error = activationErrorMessage(e);
      });
    } finally {
      if (persisted) {
        await ActivationService.instance.completeActivationUi();
        BackgroundSyncService.instance.start();
        LicenseHeartbeatService.instance.start(checkImmediately: false);
      }
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
          _error = trf.closeTablesFailed(e);
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
              '${tr.pastrimiDhenaveLokaleDeshtoiAktivizimiU}${gate.error}';
        });
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final inputsEnabled = !_busy;
    final subtitle =
        widget.subtitle ??
        'Shkruani çelësin e biznesit. Gjejmë biznesin, shfaqen të dhënat, '
            'pastaj Vazhdo / Pastro dhe vazhdo.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showLogo) ...[
          const Center(child: GgLogoBox(size: 64, radius: 16)),
          const SizedBox(height: 24),
        ],
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGreenText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.lightGreenText,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _keyController,
          enabled: inputsEnabled,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: tr.celesiAktivizimit,
            hintText: 'SLX-XXXXX-XXXXX-XXXXX-XXXXX',
            prefixIcon: const Icon(Icons.vpn_key_rounded),
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
              : Text(tr.verifikoCelesin),
        ),
        if (_validated != null) ...[
          const SizedBox(height: 16),
          BusinessPreviewCard(validation: _validated!),
        ],
        const SizedBox(height: 24),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.negativeBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.softRed.withValues(alpha: 0.3)),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: AppColors.softRed, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_validated != null)
          ElevatedButton(
            onPressed: inputsEnabled ? _activate : null,
            child: _activating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Text('Vazhdo'),
          ),
      ],
    );
  }
}

class BusinessPreviewCard extends StatelessWidget {
  const BusinessPreviewCard({super.key, required this.validation});

  final ActivationValidateResponse validation;

  @override
  Widget build(BuildContext context) {
    final business = validation.business ?? const SellixBusinessProfile();
    final license = validation.license;

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
          Text(
            tr.celesiUVerifikua,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 10),
          _row(
            tr.biznesi,
            business.name.isEmpty ? (validation.businessName ?? '—') : business.name,
          ),
          _row('NUI', business.nui),
          _row('Sektori', business.sector),
          _row('Adresa', business.formattedAddress),
          _row('Telefoni', business.phone),
          _row('Email', business.email),
          _row('Kontakti', business.contactPerson),
          _row('Nr. fiskal', business.fiscalNumber),
          _row('Nr. TVSH', business.vatNumber),
          _row(tr.licenca, license?.status ?? validation.licenseStatus ?? '—'),
          if ((license?.expiresAt ?? validation.licenseExpiresAt) != null)
            _row('Skadon', license?.expiresAt ?? validation.licenseExpiresAt!),
          if (license != null && license.seats > 0)
            _row('Pajisje', '${license.devicesUsed} / ${license.seats}'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.mediumGreenText),
            ),
          ),
          Expanded(
            flex: 3,
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
}
