import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';

class AdjustmentRow extends StatelessWidget {
  const AdjustmentRow({super.key, required this.adj});
  final SaleAdjustmentRow adj;

  String get _typeLabel {
    switch (adj.adjustmentType) {
      case 'refund':
        return 'Rimbursim';
      case 'void':
        return 'Anulim';
      case 'discount':
        return 'Zbritje';
      default:
        return adj.adjustmentType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = adj.createdAt;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.negativeText.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _typeLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.negativeText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              adj.reason ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mediumGreenText,
              ),
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.lightGreenText,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '-${adj.amount.toStringAsFixed(2)}€',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.negativeText,
            ),
          ),
        ],
      ),
    );
  }
}
