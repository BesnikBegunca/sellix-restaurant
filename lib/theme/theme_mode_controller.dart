import 'package:flutter/foundation.dart';

import '../services/database_service.dart';

class ThemeModeController extends ChangeNotifier {
  ThemeModeController._();

  static final ThemeModeController instance = ThemeModeController._();
  static const _storageKey = 'app_theme_mode';

  bool _isDark = false;
  bool get isDark => _isDark;

  Future<void> load() async {
    final value = await DatabaseService.instance.getAppMeta(_storageKey);
    _isDark = value == 'dark';
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    await DatabaseService.instance.setAppMeta(
      _storageKey,
      value ? 'dark' : 'light',
    );
  }
}
