import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/license_gate_service.dart';
import '../theme/app_colors.dart';
import '../widgets/activation_key_form.dart';

/// Bllokim licence: vetëm çelës i ri. Nuk pret extend nga webi.
class LicenseSuspendedScreen extends StatelessWidget {
  const LicenseSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gate = LicenseGateService.instance;
    final expired = gate.code == LicenseBlockCode.licenseExpired;
    final title = gate.needsReplacementKey
        ? 'Çelës i ri'
        : expired
        ? 'Licenca ka skaduar'
        : 'Licenca është pezulluar';
    final reason = gate.reason ??
        (gate.needsReplacementKey
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
                      const SizedBox(height: 20),
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
