import 'package:flutter/material.dart';

import '../models/open_tables_summary.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// Shown from [ActivationScreen] when open tables block local data wipe.
Future<bool?> showOpenTablesActivationDialog(
  BuildContext context,
  OpenTablesSummary summary,
) {
  final totalLabel = summary.totalAmount.toStringAsFixed(2);
  final countLabel = summary.count == 1
      ? tr.k1TavolinePorosiHapur
      : trf.openTablesSummary(summary.count);

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(tr.keniTavolinaHapura),
      content: Text(
        trf.openTablesFound(countLabel, totalLabel) +
            tr.vazhduarAktiviziminDuhetTMbyllni,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(tr.anulo),
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
