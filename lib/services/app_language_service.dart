import 'package:flutter/material.dart';

import 'app_translations.dart';
import 'database_service.dart';

/// Languages the app ships with.
enum AppLanguage {
  albanian,
  english,
  french,
  italian,
  german,
  swissGerman;

  /// Stable code persisted in app metadata. Never change these — existing
  /// installs read them back on startup.
  String get code => switch (this) {
    AppLanguage.albanian => 'sq',
    AppLanguage.english => 'en',
    AppLanguage.french => 'fr',
    AppLanguage.italian => 'it',
    AppLanguage.german => 'de',
    AppLanguage.swissGerman => 'de_CH',
  };

  Locale get locale => switch (this) {
    AppLanguage.swissGerman => const Locale('de', 'CH'),
    _ => Locale(code),
  };

  /// Name of the language written in that language.
  String get nativeName => switch (this) {
    AppLanguage.albanian => 'Shqip',
    AppLanguage.english => 'English',
    AppLanguage.french => 'Français',
    AppLanguage.italian => 'Italiano',
    AppLanguage.german => 'Deutsch',
    AppLanguage.swissGerman => 'Schwiizerdütsch',
  };

  /// Short badge shown next to the language name.
  String get badge => switch (this) {
    AppLanguage.albanian => 'SQ',
    AppLanguage.english => 'EN',
    AppLanguage.french => 'FR',
    AppLanguage.italian => 'IT',
    AppLanguage.german => 'DE',
    AppLanguage.swissGerman => 'CH',
  };

  String get flag => switch (this) {
    AppLanguage.albanian => '🇦🇱',
    AppLanguage.english => '🇬🇧',
    AppLanguage.french => '🇫🇷',
    AppLanguage.italian => '🇮🇹',
    AppLanguage.german => '🇩🇪',
    AppLanguage.swissGerman => '🇨🇭',
  };

  static AppLanguage fromCode(String? code) {
    for (final l in AppLanguage.values) {
      if (l.code == code) return l;
    }
    return AppLanguage.albanian;
  }
}

class AppLanguageService extends ChangeNotifier {
  AppLanguageService._();
  static final instance = AppLanguageService._();

  static const _metaKey = 'app_language';
  AppLanguage _language = AppLanguage.albanian;

  AppLanguage get language => _language;
  Locale get locale => _language.locale;

  /// Every locale the app declares support for.
  static List<Locale> get supportedLocales =>
      AppLanguage.values.map((l) => l.locale).toList(growable: false);

  bool get isEnglish => _language == AppLanguage.english;

  Future<void> load() async {
    final saved = await DatabaseService.instance.getAppMeta(_metaKey);
    _language = AppLanguage.fromCode(saved);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    await DatabaseService.instance.setAppMeta(_metaKey, language.code);
  }

  /// Translate a string pair.
  ///
  /// Call sites pass the Albanian and English wording. For the four other
  /// languages the English string is looked up in [AppTranslations]; when a
  /// phrase has no entry yet it falls back to English, which is always a
  /// readable result rather than a missing-key placeholder.
  String t(String sq, String en) {
    switch (_language) {
      case AppLanguage.albanian:
        return sq;
      case AppLanguage.english:
        return en;
      case AppLanguage.french:
      case AppLanguage.italian:
      case AppLanguage.german:
      case AppLanguage.swissGerman:
        return AppTranslations.lookup(_language, en) ?? en;
    }
  }
}
