import 'package:flutter/material.dart';

/// Premium POS design token palette.
abstract final class AppColors {
  // ── Primary brand ──────────────────────────────────────────────────────────
  static const Color primaryGreen = Color(0xFF234B36);   // deep forest green — CTAs, active nav
  static const Color oliveGreen   = Color(0xFF3E6B52);   // secondary accent

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color beige         = Color(0xFFF7F8F6);  // page background
  static const Color lightGreenBg  = Color(0xFFEAF0EA);  // hover / selected bg
  static const Color white         = Color(0xFFFFFFFF);  // card surface

  // ── Borders ───────────────────────────────────────────────────────────────
  static const Color lightGreenBorder = Color(0xFFDCE5DC);  // card / input border

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color darkGreenText   = Color(0xFF222222);  // charcoal — headings
  static const Color mediumGreenText = Color(0xFF555555);  // body text
  static const Color lightGreenText  = Color(0xFF888888);  // muted / metadata

  // ── Semantic / accents ────────────────────────────────────────────────────
  static const Color warmGold       = Color(0xFFD4AF37);  // revenue / profit
  static const Color softRed        = Color(0xFFDC3545);  // errors
  static const Color mutedOrange    = Color(0xFFFFA07A);  // warnings
  static const Color infoBlue       = Color(0xFF5B9BD5);  // info / reserved

  // ── Semantic aliases (new widget tokens) ──────────────────────────────────
  static const Color deepForestGreen = primaryGreen;           // alias
  static const Color pureWhite       = white;                  // alias
  static const Color charcoalText    = darkGreenText;          // alias
  static const Color softGreenTint   = lightGreenBg;           // alias
  static const Color warmOffWhite    = beige;                  // alias
  static const Color mutedGray       = Color(0xFF9E9E9E);      // neutral grey
  static const Color successGreen    = Color(0xFF28A745);      // positive / success
  static const Color accentRed       = softRed;                // alias
  static const Color accentOrange    = mutedOrange;            // alias
  static const Color accentBlue      = infoBlue;               // alias

  // ── Legacy aliases (kept for backward compatibility) ──────────────────────
  static const Color darkerGreenHover = oliveGreen;
  static const Color negativeText     = softRed;
  static const Color negativeBg       = Color(0xFFFFEBEE);

  // ── Dynamic border helpers (kept for backward compatibility) ──────────────
  static Color borderSubtle([double a = 0.1]) =>
      const Color(0xFF234B36).withValues(alpha: a);

  static Color borderVisible([double a = 0.2]) =>
      const Color(0xFF234B36).withValues(alpha: a);

  static Color borderEmphasized([double a = 0.3]) =>
      const Color(0xFF234B36).withValues(alpha: a);

  static Color lightGreenBorderEmpty() =>
      lightGreenBorder.withValues(alpha: 0.72);
}
