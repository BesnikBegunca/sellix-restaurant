import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  // ── Page / section titles ─────────────────────────────────────────────────
  static const TextStyle pageTitle = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: AppColors.darkGreenText,
    height: 1.2,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.darkGreenText,
    height: 1.25,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.darkGreenText,
    height: 1.3,
  );

  // ── KPI numbers ───────────────────────────────────────────────────────────
  static const TextStyle kpiLarge = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 40,
    fontWeight: FontWeight.w600,
    color: AppColors.darkGreenText,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static const TextStyle kpiMedium = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.darkGreenText,
    height: 1.2,
    letterSpacing: -0.3,
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  static const TextStyle body = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.darkGreenText,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.mediumGreenText,
    height: 1.45,
  );

  static const TextStyle muted = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.lightGreenText,
    height: 1.4,
  );

  // ── UI elements ───────────────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static const TextStyle tableHeader = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.lightGreenText,
    letterSpacing: 0.6,
  );

  static const TextStyle tableCell = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.darkGreenText,
  );

  static const TextStyle badge = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle navItem = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle metadata = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.lightGreenText,
  );
}
