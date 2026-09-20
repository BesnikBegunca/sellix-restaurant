import 'package:flutter/material.dart';

import '../services/activation_error_message.dart';
import '../services/activation_service.dart';
import '../services/license_gate_service.dart';
import '../services/license_heartbeat_service.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// Full-screen block shown while the license is revoked, expired or suspended.
///
/// It never asks the operator to re-activate: [LicenseHeartbeatService] keeps
/// checking in the background, and the moment SelliX turns the license back on
/// the gate lifts and this screen disappears on its own.
class LicenseSuspendedScreen extends StatefulWidget {
  const LicenseSuspendedScreen({super.key});

  @override
  State<LicenseSuspendedScreen> createState() => _LicenseSuspendedScreenState();
}

class _LicenseSuspendedScreenState extends State<LicenseSuspendedScreen> {
  final _gate = LicenseGateService.instance;
  final _heartbeat = LicenseHeartbeatService.instance;
  String? _statusMessage;
  bool _replacingKey = false;

  @override
  void initState() {
    super.initState();
    _gate.addListener(_onStateChanged);
    _heartbeat.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _gate.removeListener(_onStateChanged);
    _heartbeat.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _retryStatusCheck() async {
    if (_heartbeat.isChecking) return;
    setState(() => _statusMessage = null);

    final ok = await _heartbeat.checkNow(manual: true);
    if (!mounted) return;
    // A successful check lifts the gate and this screen is torn down by
    // LicenseBlockedOverlay — nothing more to do here.
    if (ok && !_gate.isBlocked) return;
    setState(() {
      _statusMessage = tr.licencaEshteEndePezulluarKontaktoniAdministratorin;
    });
  }

  /// Lets the operator paste a replacement key without losing local data —
  /// used when SelliX issues a new license instead of reviving the old one.
  Future<void> _promptForNewKey() async {
    final controller = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr.vazhdoLicencen),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'SLX-XXXX-XXXX-XXXX'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr.anulo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(tr.vazhdoLicencen),
          ),
        ],
      ),
    );
    controller.dispose();

    if (key == null || key.trim().isEmpty || !mounted) return;

    setState(() {
      _replacingKey = true;
      _statusMessage = null;
    });
    try {
      await ActivationService.instance.replaceLocalLicenseKey(key.trim());
      if (!mounted) return;
      // replaceLocalLicenseKey persists the activation, which lifts the gate.
      setState(() => _statusMessage = tr.licencaRiaktivizua);
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = activationErrorMessage(e));
    } finally {
      if (mounted) setState(() => _replacingKey = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final revoked = _gate.code == LicenseBlockCode.licenseRevoked;
    final reason =
        _gate.reason ?? tr.licencaEshtePezulluarKontaktoniAdministratorin;
    final busy = _heartbeat.isChecking || _replacingKey;

    return Material(
      color: AppColors.beige,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.negativeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        revoked
                            ? Icons.lock_person_rounded
                            : Icons.pause_circle_filled_rounded,
                        size: 40,
                        color: AppColors.softRed,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      revoked ? 'Kontakto SelliX' : 'Aksesi i pezulluar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreenText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppColors.charcoalText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.lightGreenText,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _heartbeat.isChecking
                                ? tr.poKontrollohetLicenca
                                : tr.licencaKontrollohetAutomatikisht,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: busy ? null : _retryStatusCheck,
                        child: busy
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text('Riprovo'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: busy ? null : _promptForNewKey,
                        child: Text(tr.vazhdoLicencen),
                      ),
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
