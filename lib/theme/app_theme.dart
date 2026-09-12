import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the light and dark [ThemeData] for the app.
///
/// Both themes are generated from one spec so every surface, border and text
/// colour has a deliberate counterpart in the other mode — the dark theme is a
/// designed palette (deep green-black surfaces, luminous mint accent), not an
/// inverted copy of the light one.
abstract final class AppTheme {
  // ── Dark palette ──────────────────────────────────────────────────────────
  /// Page background — near-black with a green cast so it sits under the mint
  /// accent without looking like a blue-grey "default dark".
  static const Color darkBackground = Color(0xFF0E1512);

  /// Card / panel surface, one step above the background.
  static const Color darkSurface = Color(0xFF16201B);

  /// Raised surface: table headers, hover fills, inset wells.
  static const Color darkSurfaceHigh = Color(0xFF1B2A23);

  /// Input fields — slightly recessed from a card.
  static const Color darkField = Color(0xFF121A16);

  static const Color darkBorder = Color(0xFF2C3B33);
  static const Color darkBorderStrong = Color(0xFF3B5145);

  static const Color darkPrimary = Color(0xFF5EC79A);
  static const Color darkOnPrimary = Color(0xFF06251A);
  static const Color darkPrimaryContainer = Color(0xFF234134);

  static const Color darkOnSurface = Color(0xFFECF3EE);
  static const Color darkOnSurfaceVariant = Color(0xFFB4C4BA);

  // ── Light palette ─────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF7F8F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFEAF0EA);
  static const Color lightBorder = Color(0xFFDCE5DC);
  static const Color lightPrimary = Color(0xFF234B36);
  static const Color lightOnSurface = Color(0xFF222222);
  static const Color lightOnSurfaceVariant = Color(0xFF555555);

  static ThemeData light() => _build(
    brightness: Brightness.light,
    background: lightBackground,
    surface: lightSurface,
    surfaceHigh: lightSurfaceHigh,
    field: lightSurface,
    border: lightBorder,
    borderStrong: const Color(0xFFC6D3C6),
    primary: lightPrimary,
    onPrimary: Colors.white,
    primaryContainer: lightSurfaceHigh,
    onSurface: lightOnSurface,
    onSurfaceVariant: lightOnSurfaceVariant,
    hint: const Color(0xFF888888),
    error: const Color(0xFFDC3545),
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    background: darkBackground,
    surface: darkSurface,
    surfaceHigh: darkSurfaceHigh,
    field: darkField,
    border: darkBorder,
    borderStrong: darkBorderStrong,
    primary: darkPrimary,
    onPrimary: darkOnPrimary,
    primaryContainer: darkPrimaryContainer,
    onSurface: darkOnSurface,
    onSurfaceVariant: darkOnSurfaceVariant,
    hint: const Color(0xFF82988B),
    error: const Color(0xFFFF6B7A),
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceHigh,
    required Color field,
    required Color border,
    required Color borderStrong,
    required Color primary,
    required Color onPrimary,
    required Color primaryContainer,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color hint,
    required Color error,
  }) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: isDark ? darkOnSurface : lightPrimary,
      secondary: primary,
      onSecondary: onPrimary,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHigh,
      onSurfaceVariant: onSurfaceVariant,
      outline: borderStrong,
      outlineVariant: border,
      error: error,
      onError: Colors.white,
      errorContainer: error.withValues(alpha: isDark ? 0.22 : 0.10),
      onErrorContainer: error,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: onSurface,
      onInverseSurface: surface,
    );

    OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );

    const buttonText = TextStyle(
      inherit: false,
      fontFamily: 'DMSans',
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      fontFamily: 'DMSans',
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme().apply(
        fontFamily: 'DMSans',
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      iconTheme: IconThemeData(color: onSurfaceVariant),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: outline(border),
        enabledBorder: outline(border),
        focusedBorder: outline(primary, 2),
        errorBorder: outline(error),
        focusedErrorBorder: outline(error, 2),
        hintStyle: TextStyle(color: hint, fontSize: 14),
        labelStyle: TextStyle(color: onSurfaceVariant),
        prefixIconColor: onSurfaceVariant,
        suffixIconColor: onSurfaceVariant,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? onSurface : primary,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: buttonText.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: buttonText.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.35)
              : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? primary : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(onPrimary),
        side: BorderSide(color: borderStrong, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : borderStrong,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceHigh,
        circularTrackColor: surfaceHigh,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? surfaceHigh : const Color(0xFF2B332E),
          borderRadius: BorderRadius.circular(8),
          border: isDark ? Border.all(color: border) : null,
        ),
        textStyle: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 12,
          color: isDark ? onSurface : Colors.white,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(surface),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: border),
            ),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surfaceHigh : lightPrimary,
        contentTextStyle: TextStyle(
          inherit: false,
          fontFamily: 'DMSans',
          color: isDark ? onSurface : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
        titleTextStyle: TextStyle(
          inherit: false,
          fontFamily: 'DMSans',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        contentTextStyle: TextStyle(
          inherit: false,
          fontFamily: 'DMSans',
          fontSize: 14,
          color: onSurfaceVariant,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          onSurfaceVariant.withValues(alpha: 0.35),
        ),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(8),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurfaceVariant,
        textColor: onSurface,
      ),
    );
  }

  /// Card shadow — omitted in dark mode, where elevation reads as a lighter
  /// surface plus a border rather than a cast shadow.
  static List<BoxShadow>? cardShadow(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) return null;
    return const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 8)),
    ];
  }

  /// Convenience: the border colour for cards/inputs in the active theme.
  static Color border(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  /// Convenience: page background for the active theme.
  static Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  /// Keeps [AppColors] in sync for code that reads tokens statically.
  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
}
