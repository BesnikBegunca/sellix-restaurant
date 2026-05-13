import 'package:flutter/material.dart';

/// Hospitality POS palette (Green Leaf) + names used across the existing codebase.
abstract final class AppColors {
  // --- Primary palette ---
  static const Color deepForestGreen = Color(0xFF234B36);
  static const Color oliveGreen = Color(0xFF3E6B52);
  static const Color warmOffWhite = Color(0xFFF7F8F6);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color softGreenTint = Color(0xFFEAF0EA);
  static const Color lightGreenBorder = Color(0xFFDCE5DC);
  static const Color charcoalText = Color(0xFF222222);
  static const Color mutedGray = Color(0xFF666666);

  // --- Accents ---
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color accentRed = Color(0xFFDC3545);
  static const Color accentOrange = Color(0xFFFFA07A);
  static const Color accentBlue = Color(0xFF5B9BD5);
  static const Color successGreen = Color(0xFF3E6B52);

  // --- Legacy aliases (do not remove — used throughout screens) ---
  static const Color primaryGreen = deepForestGreen;
  static const Color lightGreenBg = softGreenTint;
  static const Color beige = warmOffWhite;
  static const Color darkGreenText = charcoalText;
  static const Color mediumGreenText = mutedGray;
  static const Color lightGreenText = mutedGray;
  static const Color white = pureWhite;
  static const Color darkerGreenHover = oliveGreen;

  static final Color negativeBg = accentRed.withValues(alpha: 0.1);
  static const Color negativeText = accentRed;

  static Color borderSubtle([double strength = 1]) {
    final t =
        (0.12 + 0.55 * strength.clamp(0.0, 1.0)).clamp(0.08, 1.0).toDouble();
    return Color.lerp(pureWhite, lightGreenBorder, t)!;
  }

  static Color borderVisible([double a = 1]) =>
      deepForestGreen.withValues(alpha: (0.12 * a).clamp(0.0, 1.0));

  static Color borderEmphasized([double a = 1]) =>
      oliveGreen.withValues(alpha: (0.28 + 0.2 * a).clamp(0.0, 1.0));

  static Color lightGreenBorderEmpty() =>
      lightGreenBorder.withValues(alpha: 0.72);
}
