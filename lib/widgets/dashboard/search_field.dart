import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// Rounded search field aligned with dashboard inputs (decoration only).
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hintText = 'Search…',
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.width,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? 280,
      height: 44,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(
          fontSize: AppTokens.tableTextSize,
          color: AppColors.charcoalText,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.mutedGray.withValues(alpha: 0.85),
            fontSize: AppTokens.tableTextSize,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 22,
            color: AppColors.mutedGray.withValues(alpha: 0.9),
          ),
          filled: true,
          fillColor: AppColors.warmOffWhite,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.controlRadius),
            borderSide: BorderSide(color: AppColors.lightGreenBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.controlRadius),
            borderSide: BorderSide(color: AppColors.lightGreenBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.controlRadius),
            borderSide: BorderSide(
              color: AppColors.deepForestGreen,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
