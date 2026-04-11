import 'package:flutter/material.dart';

/// Green Grounds POS — paleta sipas specifikës vizuale.
abstract final class AppColors {
  static const Color primaryGreen = Color(0xFF4a7c59);
  static const Color lightGreenBg = Color(0xFFe8f3ec);
  static const Color beige = Color(0xFFf9faf7);
  static const Color darkGreenText = Color(0xFF2d4a35);
  static const Color mediumGreenText = Color(0xFF6b8670);
  static const Color lightGreenText = Color(0xFF9db3a1);
  static const Color white = Color(0xFFffffff);
  static const Color darkerGreenHover = Color(0xFF3d6849);
  static const Color negativeBg = Color(0xFFFFEBEE);
  static const Color negativeText = Color(0xFFC62828);

  static Color borderSubtle([double a = 0.1]) =>
      primaryGreen.withValues(alpha: a);

  static Color borderVisible([double a = 0.2]) =>
      primaryGreen.withValues(alpha: a);

  static Color borderEmphasized([double a = 0.3]) =>
      primaryGreen.withValues(alpha: a);

  static Color lightGreenBorderEmpty() =>
      lightGreenText.withValues(alpha: 0.2);
}
