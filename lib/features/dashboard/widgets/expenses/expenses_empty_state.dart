import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../l10n/tr.dart';

class ExpensesEmptyState extends StatelessWidget {
  const ExpensesEmptyState({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle(0.08)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: AppColors.lightGreenText.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            tr.nukKaRreshtaPerputhenFiltrat,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr.zbrazKerkiminZgjidhGjithaLlojiOse,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.mediumGreenText),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Shto transaksion'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}
