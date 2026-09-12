import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_system/services/app_language_service.dart';
import 'package:pos_system/services/app_translations.dart';
import 'package:pos_system/theme/app_colors.dart';
import 'package:pos_system/theme/app_theme.dart';
import 'package:pos_system/theme/theme_mode_controller.dart';

/// Relative luminance, used to assert that dark surfaces really are dark.
double _luminance(Color c) => c.computeLuminance();

void main() {
  group('AppColors follows the active appearance', () {
    tearDown(() => ThemeModeController.instance.debugSetDark(false));

    test('surface and text tokens invert between light and dark', () {
      ThemeModeController.instance.debugSetDark(false);
      final lightBg = AppColors.beige;
      final lightText = AppColors.darkGreenText;
      final lightCard = AppColors.white;

      ThemeModeController.instance.debugSetDark(true);
      final darkBg = AppColors.beige;
      final darkText = AppColors.darkGreenText;
      final darkCard = AppColors.white;

      // The page background must actually get darker, and the body text
      // lighter — this is what was broken when the tokens were const.
      expect(_luminance(darkBg), lessThan(_luminance(lightBg)));
      expect(_luminance(darkCard), lessThan(_luminance(lightCard)));
      expect(_luminance(darkText), greaterThan(_luminance(lightText)));
    });

    test('text stays readable against its surface in both modes', () {
      for (final dark in [false, true]) {
        ThemeModeController.instance.debugSetDark(dark);
        final surface = AppColors.white;
        final body = AppColors.darkGreenText;
        // A crude contrast proxy: body text and card surface must sit far
        // apart in luminance.
        expect(
          (_luminance(body) - _luminance(surface)).abs(),
          greaterThan(0.4),
          reason: 'body text on card, dark=$dark',
        );
      }
    });

    test('fields sit at or below the card surface in dark mode', () {
      ThemeModeController.instance.debugSetDark(true);
      expect(
        _luminance(AppColors.fieldFill),
        lessThanOrEqualTo(_luminance(AppColors.white)),
      );
    });
  });

  group('AppTheme', () {
    test('builds a dark scheme whose surfaces are genuinely dark', () {
      final dark = AppTheme.dark();
      expect(dark.brightness, Brightness.dark);
      expect(_luminance(dark.colorScheme.surface), lessThan(0.1));
      expect(_luminance(dark.scaffoldBackgroundColor), lessThan(0.1));
      // Accent must be light enough to read on those surfaces.
      expect(_luminance(dark.colorScheme.primary), greaterThan(0.3));
    });

    test('light and dark expose the same component themes', () {
      for (final t in [AppTheme.light(), AppTheme.dark()]) {
        expect(t.inputDecorationTheme.filled, isTrue);
        expect(t.cardTheme.color, isNotNull);
        expect(t.dialogTheme.backgroundColor, isNotNull);
        expect(t.dividerTheme.color, isNotNull);
        expect(t.snackBarTheme.backgroundColor, isNotNull);
      }
    });
  });

  group('Languages', () {
    tearDown(
      () => AppLanguageService.instance.debugSetLanguage(AppLanguage.albanian),
    );

    test('ships six languages with distinct codes and locales', () {
      expect(AppLanguage.values.length, 6);
      final codes = AppLanguage.values.map((l) => l.code).toSet();
      expect(codes.length, 6);
      expect(
        codes,
        containsAll(<String>['sq', 'en', 'fr', 'it', 'de', 'de_CH']),
      );
      expect(AppLanguageService.supportedLocales.length, 6);
      expect(AppLanguage.swissGerman.locale, const Locale('de', 'CH'));
    });

    test('round-trips every language code', () {
      for (final l in AppLanguage.values) {
        expect(AppLanguage.fromCode(l.code), l);
      }
      // Unknown / missing codes fall back rather than throwing.
      expect(AppLanguage.fromCode(null), AppLanguage.albanian);
      expect(AppLanguage.fromCode('xx'), AppLanguage.albanian);
    });

    test('t() returns the right language, falling back to English', () {
      const sq = 'Cilësimet';
      const en = 'Settings';
      final svc = AppLanguageService.instance;

      svc.debugSetLanguage(AppLanguage.albanian);
      expect(svc.t(sq, en), sq);

      svc.debugSetLanguage(AppLanguage.english);
      expect(svc.t(sq, en), en);

      svc.debugSetLanguage(AppLanguage.french);
      expect(svc.t(sq, en), 'Paramètres');

      svc.debugSetLanguage(AppLanguage.italian);
      expect(svc.t(sq, en), 'Impostazioni');

      svc.debugSetLanguage(AppLanguage.german);
      expect(svc.t(sq, en), 'Einstellungen');

      // Untranslated phrases fall back to English, never to a blank or a key.
      svc.debugSetLanguage(AppLanguage.french);
      expect(
        svc.t('Diçka', 'Something untranslated'),
        'Something untranslated',
      );
    });

    test('Swiss German falls through to standard German when unlisted', () {
      final svc = AppLanguageService.instance;
      svc.debugSetLanguage(AppLanguage.swissGerman);
      // Has its own entry.
      expect(svc.t('Dil', 'Log out'), 'Abmälde');
      // No Swiss-specific entry -> standard German.
      expect(svc.t('Fitime', 'Profits'), 'Gewinne');
    });

    test('every language has a name, badge and flag', () {
      for (final l in AppLanguage.values) {
        expect(l.nativeName, isNotEmpty);
        expect(l.badge, isNotEmpty);
        expect(l.flag, isNotEmpty);
      }
    });

    test('the nav labels are translated in all four catalog languages', () {
      const navLabels = [
        'Overview',
        'Waiters',
        'Managers',
        'Expenses',
        'Profits',
        'Sales',
        'Menu',
        'Tables',
        'Settings',
        'Refunds',
        'Audit log',
        'Log out',
      ];
      for (final lang in [
        AppLanguage.french,
        AppLanguage.italian,
        AppLanguage.german,
      ]) {
        for (final label in navLabels) {
          expect(
            AppTranslations.lookup(lang, label),
            isNotNull,
            reason: '$label missing for ${lang.code}',
          );
        }
      }
    });
  });
}
