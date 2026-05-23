import 'package:flutter/foundation.dart';

import 'database_service.dart';
import 'license_gate_service.dart';

/// In-memory license expiry for UI (badge) — synced with [app_meta].
///
/// Notifies listeners after refresh, verify, unblock, or activation persist.
class ActivationLicenseController extends ChangeNotifier {
  ActivationLicenseController._();
  static final ActivationLicenseController instance =
      ActivationLicenseController._();

  String? _expiresAtIso;

  String? get expiresAtIso => _expiresAtIso;

  /// Ditë të mbetura deri në skadim (`null` = pa datë të ruajtur).
  int? get daysRemaining {
    final raw = _expiresAtIso;
    if (raw == null || raw.trim().isEmpty) return null;
    final expires = DateTime.tryParse(raw.trim());
    if (expires == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expires.year, expires.month, expires.day);
    return expiryDay.difference(today).inDays;
  }

  /// Reads [activation_license_expires_at] from SQLite into memory.
  Future<void> reloadFromStorage() async {
    final raw = await DatabaseService.instance.getAppMeta(
      LicenseGateService.kLicenseExpiresAtMeta,
    );
    final normalized = (raw == null || raw.trim().isEmpty) ? null : raw.trim();
    if (normalized == _expiresAtIso) return;
    _expiresAtIso = normalized;
    notifyListeners();
    if (kDebugMode) {
      debugPrint(
        'ActivationLicenseController: reloaded expiresAt=$_expiresAtIso '
        'days=$daysRemaining',
      );
    }
  }

  /// Persists ISO expiry, updates cache, notifies UI.
  Future<void> setExpiresAt(String? iso8601) async {
    final normalized =
        (iso8601 == null || iso8601.trim().isEmpty) ? null : iso8601.trim();
    if (normalized == _expiresAtIso) return;

    await DatabaseService.instance.setAppMeta(
      LicenseGateService.kLicenseExpiresAtMeta,
      normalized ?? '',
    );
    _expiresAtIso = normalized;
    notifyListeners();
    if (kDebugMode) {
      debugPrint(
        'ActivationLicenseController: set expiresAt=$_expiresAtIso '
        'days=$daysRemaining',
      );
    }
  }

  /// Clears in-memory expiry (e.g. on full activation revoke).
  void clearInMemory() {
    if (_expiresAtIso == null) return;
    _expiresAtIso = null;
    notifyListeners();
  }
}
