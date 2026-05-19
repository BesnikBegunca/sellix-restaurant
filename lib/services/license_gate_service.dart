import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Blocks desktop POS when the server rejects access (suspended business/license).
///
/// Unlike [ActivationService.revokeActivation], blocking keeps local activation
/// and tokens so the user can retry after reactivation.
class LicenseGateService extends ChangeNotifier {
  LicenseGateService._();
  static final LicenseGateService instance = LicenseGateService._();

  bool _blocked = false;
  String? _reason;

  bool get isBlocked => _blocked;
  String? get reason => _reason;

  void block({String? reason}) {
    if (_blocked && _reason == reason) return;
    _blocked = true;
    _reason = reason ?? 'Licenca është pezulluar. Kontaktoni administratorin.';
    notifyListeners();
    if (kDebugMode) {
      debugPrint('LicenseGateService: blocked — $_reason');
    }
  }

  void unblock() {
    if (!_blocked) return;
    _blocked = false;
    _reason = null;
    notifyListeners();
    if (kDebugMode) debugPrint('LicenseGateService: unblocked');
  }

  /// Returns true when a [DioException] indicates license/business suspension.
  static bool isLicenseSuspendedError(DioException error) {
    if (error.response?.statusCode != 403) return false;
    final message = _messageFromResponse(error.response?.data);
    if (message == null || message.isEmpty) return true;
    final lower = message.toLowerCase();
    return lower.contains('suspend') ||
        lower.contains('not active') ||
        lower.contains('expired') ||
        lower.contains('pezull');
  }

  static String? _messageFromResponse(dynamic data) {
    if (data is Map) {
      final message = data['message'];
      if (message is String) return message;
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
    }
    if (data is String) return data;
    return null;
  }
}
