import 'package:flutter/material.dart';

import 'database_service.dart';

enum AppLanguage { albanian, english }

class AppLanguageService extends ChangeNotifier {
  AppLanguageService._();
  static final instance = AppLanguageService._();

  static const _metaKey = 'app_language';
  AppLanguage _language = AppLanguage.albanian;

  AppLanguage get language => _language;
  Locale get locale => _language == AppLanguage.english
      ? const Locale('en')
      : const Locale('sq');
  bool get isEnglish => _language == AppLanguage.english;

  Future<void> load() async {
    final saved = await DatabaseService.instance.getAppMeta(_metaKey);
    _language = saved == 'en' ? AppLanguage.english : AppLanguage.albanian;
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    await DatabaseService.instance.setAppMeta(
      _metaKey,
      language == AppLanguage.english ? 'en' : 'sq',
    );
    notifyListeners();
  }

  String t(String sq, String en) => isEnglish ? en : sq;
}
