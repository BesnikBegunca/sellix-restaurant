import 'package:flutter/material.dart';

import '../models/tenant_data_conflict.dart';
import '../theme/app_colors.dart';

/// Asks whether to keep or wipe local SQLite data when the business changes.
///
/// Returns `true` = wipe local data, `false` = keep, `null` = cancelled.
Future<bool?> showTenantDataConflictDialog(
  BuildContext context,
  TenantDataConflict conflict,
) {
  final previousLabel = conflict.previousBusinessName ??
      conflict.previousBusinessId ??
      'biznesi i mëparshëm';

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Të dhëna lokale nga biznes tjetër'),
      content: Text(
        'Ky terminal ka të dhëna lokale nga një biznes tjetër ($previousLabel).\n\n'
        'Dëshironi të filloni me të dhëna të pastra për biznesin e ri?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Anulo'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Ruaj të dhënat lokale'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.softRed),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Pastro të dhënat lokale'),
        ),
      ],
    ),
  );
}
