import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/license_gate_service.dart';
import '../services/license_heartbeat_service.dart';
import '../theme/app_colors.dart';
import '../widgets/activation_key_form.dart';

/// Expire/pezullim: Riprovo pret webin. New key: i njëjti flow si aktivizimi.
class LicenseSuspendedScreen extends StatefulWidget {
  const LicenseSuspendedScreen({super.key});

  @override
  State<LicenseSuspendedScreen> createState() => _LicenseSuspendedScreenState();
}

class _LicenseSuspendedScreenState extends State<LicenseSuspendedScreen> {
  final _gate = LicenseGateService.instance;
  final _heartbeat = LicenseHeartbeatService.instance;
  bool _retrying = false;
  String? _retryMessage;

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
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryMessage = null;
    });
    if (!_heartbeat.isRunning) {
      _heartbeat.start(checkImmediately: false);
    }
    final ok = await _heartbeat.checkNow(manual: true);
    if (!mounted) return;
    setState(() => _retrying = false);
    if (ok && !_gate.isBlocked) return;
    setState(() {
      _retryMessage = _gate.waitsForWebRestore
          ? 'Ende e bllokuar. Bëni extend / vazhdim nga webi — app-i kthehet vetë.'
          : tr.licencaEshteEndePezulluarKontaktoniAdministratorin;
    });
  }

  @override
  Widget build(BuildContext context) {
    final needsNewKey = _gate.needsReplacementKey;
    final expired = _gate.code == LicenseBlockCode.licenseExpired;
    final title = needsNewKey
        ? 'Çelës i ri'
        : expired
        ? 'Licenca ka skaduar'
        : 'Licenca është pezulluar';
    final reason = _gate.reason ??
        (needsNewKey
            ? 'U lëshua një çelës i ri. Verifikoni, shihni biznesin, pastaj Vazhdo.'
            : expired
            ? tr.licencaKaSkaduarKontaktoniAdministratorinRinovim
            : tr.licencaEshtePezulluarKontaktoniAdministratorin);

    return Material(
      color: AppColors.beige,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!needsNewKey) ...[
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          reason,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.charcoalText,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _retrying ? null : _retryStatusCheck,
                          child: _retrying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Riprovo (extend / vazhdim nga webi)',
                                ),
                        ),
                        if (_retryMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _retryMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Divider(color: AppColors.lightGreenBorder),
                        const SizedBox(height: 8),
                      ],
                      const ActivationKeyForm(
                        showLogo: false,
                        title: 'Çelësi i ri',
                        subtitle:
                            'Shkruani çelësin, verifikohet biznesi, shfaqen të dhënat, '
                            'pastaj Vazhdo / Pastro dhe vazhdo.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
