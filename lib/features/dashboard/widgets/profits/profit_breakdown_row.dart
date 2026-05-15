import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

class ProfitBreakdownRow extends StatelessWidget {
  const ProfitBreakdownRow({
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
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: bold ? AppColors.darkGreenText : AppColors.lightGreenText,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.darkGreenText,
          ),
        ),
      ],
    );
  }
}
