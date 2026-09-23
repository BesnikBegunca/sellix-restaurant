import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/tenant_activation_gate_result.dart';
import '../models/tenant_data_conflict.dart';
import '../services/local_tenant_data_service.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// Asks whether to wipe local SQLite data before activating a new business.
Future<TenantConflictDialogChoice?> showTenantDataConflictDialog(
  BuildContext context,
  TenantDataConflict conflict,
) {
  final previousLabel = conflict.previousBusinessName ??
      conflict.previousBusinessId ??
      tr.biznesiMeparshem;
  final release = LocalTenantDataService.isMandatoryWipeEnforced;

  if (release) {
    return showDialog<TenantConflictDialogChoice>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tr.biznesTjeterUZbulua),
        content: Text(
          '${trf.tenantConflict(previousLabel)}\n\n'
          '${tr.tenantCleanupRequired}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(
              TenantConflictDialogChoice.cancelled,
            ),
            child: Text(tr.anulo),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.softRed),
            onPressed: () => Navigator.of(ctx).pop(
              TenantConflictDialogChoice.wipeAndContinue,
            ),
            child: const Text('Pastro dhe vazhdo'),
          ),
        ],
      ),
    );
  }

  return showDialog<TenantConflictDialogChoice>(
    context: context,
    // Shown from inside LicenseBlockedOverlay's nested Navigator: the root
    // navigator sits under that overlay, so the dialog would be invisible.
    useRootNavigator: false,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(tr.biznesTjeterUZbulua),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${trf.tenantConflict(previousLabel)}\n\n'
            '${tr.releaseCleanupMandatory}',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.negativeBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.softRed.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              tr.rrezikRuajVetemTestimMundShfaqen + tr.biznesitTjeterLeximetNukFiltrohenEnde,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.negativeText,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(
            TenantConflictDialogChoice.cancelled,
          ),
          child: Text(tr.anulo),
        ),
        if (kDebugMode)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(
              TenantConflictDialogChoice.keepLocalDebugOnly,
            ),
            child: Text(tr.ruajVetemTestim),
          ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.softRed),
          onPressed: () => Navigator.of(ctx).pop(
            TenantConflictDialogChoice.wipeAndContinue,
          ),
          child: const Text('Pastro dhe vazhdo'),
        ),
      ],
    ),
  );
}
