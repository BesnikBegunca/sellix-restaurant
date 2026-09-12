import 'package:flutter/material.dart';

import 'theme_mode_controller.dart';

/// Premium POS design token palette.
///
/// Every token below is a *getter* that resolves against the currently active
/// appearance ([ThemeModeController.instance.isDark]). Call sites stay the
/// same (`AppColors.primaryGreen`), but the value follows the theme, so the
/// whole app switches to a properly designed dark palette instead of leaving
/// hardcoded light colours behind.
///
/// Because these are runtime getters, they cannot be used inside `const`
/// expressions — drop the `const` on the surrounding widget/TextStyle.
abstract final class AppColors {
  static bool get _dark => ThemeModeController.instance.isDark;

  static Color _pick(Color light, Color dark) => _dark ? dark : light;

  // ── Primary brand ──────────────────────────────────────────────────────────
  /// Deep forest green in light; a luminous mint in dark so it stays legible
  /// against dark surfaces and passes contrast on text + icons.
  static Color get primaryGreen =>
      _pick(const Color(0xFF234B36), const Color(0xFF5EC79A));

  static Color get oliveGreen =>
      _pick(const Color(0xFF3E6B52), const Color(0xFF41A87B));

  // ── Backgrounds ───────────────────────────────────────────────────────────
  /// Page background.
  static Color get beige =>
      _pick(const Color(0xFFF7F8F6), const Color(0xFF0E1512));

  /// Hover / selected background tint.
  static Color get lightGreenBg =>
      _pick(const Color(0xFFEAF0EA), const Color(0xFF1B2A23));

  /// Card surface.
  static Color get white =>
      _pick(const Color(0xFFFFFFFF), const Color(0xFF16201B));

  // ── Borders ───────────────────────────────────────────────────────────────
  static Color get lightGreenBorder =>
      _pick(const Color(0xFFDCE5DC), const Color(0xFF2C3B33));

  // ── Text ──────────────────────────────────────────────────────────────────
  /// Headings.
  static Color get darkGreenText =>
      _pick(const Color(0xFF222222), const Color(0xFFECF3EE));

  /// Body text.
  static Color get mediumGreenText =>
      _pick(const Color(0xFF555555), const Color(0xFFB4C4BA));

  /// Muted / metadata.
  static Color get lightGreenText =>
      _pick(const Color(0xFF888888), const Color(0xFF82988B));

  // ── Semantic / accents ────────────────────────────────────────────────────
  static Color get warmGold =>
      _pick(const Color(0xFFD4AF37), const Color(0xFFE8C765));

  static Color get softRed =>
      _pick(const Color(0xFFDC3545), const Color(0xFFFF6B7A));

  static Color get mutedOrange =>
      _pick(const Color(0xFFFFA07A), const Color(0xFFFFB48F));

  static Color get infoBlue =>
      _pick(const Color(0xFF5B9BD5), const Color(0xFF74B4EC));

  // ── Semantic aliases (new widget tokens) ──────────────────────────────────
  static Color get deepForestGreen => primaryGreen;
  static Color get pureWhite => white;
  static Color get charcoalText => darkGreenText;
  static Color get softGreenTint => lightGreenBg;
  static Color get warmOffWhite => beige;

  static Color get mutedGray =>
      _pick(const Color(0xFF9E9E9E), const Color(0xFF93A39A));

  static Color get successGreen =>
      _pick(const Color(0xFF28A745), const Color(0xFF4ED18B));

  static Color get accentRed => softRed;
  static Color get accentOrange => mutedOrange;
  static Color get accentBlue => infoBlue;

  // ── Legacy aliases (kept for backward compatibility) ──────────────────────
  static Color get darkerGreenHover => oliveGreen;
  static Color get negativeText => softRed;

  static Color get negativeBg =>
      _pick(const Color(0xFFFFEBEE), const Color(0xFF3A1F24));

  // ── Dynamic border helpers (kept for backward compatibility) ──────────────
  static Color borderSubtle([double a = 0.1]) =>
      _pick(const Color(0xFF234B36), const Color(0xFF8FD8B8)).withValues(alpha: a);

  static Color borderVisible([double a = 0.2]) =>
      _pick(const Color(0xFF234B36), const Color(0xFF8FD8B8)).withValues(alpha: a);

  static Color borderEmphasized([double a = 0.3]) =>
      _pick(const Color(0xFF234B36), const Color(0xFF8FD8B8)).withValues(alpha: a);

  static Color lightGreenBorderEmpty() =>
      lightGreenBorder.withValues(alpha: 0.72);
}
