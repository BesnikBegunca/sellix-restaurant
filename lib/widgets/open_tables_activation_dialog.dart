import 'package:flutter/material.dart';

import '../models/open_tables_summary.dart';
import '../theme/app_colors.dart';

/// Shown from [ActivationScreen] when open tables block local data wipe.
Future<bool?> showOpenTablesActivationDialog(
  BuildContext context,
  OpenTablesSummary summary,
) {
  final totalLabel = summary.totalAmount.toStringAsFixed(2);
  final countLabel = summary.count == 1
      ? '1 tavolinë/porosi të hapur'
      : '${summary.count} tavolina/porosi të hapura';

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Keni tavolina të hapura'),
      content: Text(
        'Janë gjetur $countLabel me total $totalLabel €. '
        'Për të vazhduar aktivizimin duhet t\'i mbyllni.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Anulo'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.darkGreenText,
            foregroundColor: AppColors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Mbyll tavolinat dhe vazhdo'),
        ),
      ],
    ),
  );
}
