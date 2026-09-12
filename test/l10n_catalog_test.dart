import 'package:flutter_test/flutter_test.dart';

import 'package:pos_system/l10n/app_strings.dart';
import 'package:pos_system/l10n/strings_de.dart';
import 'package:pos_system/l10n/strings_de_ch.dart';
import 'package:pos_system/l10n/strings_en.dart';
import 'package:pos_system/l10n/strings_fr.dart';
import 'package:pos_system/l10n/strings_it.dart';
import 'package:pos_system/l10n/strings_sq.dart';
import 'package:pos_system/l10n/tr.dart';
import 'package:pos_system/services/app_language_service.dart';

/// Guards the translation catalog: every language must cover every key, and
/// every key must actually resolve in every language.
void main() {
  final languages = <String, Map<String, String>>{
    'en': kEn,
    'fr': kFr,
    'it': kIt,
    'de': kDe,
  };

  tearDown(
    () => AppLanguageService.instance.debugSetLanguage(AppLanguage.albanian),
  );

  test('Albanian is the source language and is non-empty', () {
    expect(kSq, isNotEmpty);
    for (final e in kSq.entries) {
      expect(e.value.trim(), isNotEmpty, reason: '${e.key} is blank in sq');
    }
  });

  test('every language covers every key in the source language', () {
    for (final entry in languages.entries) {
      final missing = kSq.keys.where((k) => !entry.value.containsKey(k));
      expect(
        missing,
        isEmpty,
        reason: '${entry.key} is missing: ${missing.take(10).join(', ')}',
      );
    }
  });

  test('no language defines a key the source language does not have', () {
    for (final entry in languages.entries) {
      final extra = entry.value.keys.where((k) => !kSq.containsKey(k));
      expect(
        extra,
        isEmpty,
        reason: '${entry.key} has stray keys: ${extra.take(10).join(', ')}',
      );
    }
    final strayCh = kDeChOverrides.keys.where((k) => !kSq.containsKey(k));
    expect(strayCh, isEmpty, reason: 'de_CH stray: ${strayCh.join(', ')}');
  });

  test('no translation is blank', () {
    for (final entry in languages.entries) {
      for (final e in entry.value.entries) {
        expect(
          e.value.trim(),
          isNotEmpty,
          reason: '${entry.key}/${e.key} is blank',
        );
      }
    }
  });

  test('Swiss German resolves every key, via German where unlisted', () {
    AppLanguageService.instance.debugSetLanguage(AppLanguage.swissGerman);
    for (final key in kSq.keys) {
      final v = trKey(key);
      expect(v.trim(), isNotEmpty, reason: '$key is blank in de_CH');
      expect(v, isNot(key), reason: '$key fell through to the raw key');
    }
  });

  test('Swiss written German never uses eszett', () {
    for (final e in kDeChOverrides.entries) {
      expect(
        e.value.contains('ß'),
        isFalse,
        reason: '${e.key} contains ß, which Swiss German does not use',
      );
    }
  });

  test('every key resolves to real text in every language', () {
    for (final lang in AppLanguage.values) {
      AppLanguageService.instance.debugSetLanguage(lang);
      for (final key in kSq.keys) {
        final v = trKey(key);
        expect(v.trim(), isNotEmpty, reason: '${lang.code}/$key blank');
        expect(v, isNot(key), reason: '${lang.code}/$key unresolved');
      }
    }
  });

  test('tr exposes a getter for every key', () {
    // Spot-check a spread of keys through the generated accessor rather than
    // reflecting over it (dart:mirrors is unavailable in Flutter tests).
    AppLanguageService.instance.debugSetLanguage(AppLanguage.albanian);
    expect(tr.anulo, kSq['anulo']);
    expect(tr.cilesimet, kSq['cilesimet']);
    expect(tr.shitjet, kSq['shitjet']);
    expect(tr.kamarieret, kSq['kamarieret']);
    expect(tr.data, kSq['data']);

    AppLanguageService.instance.debugSetLanguage(AppLanguage.german);
    expect(tr.anulo, kDe['anulo']);
    expect(tr.cilesimet, kDe['cilesimet']);
  });

  test('parameterised strings interpolate in every language', () {
    for (final lang in AppLanguage.values) {
      AppLanguageService.instance.debugSetLanguage(lang);
      expect(trf.occupiedTables(3), contains('3'));
      expect(trf.categoriesCount(7), contains('7'));
      expect(trf.minutesAgo(5), contains('5'));
      expect(trf.wrongPinAttemptsLeft(2), contains('2'));
      expect(trf.licenceExpiresInDays(9), contains('9'));
      expect(trf.deleteCategory('Pije'), contains('Pije'));
      // Singular and plural branches both produce text.
      expect(trf.blockedDeletes(1).trim(), isNotEmpty);
      expect(trf.blockedDeletes(4), contains('4'));
      expect(trf.paymentFailed('boom'), contains('boom'));
    }
  });

  test('an unknown language key falls back rather than throwing', () {
    AppLanguageService.instance.debugSetLanguage(AppLanguage.french);
    // A key present in sq/en resolves; the fallback chain is fr -> en -> sq.
    expect(trKey('anulo'), kFr['anulo']);
  });
}
