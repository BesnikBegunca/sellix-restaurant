import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

class PayrollSummaryRow extends StatelessWidget {
  const PayrollSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.mediumGreenText,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.darkGreenText,
          ),
        ),
      ],
    );
  }
}
