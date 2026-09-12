import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../l10n/tr.dart';

class AuditErrorCard extends StatelessWidget {
  const AuditErrorCard({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.negativeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.negativeText.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.negativeText),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trf.loadFailed(error),
              style: TextStyle(color: AppColors.negativeText),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Riprovo'),
          ),
        ],
      ),
    );
  }
}
