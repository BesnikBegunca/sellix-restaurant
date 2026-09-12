import '../services/app_language_service.dart';
import 'strings_de.dart';
import 'strings_de_ch.dart';
import 'strings_en.dart';
import 'strings_fr.dart';
import 'strings_it.dart';
import 'strings_sq.dart';

export 'app_strings_fn.dart';

/// Every user-facing string in the app, keyed by a stable identifier.
///
/// Call sites read them through [tr] (`tr.anulo`), and the value follows
/// [AppLanguageService.instance.language]. Albanian is the source language and
/// is always complete; a language missing an entry falls back to English and
/// then to Albanian, so a gap shows real words rather than a blank or a key.
///
/// Strings that interpolate values are methods on [AppStringsFn] (`trf.…`),
/// since a constant map cannot hold them.
///
/// Product and category names are user data, not UI text, and are never
/// translated.
String trKey(String key) {
  final lang = AppLanguageService.instance.language;
  final direct = _tableFor(lang)[key];
  if (direct != null) return direct;
  if (lang != AppLanguage.english) {
    final en = kEn[key];
    if (en != null) return en;
  }
  final sq = kSq[key];
  if (sq != null) return sq;
  assert(false, 'Missing translation key: $key');
  return key;
}

Map<String, String> _tableFor(AppLanguage lang) => switch (lang) {
  AppLanguage.albanian => kSq,
  AppLanguage.english => kEn,
  AppLanguage.french => kFr,
  AppLanguage.italian => kIt,
  AppLanguage.german => kDe,
  AppLanguage.swissGerman => _deCh,
};

/// Swiss German lists only the entries that differ from standard German, so
/// resolve it as German overlaid with those overrides.
Map<String, String> get _deCh => _deChCache ??= {...kDe, ...kDeChOverrides};
Map<String, String>? _deChCache;

/// Test seam: drop the memoised Swiss German table.
void debugResetL10nCache() => _deChCache = null;

/// Number of keys in the source language — used by tests to assert parity.
int get l10nKeyCount => kSq.length;

/// The translation tables, for tests that check coverage.
Map<AppLanguage, Map<String, String>> get l10nTables => {
  AppLanguage.albanian: kSq,
  AppLanguage.english: kEn,
  AppLanguage.french: kFr,
  AppLanguage.italian: kIt,
  AppLanguage.german: kDe,
  AppLanguage.swissGerman: _deCh,
};
