import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class AuditEmptyState extends StatelessWidget {
  const AuditEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 48,
            color: AppColors.lightGreenText.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nuk ka aktivitet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.mediumGreenText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ndrysho kategorinë ose periudhën.',
            style: TextStyle(fontSize: 13, color: AppColors.lightGreenText),
          ),
        ],
      ),
    );
  }
}
