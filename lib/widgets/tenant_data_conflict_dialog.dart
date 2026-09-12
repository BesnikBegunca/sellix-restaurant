import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/tenant_activation_gate_result.dart';
import '../models/tenant_data_conflict.dart';
import '../services/local_tenant_data_service.dart';
import '../theme/app_colors.dart';

/// Asks whether to wipe local SQLite data before activating a new business.
Future<TenantConflictDialogChoice?> showTenantDataConflictDialog(
  BuildContext context,
  TenantDataConflict conflict,
) {
  final previousLabel = conflict.previousBusinessName ??
      conflict.previousBusinessId ??
      'biznesi i mëparshëm';
  final release = LocalTenantDataService.isMandatoryWipeEnforced;

  if (release) {
    return showDialog<TenantConflictDialogChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Biznes tjetër u zbulua'),
        content: Text(
          'Ky terminal ka të dhëna lokale nga një biznes tjetër ($previousLabel).\n\n'
          'Për siguri, duhet të pastrohen të dhënat lokale para se të '
          'aktivizohet biznesi i ri.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(
              TenantConflictDialogChoice.cancelled,
            ),
            child: const Text('Anulo'),
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
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Biznes tjetër u zbulua'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ky terminal ka të dhëna lokale nga një biznes tjetër ($previousLabel).\n\n'
            'Në versionin e publikuar, pastrimi lokal është i detyrueshëm.',
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
              'Rrezik: "Ruaj vetëm për testim" mund të shfaqen të dhëna të '
              'biznesit tjetër (leximet nuk filtrohen ende sipas tenant-it).',
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
          child: const Text('Anulo'),
        ),
        if (kDebugMode)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(
              TenantConflictDialogChoice.keepLocalDebugOnly,
            ),
            child: const Text('Ruaj vetëm për testim'),
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
