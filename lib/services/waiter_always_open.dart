import 'package:flutter/foundation.dart';

/// "Always open" për kamarierin: kur është ON, pas PRINTO / pagesës
/// kthehet te tavolinat në vend të ekranit të login-it.
///
/// Ruhet në memorie për kamarier (mbetet derisa të mbyllet aplikacioni).
class WaiterAlwaysOpen extends ChangeNotifier {
  WaiterAlwaysOpen._();
  static final WaiterAlwaysOpen instance = WaiterAlwaysOpen._();

  final Set<String> _enabled = <String>{};

  bool isEnabled(String waiterName) => _enabled.contains(waiterName);

  void setEnabled(String waiterName, bool value) {
    final changed = value ? _enabled.add(waiterName) : _enabled.remove(waiterName);
    if (changed) notifyListeners();
  }
}
