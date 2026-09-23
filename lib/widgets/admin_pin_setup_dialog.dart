import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/tr.dart';
import '../manager/manager_data.dart';
import '../services/activation_service.dart';
import '../theme/app_colors.dart';

/// Asks whether to store the first PIN as the administrator PIN.
Future<bool> showAdminPinSetupDialog(BuildContext context) async {
  final pinController = TextEditingController();
  final pin = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: Text(tr.konfiguroMenaxherinPare),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr.nukEshteKonfiguruarAsnjePinAdministratorit +
                  tr.deshironiTaVendosniKetePinPin,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'PIN',
                counterText: '',
              ),
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.length >= 4) Navigator.of(ctx).pop(trimmed);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr.anulo),
          ),
          TextButton(
            onPressed: () {
              final trimmed = pinController.text.trim();
              if (trimmed.length < 4) return;
              Navigator.of(ctx).pop(trimmed);
            },
            child: Text(
              'Konfirmo',
              style: TextStyle(color: AppColors.primaryGreen),
            ),
          ),
        ],
      );
    },
  );
  pinController.dispose();

  if (pin == null || pin.length < 4) return false;

  await ManagerData.instance.addManager('Administrator', pin);
  await ManagerData.instance.setAdminPin(pin);
  ActivationService.instance.takeOfferAdminPinOnNextLogin();
  return true;
}
