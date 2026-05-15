import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

class SettingsCheckTile extends StatelessWidget {
  const SettingsCheckTile({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: true,
              onChanged: (_) {},
              activeColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.lightGreenBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.darkGreenText,
            ),
          ),
        ],
      ),
    );
  }
}
