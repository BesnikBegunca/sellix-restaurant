import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

class ExpenseFilterChip extends StatelessWidget {
  const ExpenseFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : AppColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? AppColors.primaryGreen
                : AppColors.lightGreenBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.white : AppColors.darkGreenText,
          ),
        ),
      ),
    );
  }
}
