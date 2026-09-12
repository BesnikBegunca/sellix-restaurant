import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../l10n/tr.dart';

/// Dialog: menaxheri shkruan PIN-in e stafit për ta verifikuar dhe ruajtur.
Future<String?> showStaffPinRevealDialog(
  BuildContext context, {
  required String staffName,
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Shfaq PIN — $staffName'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr.shkruajPinSakteStafitDoRuhet + tr.menjehereHerenTjeter,
            style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'PIN',
              filled: true,
              fillColor: AppColors.beige,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) {
              final p = ctrl.text.trim();
              if (p.length >= 4) Navigator.of(ctx).pop(p);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr.anulo),
        ),
        FilledButton(
          onPressed: () {
            final p = ctrl.text.trim();
            if (p.length < 4) return;
            Navigator.of(ctx).pop(p);
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
          ),
          child: const Text('Shfaq'),
        ),
      ],
    ),
  );
}
