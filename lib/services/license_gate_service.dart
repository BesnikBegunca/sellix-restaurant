import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'activation_license_controller.dart';
import 'api_enforcement_parser.dart';
import 'database_service.dart';

enum LicenseBlockCode {
  licenseExpired,
  licenseSuspended,
  businessSuspended,
  deviceSuspended,
}

class LicenseBlockedException implements Exception {
  LicenseBlockedException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LicenseGateService extends ChangeNotifier {
  LicenseGateService._();
  static final LicenseGateService instance = LicenseGateService._();

  static const String kMetaBlocked = 'license_gate_blocked';
  static const String kMetaCode = 'license_gate_code';
  static const String kMetaMessage = 'license_gate_message';
  static const String kMetaBlockedAt = 'license_gate_blocked_at';
  static const String kLicenseExpiresAtMeta = 'activation_license_expires_at';

  /// Wired from [main] to stop sync without circular imports.
  void Function()? onBlocked;

  bool _blocked = false;
  LicenseBlockCode? _code;
  String? _message;
  DateTime? _blockedAt;

  bool get isBlocked => _blocked;
  LicenseBlockCode? get code => _code;
  String? get message => _message;
  String? get reason => _message;
  DateTime? get blockedAt => _blockedAt;

  Future<void> loadPersistedState() async {
    final db = DatabaseService.instance;
    if (await db.getAppMeta(kMetaBlocked) != 'true') {
      _blocked = false;
      _code = null;
      _message = null;
      _blockedAt = null;
      return;
    }
    _blocked = true;
    _code = _codeFromStorage(await db.getAppMeta(kMetaCode));
    final msg = await db.getAppMeta(kMetaMessage);
    _message = (msg != null && msg.isNotEmpty)
        ? msg
        : _defaultMessageForCode(_code);
    _blockedAt = _parseAt(await db.getAppMeta(kMetaBlockedAt));
    notifyListeners();
  }

  Future<bool> checkAndBlockIfLocallyExpired() async {
    final raw =
        await DatabaseService.instance.getAppMeta(kLicenseExpiresAtMeta);
    final expires = _parseAt(raw);
    if (expires == null) return false;
    if (DateTime.now().toUtc().isAfter(expires.toUtc())) {
      await block(
        code: LicenseBlockCode.licenseExpired,
        message:
            'Licenca ka skaduar. Kontaktoni administratorin për rinovim.',
      );
      return true;
    }
    return false;
  }

  Future<void> block({
    required LicenseBlockCode code,
    String? message,
  }) async {
    final resolved = message ?? _defaultMessageForCode(code);
    if (_blocked && _code == code && _message == resolved) return;
    _blocked = true;
    _code = code;
    _message = resolved;
    _blockedAt = DateTime.now().toUtc();
    await _persistState();
    onBlocked?.call();
    notifyListeners();
    if (kDebugMode) debugPrint('LicenseGateService: blocked — $code');
  }

  Future<void> blockFromApiCode(String apiCode, {String? message}) async {
    final mapped = _blockCodeFromApi(apiCode);
    if (mapped == null) return;
    await block(code: mapped, message: message);
  }

  Future<void> unblock() async {
    if (!_blocked) return;
    _blocked = false;
    _code = null;
    _message = null;
    _blockedAt = null;
    await clearPersistedStateQuietly();
    notifyListeners();
    await ActivationLicenseController.instance.reloadFromStorage();
  }

  void enforceOrThrow() {
    if (!_blocked) return;
    throw LicenseBlockedException(
      _message ?? 'Licenca është pezulluar. Kontaktoni administratorin.',
    );
  }

  Future<bool> handleDioException(DioException error) async {
    if (ApiEnforcementParser.actionFromDio(error) !=
        ApiEnforcementAction.blockLicense) {
      return false;
    }
    final apiCode =
        ApiEnforcementParser.codeFromData(error.response?.data) ??
        ApiEnforcementCodes.licenseSuspended;
    await blockFromApiCode(
      apiCode,
      message: ApiEnforcementParser.messageFromData(error.response?.data),
    );
    return true;
  }

  @Deprecated('Use ApiEnforcementParser.requiresLicenseBlock')
  static bool isLicenseSuspendedError(DioException error) {
    return ApiEnforcementParser.requiresLicenseBlock(error);
  }

  static Future<void> clearPersistedStateQuietly() async {
    final db = DatabaseService.instance;
    await db.setAppMeta(kMetaBlocked, '');
    await db.setAppMeta(kMetaCode, '');
    await db.setAppMeta(kMetaMessage, '');
    await db.setAppMeta(kMetaBlockedAt, '');
  }

  /// Clears gate RAM + persistence when activation is revoked (no [notifyListeners]).
  Future<void> clearForRevocation() async {
    _blocked = false;
    _code = null;
    _message = null;
    _blockedAt = null;
    await clearPersistedStateQuietly();
  }

  Future<void> _persistState() async {
    final db = DatabaseService.instance;
    await db.setAppMeta(kMetaBlocked, 'true');
    await db.setAppMeta(kMetaCode, _code?.name ?? '');
    await db.setAppMeta(kMetaMessage, _message ?? '');
    await db.setAppMeta(
      kMetaBlockedAt,
      _blockedAt?.toUtc().toIso8601String() ?? '',
    );
  }

  static LicenseBlockCode? _blockCodeFromApi(String apiCode) {
    switch (apiCode) {
      case ApiEnforcementCodes.licenseExpired:
        return LicenseBlockCode.licenseExpired;
      case ApiEnforcementCodes.licenseSuspended:
        return LicenseBlockCode.licenseSuspended;
      case ApiEnforcementCodes.businessSuspended:
        return LicenseBlockCode.businessSuspended;
      case ApiEnforcementCodes.deviceSuspended:
        return LicenseBlockCode.deviceSuspended;
      default:
        return null;
    }
  }

  static LicenseBlockCode? _codeFromStorage(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final v in LicenseBlockCode.values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  static String _defaultMessageForCode(LicenseBlockCode? code) {
    switch (code) {
      case LicenseBlockCode.licenseExpired:
        return 'Licenca ka skaduar. Kontaktoni administratorin.';
      case LicenseBlockCode.licenseSuspended:
        return 'Licenca është pezulluar. Kontaktoni administratorin.';
      case LicenseBlockCode.businessSuspended:
        return 'Biznesi është pezulluar. Kontaktoni administratorin.';
      case LicenseBlockCode.deviceSuspended:
        return 'Pajisja është pezulluar. Kontaktoni administratorin.';
      case null:
        return 'Licenca është pezulluar. Kontaktoni administratorin.';
    }
  }

  static DateTime? _parseAt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }
}
