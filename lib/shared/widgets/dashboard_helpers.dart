import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

Widget sectionTitle(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: AppColors.darkGreenText,
      height: 1.2,
    ),
  );
}

InputDecoration inputDeco(String hint, {String? prefix}) {
  return InputDecoration(
    hintText: hint,
    prefixText: prefix,
    filled: true,
    fillColor: AppColors.pureWhite,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lightGreenBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lightGreenBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.controlRadius),
      borderSide: const BorderSide(
        color: AppColors.deepForestGreen,
        width: 2,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: const TextStyle(
      color: AppColors.lightGreenText,
      fontSize: 14,
    ),
  );
}
