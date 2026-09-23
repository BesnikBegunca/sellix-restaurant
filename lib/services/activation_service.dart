import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/activation_response.dart';
import '../models/activation_validate_response.dart';
import '../models/device_transfer_response.dart';
import '../models/sellix_license.dart';
import 'api_client.dart';
import 'database_schema.dart';
import 'database_service.dart';
import 'activation_state_controller.dart';
import 'activation_license_controller.dart';
import 'api_enforcement_parser.dart';
import 'license_gate_service.dart';
import 'local_tenant_data_service.dart';
import 'runtime_config_service.dart';
import 'secure_activation_token_store.dart';
import 'sellix_license_client.dart';
import '../l10n/tr.dart';

/// Manages device activation against the NestJS backend.
///
/// ## Lifecycle
/// 1. [loadPersistedActivation] — call once at startup to restore the stored
///    activation and wire [ApiClient] + [DatabaseSchema] tenant IDs.
/// 2. [validateActivationKey] — optional pre-check from [ActivationScreen].
/// 3. [activateDesktop] — call from [ActivationScreen] for first-time setup.
/// 4. [verifyActivation] — call at startup (after loading) to confirm the
///    stored token is still valid; revokes locally on 401.
class ActivationService {
  ActivationService._();
  static final ActivationService instance = ActivationService._();

  /// Shown on [DeviceRevokedScreen] after server-side device revoke (401).
  /// Resolved per language, so it cannot be a const.
  static String get kDefaultServerRevokeMessage =>
      tr.deviceDeactivatedByAdmin;

  /// pos_api `PATCH /devices/:id/revoke` is SuperAdmin-only today.
  /// When the API allows device self-revoke, set this to `true`.
  static const bool kServerRevokeAvailableToDesktop = false;

  // ── app_meta keys ─────────────────────────────────────────────────────────
  static const String kMetaBusinessId = 'activation_business_id';
  static const String kMetaBranchId = 'activation_branch_id';
  static const String kMetaDeviceId = 'activation_device_id';
  static const String kMetaLicenseKey = 'activation_license_key';
  static const String kMetaBusinessJson = 'activation_business_json';
  static const String kMetaLastCheckAt = 'license_last_check_at';
  static const String kMetaOfferAdminPin = 'offer_admin_pin_on_next_login';

  static const Duration kOfflineGrace = Duration(days: 7);

  static const String _kBusinessId = kMetaBusinessId;
  static const String _kBranchId = kMetaBranchId;
  static const String _kDeviceId = kMetaDeviceId;
  static const String _kLicenseExpiresAt = 'activation_license_expires_at';
  static const String _kCompleted = 'activation_completed';

  // ── in-memory state ───────────────────────────────────────────────────────
  String? _businessId;
  String? _branchId;
  String? _serverDeviceId;
  bool _activated = false;
  bool _handlingRevoke = false;
  bool _offerAdminPinOnNextLogin = false;

  bool get isActivated => _activated;
  bool get offerAdminPinOnNextLogin => _offerAdminPinOnNextLogin;
  String? get businessId => _businessId;
  String? get branchId => _branchId;
  String? get serverDeviceId => _serverDeviceId;

  // ── public API ────────────────────────────────────────────────────────────

  /// Moves legacy plaintext tokens from [app_meta] into [SecureActivationTokenStore].
  ///
  /// Safe to call on every startup before [loadPersistedActivation].
  Future<void> migrateTokensFromAppMetaIfNeeded() async {
    final db = DatabaseService.instance;
    final store = SecureActivationTokenStore.instance;

    if (await store.hasValidTokenPair()) {
      await _clearLegacyTokenMeta(db);
      return;
    }

    final access = await db.getAppMeta(
      SecureActivationTokenStore.legacyAccessTokenKey,
    );
    final refresh = await db.getAppMeta(
      SecureActivationTokenStore.legacyRefreshTokenKey,
    );

    if (access == null || access.isEmpty) {
      await _clearLegacyTokenMeta(db);
      return;
    }

    final refreshValue = refresh ?? '';
    if (refreshValue.isEmpty && kDebugMode) {
      debugPrint(
        'ActivationService: legacy migration has no refresh token — '
        'activation may require re-login after restart',
      );
    }
    await store.saveTokens(accessToken: access, refreshToken: refreshValue);
    await _clearLegacyTokenMeta(db);

    if (kDebugMode) {
      debugPrint('Activation tokens migrated to secure storage');
    }
  }

  /// Restores activation from [app_meta] + [SecureActivationTokenStore].
  ///
  /// Returns `true` when the device is fully activated and wired for API calls.
  /// On hot restart, re-reads secure storage (not in-memory cache only).
  Future<bool> loadPersistedActivation() async {
    await migrateTokensFromAppMetaIfNeeded();

    final db = DatabaseService.instance;
    final store = SecureActivationTokenStore.instance;

    final completed = await db.getAppMeta(_kCompleted);
    final businessId = await db.getAppMeta(_kBusinessId);
    final branchId = await db.getAppMeta(_kBranchId);
    final deviceId = await db.getAppMeta(_kDeviceId);
    final licenseKey = await db.getAppMeta(kMetaLicenseKey);
    var accessToken = await store.readAccessToken();
    var refreshToken = await store.readRefreshToken();

    final completedOk = completed == 'true';
    final businessOk = _nonEmpty(businessId);
    final deviceOk = _nonEmpty(deviceId);
    final licenseOk = _nonEmpty(licenseKey) && isSellixLicenseKey(licenseKey!);

    if (kDebugMode) {
      debugPrint('[Activation] loadPersistedActivation:');
      debugPrint('[Activation]   activation_completed=$completedOk');
      debugPrint('[Activation]   businessId=${businessOk ? "yes" : "no"}');
      debugPrint('[Activation]   deviceId=${deviceOk ? "yes" : "no"}');
      debugPrint('[Activation]   sellixKey=${licenseOk ? "yes" : "no"}');
    }

    if (!completedOk) {
      _activated = false;
      _offerAdminPinOnNextLogin = false;
      if (kDebugMode) debugPrint('[Activation]   final activated=false');
      return false;
    }

    if (!businessOk || !deviceOk || !licenseOk) {
      if (kDebugMode) {
        debugPrint(
          '[Activation]   invalid persisted activation — clearing metadata',
        );
      }
      await revokeActivation();
      ActivationStateController.instance.setActivated(false);
      if (kDebugMode) debugPrint('[Activation]   final activated=false');
      return false;
    }

    final branch = _nonEmpty(branchId) ? branchId! : DatabaseSchema.kMainBranchId;
    if (!_nonEmpty(accessToken) || !_nonEmpty(refreshToken)) {
      await store.saveTokens(
        accessToken: licenseKey,
        refreshToken: licenseKey,
      );
      accessToken = licenseKey;
      refreshToken = licenseKey;
    }

    _businessId = businessId;
    _branchId = branch;
    _serverDeviceId = deviceId;
    _activated = true;

    ApiClient.instance.setAccessToken(accessToken!);
    DatabaseSchema.setActivatedTenant(
      businessId: businessId!,
      branchId: branch,
    );
    ActivationStateController.instance.setActivated(true);

    if (kDebugMode) debugPrint('[Activation]   final activated=true');
    await ActivationLicenseController.instance.reloadFromStorage();
    final offer = await db.getAppMeta(kMetaOfferAdminPin);
    _offerAdminPinOnNextLogin = offer == '1';
    return true;
  }

  /// First PIN after a new activation should offer to become the admin PIN.
  bool takeOfferAdminPinOnNextLogin() {
    if (!_offerAdminPinOnNextLogin) return false;
    _offerAdminPinOnNextLogin = false;
    unawaited(DatabaseService.instance.setAppMeta(kMetaOfferAdminPin, ''));
    return true;
  }

  /// Public for unit tests and diagnostics.
  static bool nonEmptyMeta(String? value) => _nonEmpty(value);

  static bool _nonEmpty(String? value) =>
      value != null && value.trim().isNotEmpty;

  /// POST /api/license/activate — checks the SelliX key and returns business data.
  Future<ActivationValidateResponse> validateActivationKey({
    required String activationKey,
  }) async {
    _assertProductionApiConfig();
    final key = normalizeSellixLicenseKey(activationKey);
    if (!isSellixLicenseKey(key)) {
      throw SellixLicenseException('not_found');
    }
    final deviceId = await DatabaseService.instance.syncDeviceId();
    final result = await SellixLicenseClient.instance.activate(
      licenseKey: key,
      deviceId: deviceId,
      deviceName: _detectHostname(),
    );
    if (!isRestaurantSector(result.business.sector)) {
      throw SellixLicenseException('not_restaurant');
    }
    final businessId = _businessIdFor(result.business, key);
    return ActivationValidateResponse(
      valid: true,
      businessId: businessId,
      businessName: result.business.name,
      branchCode: 'MAIN',
      branchName: result.business.city.isNotEmpty
          ? result.business.city
          : result.business.name,
      licenseStatus: result.license.status,
      licenseExpiresAt: result.license.expiresAt,
      business: result.business,
      license: result.license,
    );
  }

  /// Binds this device to the SelliX license and persists business data locally.
  Future<ActivationResponse> activateDesktop({
    required String activationKey,
    required String branchCode,
    String? businessName,
    SellixBusinessProfile? business,
    SellixLicenseInfo? license,
    bool liftUi = true,
  }) async {
    _assertProductionApiConfig();
    final key = normalizeSellixLicenseKey(activationKey);
    if (!isSellixLicenseKey(key)) {
      throw SellixLicenseException('not_found');
    }

    final deviceId = await DatabaseService.instance.syncDeviceId();
    final result = await SellixLicenseClient.instance.activate(
      licenseKey: key,
      deviceId: deviceId,
      deviceName: _detectHostname(),
    );
    if (!isRestaurantSector(result.business.sector)) {
      throw SellixLicenseException('not_restaurant');
    }

    final profile = business ?? result.business;
    final licenseInfo = license ?? result.license;
    final businessId = _businessIdFor(profile, key);
    final response = ActivationResponse(
      businessId: businessId,
      branchId: branchCode.trim().isEmpty
          ? DatabaseSchema.kMainBranchId
          : 'local-${branchCode.trim().toLowerCase()}',
      deviceId: deviceId,
      accessToken: key,
      refreshToken: key,
      licenseExpiresAt: parseSellixDateTime(licenseInfo.expiresAt),
    );
    await _persistActivation(
      response,
      businessName: businessName ?? profile.name,
      licenseKey: key,
      business: profile,
      license: licenseInfo,
      liftUi: liftUi,
    );
    return response;
  }

  /// Leaves activation screen / license overlay after the admin-PIN prompt.
  Future<void> completeActivationUi() async {
    ActivationStateController.instance.setActivated(true);
    await LicenseGateService.instance.unblock();
  }

  /// Submits POST /licenses/request-transfer to ask SuperAdmin to move the
  /// license from its current device to this one.
  ///
  /// Returns a [DeviceTransferResponse] with [isDuplicate] == true when the
  /// server reports a pending request already exists (HTTP 409) — the caller
  /// should treat this the same as a freshly created request.
  Future<DeviceTransferResponse> requestDeviceTransfer({
    required String licenseId,
    String? oldDeviceId,
    String? oldDeviceName,
    required String newDeviceFingerprint,
    required String newDeviceName,
    String reason = 'Device replacement requested from desktop POS',
  }) async {
    final body = <String, dynamic>{
      'licenseId': licenseId,
      if (oldDeviceId != null && oldDeviceId.isNotEmpty)
        'oldDeviceId': oldDeviceId,
      if (oldDeviceName != null && oldDeviceName.isNotEmpty)
        'oldDeviceName': oldDeviceName,
      'newDeviceFingerprint': newDeviceFingerprint,
      'newDeviceName': newDeviceName,
      'reason': reason,
    };

    if (kDebugMode) {
      debugPrint(
        'ActivationService: requestDeviceTransfer → $kEndpointRequestTransfer '
        'licenseId=$licenseId newDevice=$newDeviceName',
      );
    }

    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        kEndpointRequestTransfer,
        data: body,
      );
      final data = response.data;
      if (data == null) {
        throw Exception('Empty transfer request response from server.');
      }
      if (kDebugMode) {
        debugPrint(
          'ActivationService: transfer request created id=${data['id']} '
          'status=${data['status']}',
        );
      }
      return DeviceTransferResponse.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        if (kDebugMode) {
          debugPrint(
            'ActivationService: duplicate transfer request (409) — '
            'treating as pending',
          );
        }
        final errorData = e.response?.data;
        if (errorData is Map<String, dynamic>) {
          return DeviceTransferResponse.fromJson(errorData, isDuplicate: true);
        }
        return const DeviceTransferResponse(
          id: '',
          status: 'pending',
          isDuplicate: true,
        );
      }
      rethrow;
    }
  }

  /// Attempts `PATCH /devices/:id/revoke` on the server.
  ///
  /// Returns `true` if the server confirmed revoke. Returns `false` when skipped
  /// (no device id, desktop cannot auth, or network/auth error).
  ///
  /// Today [kServerRevokeAvailableToDesktop] is `false` because pos_api requires
  /// SuperAdmin — use SuperAdmin mobile to revoke server-side.
  Future<bool> revokeDeviceOnServer() async {
    if (!kServerRevokeAvailableToDesktop) {
      if (kDebugMode) {
        debugPrint(
          'ActivationService: revokeDeviceOnServer skipped — '
          'endpoint requires SuperAdmin (use SuperAdmin app)',
        );
      }
      return false;
    }

    final deviceId = await DatabaseService.instance.getAppMeta(_kDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'ActivationService: revokeDeviceOnServer skipped — no activation_device_id',
        );
      }
      return false;
    }

    try {
      await ApiClient.instance.patch<void>(deviceRevokeEndpoint(deviceId));
      if (kDebugMode) {
        debugPrint('ActivationService: device revoked on server ($deviceId)');
      }
      return true;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ActivationService: revokeDeviceOnServer failed '
          '(${e.response?.statusCode}): ${e.message}',
        );
      }
      return false;
    }
  }

  /// Revokes local tokens and routes UI to [DeviceRevokedScreen].
  ///
  /// Callers must stop [BackgroundSyncService] / [SyncStatusService] first.
  /// Does NOT delete business SQLite data.
  Future<void> handleRevokedByServer({String? reason}) async {
    if (_handlingRevoke || !_activated) return;
    _handlingRevoke = true;
    final message = reason ?? kDefaultServerRevokeMessage;
    try {
      await revokeActivation();
      ActivationStateController.instance.notifyServerRevoked(message);
    } finally {
      _handlingRevoke = false;
    }
    if (kDebugMode) {
      debugPrint('ActivationService: handleRevokedByServer — $message');
    }
  }

  /// Whether a [DioException] should clear activation (revoke), not license block.
  static bool shouldTreatAsDeviceRevocation(DioException error) {
    final action = ApiEnforcementParser.actionFromDio(error);
    if (action == ApiEnforcementAction.blockLicense) return false;
    if (action == ApiEnforcementAction.refreshToken) return false;
    if (action == ApiEnforcementAction.revokeDevice) {
      final path = error.requestOptions.path;
      if (path.contains(kEndpointValidateKey)) return false;
      if (path.contains(kEndpointActivateDesktop)) return false;
      return true;
    }
    if (error.response?.statusCode != 401) return false;
    final path = error.requestOptions.path;
    if (path.contains(kEndpointValidateKey)) return false;
    if (path.contains(kEndpointActivateDesktop)) return false;
    return true;
  }

  /// User-facing Albanian message for [handleRevokedByServer].
  static String messageForRevocation(DioException error) {
    final server = ApiEnforcementParser.messageFromData(error.response?.data);
    if (server != null && server.isNotEmpty) return server;
    return kDefaultServerRevokeMessage;
  }

  /// Reason string from the last `POST /api/license/check` (`null` when the
  /// license answered valid). Read by [LicenseHeartbeatService] to pace polls.
  String? _lastCheckReason;
  String? get lastCheckReason => _lastCheckReason;

  /// When the license row is alive but this device is no longer registered
  /// (`not_activated`), re-bind the stored key silently instead of dropping
  /// the operator on the activation screen. Flip to `false` to disable.
  static const bool kSelfHealReactivation = true;

  /// POST /api/license/check. Network errors keep the last good result for
  /// [kOfflineGrace]; explicit revoked/expired answers block immediately.
  ///
  /// A revoked, expired or suspended license **blocks the gate** — it no
  /// longer wipes the activation — so the stored key survives until the
  /// operator enters a key on the blocked screen.
  /// Pass [force] to run even while the gate is blocked.
  Future<bool> verifyActivation({bool force = false}) async {
    if (!_activated) return false;
    if (!force && LicenseGateService.instance.isBlocked) return false;

    final key = await storedLicenseKey();
    if (key == null || !isSellixLicenseKey(key)) {
      await handleRevokedByServer(
        reason: sellixLicenseReasonMessage('not_found'),
      );
      return false;
    }

    final deviceId =
        _serverDeviceId ?? await DatabaseService.instance.syncDeviceId();

    final SellixLicenseResponse result;
    try {
      result = await SellixLicenseClient.instance.check(
        licenseKey: key,
        deviceId: deviceId,
      );
    } on SellixLicenseException catch (e) {
      _lastCheckReason = e.reason;
      return _applyFailedCheck(e, key: key, deviceId: deviceId);
    } catch (_) {
      _lastCheckReason = 'network';
      return _allowOfflineGrace();
    }

    _lastCheckReason = null;
    return _applyValidCheck(result);
  }

  /// Stores a valid `/license/check` answer and lifts any active block.
  Future<bool> _applyValidCheck(SellixLicenseResponse result) async {
    if (!isRestaurantSector(result.business.sector)) {
      await LicenseGateService.instance.block(
        code: LicenseBlockCode.businessSuspended,
        message: sellixLicenseReasonMessage('not_restaurant'),
      );
      return false;
    }
    // Writes the fresh expiry through ActivationLicenseController, so an
    // extension granted in the portal lands on the badge on this very tick.
    await _cacheSuccessfulCheck(result);
    await LicenseGateService.instance.unblock();
    return !LicenseGateService.instance.isBlocked;
  }

  Future<bool> _applyFailedCheck(
    SellixLicenseException e, {
    required String key,
    required String deviceId,
  }) async {
    switch (e.reason) {
      // Transient: keep serving from the offline grace window.
      case 'network':
      case 'seat_limit':
      case 'rate_limited':
        return _allowOfflineGrace();

      case 'expired':
        await LicenseGateService.instance.block(
          code: LicenseBlockCode.licenseExpired,
          message: sellixLicenseReasonMessage('expired'),
        );
        return false;

      case 'suspended':
        await LicenseGateService.instance.block(
          code: LicenseBlockCode.licenseSuspended,
          message: sellixLicenseReasonMessage('suspended'),
        );
        return false;

      case 'revoked':
      case 'not_found':
        await LicenseGateService.instance.block(
          code: LicenseBlockCode.licenseRevoked,
          message: sellixLicenseReasonMessage(e.reason),
        );
        return false;

      case 'not_activated':
        if (kSelfHealReactivation &&
            await _trySilentReactivation(key: key, deviceId: deviceId)) {
          return !LicenseGateService.instance.isBlocked;
        }
        await LicenseGateService.instance.block(
          code: LicenseBlockCode.deviceSuspended,
          message: sellixLicenseReasonMessage('not_activated'),
        );
        return false;

      default:
        await LicenseGateService.instance.block(
          code: LicenseBlockCode.licenseSuspended,
          message: sellixLicenseReasonMessage(e.reason),
        );
        return false;
    }
  }

  /// Re-binds the stored key to this device after the server dropped it.
  /// Returns `true` when the device is serving again.
  Future<bool> _trySilentReactivation({
    required String key,
    required String deviceId,
  }) async {
    try {
      final result = await SellixLicenseClient.instance.activate(
        licenseKey: key,
        deviceId: deviceId,
        deviceName: _detectHostname(),
      );
      if (!isRestaurantSector(result.business.sector)) return false;
      await _cacheSuccessfulCheck(result);
      await LicenseGateService.instance.unblock();
      _lastCheckReason = null;
      if (kDebugMode) {
        debugPrint('ActivationService: device re-bound to the stored key');
      }
      return true;
    } on SellixLicenseException catch (e) {
      _lastCheckReason = e.reason;
      if (kDebugMode) {
        debugPrint('ActivationService: silent re-activation failed (${e.reason})');
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> storedLicenseKey() async {
    final key = await DatabaseService.instance.getAppMeta(kMetaLicenseKey);
    if (key == null || key.trim().isEmpty) return null;
    return key.trim();
  }

  Future<SellixBusinessProfile?> storedBusinessProfile() async {
    final raw = await DatabaseService.instance.getAppMeta(kMetaBusinessJson);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return SellixBusinessProfile.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  Future<ActivationValidateResponse> replaceLocalLicenseKey(String key) async {
    final validated = await validateActivationKey(activationKey: key);
    await activateDesktop(
      activationKey: key,
      branchCode: validated.branchCode ?? 'MAIN',
      businessName: validated.businessName,
      business: validated.business,
      license: validated.license,
    );
    return validated;
  }

  /// Replaces the stored SelliX key (e.g. after an admin issued a new one).
  Future<bool> extendActiveLocalLicenseForBusiness({
    required String businessId,
    required String replacementKey,
  }) async {
    await replaceLocalLicenseKey(replacementKey);
    return true;
  }

  /// Refreshes license expiry from API (verify) for UI badge without reinstall.
  Future<void> syncLicenseExpiryFromApiIfActivated() async {
    if (!_activated) return;
    await verifyActivation(force: true);
  }

  /// Parses `licenseExpiresAt` from activation API JSON (string or ISO-like).
  @visibleForTesting
  static String? parseLicenseExpiresAtValue(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      return parseSellixDateTime(trimmed) ??
          (DateTime.tryParse(trimmed) != null ? trimmed : null);
    }
    if (raw is DateTime) return raw.toUtc().toIso8601String();
    if (raw is num) {
      final dt = DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true);
      return dt.toIso8601String();
    }
    final asString = raw.toString().trim();
    if (asString.isEmpty) return null;
    if (DateTime.tryParse(asString) != null) return asString;
    return null;
  }

  /// Test hook for license expiry sync from API-shaped response bodies.
  @visibleForTesting
  Future<void> applyLicenseExpiresFromApiBody(Map<String, dynamic> data) =>
      _syncLicenseExpiresFromActivationBody(data, source: 'test');

  Future<Response<Map<String, dynamic>>> _postVerifyActivation() async {
    final accessToken = await SecureActivationTokenStore.instance
        .readAccessToken();
    if (!_nonEmpty(accessToken)) {
      throw StateError('No access token stored for activation verify.');
    }
    return ApiClient.instance.post<Map<String, dynamic>>(
      kEndpointVerifyActivation,
      data: {'accessToken': accessToken},
    );
  }

  Future<bool> _processVerifyResponse(
    Response<Map<String, dynamic>> response,
  ) async {
    final data = response.data;
    if (data == null) {
      return !LicenseGateService.instance.isBlocked;
    }
    if (data['valid'] == false) {
      final handled = await _handleActivationEnforcementBody(data);
      if (handled) return false;
      return false;
    }
    final handled = await _handleActivationEnforcementBody(data);
    if (handled) return false;
    await _syncLicenseExpiresFromActivationBody(data, source: 'verify');
    return !LicenseGateService.instance.isBlocked;
  }

  Future<bool> _handleVerifyDioError(DioException e) async {
    if (await LicenseGateService.instance.handleDioException(e)) {
      if (kDebugMode) {
        debugPrint('ActivationService: license blocked on verify');
      }
      return false;
    }

    if (ApiEnforcementParser.requiresDeviceRevoke(e)) {
      await handleRevokedByServer(reason: messageForRevocation(e));
      return false;
    }

    if (ApiEnforcementParser.requiresTokenRefresh(e)) {
      try {
        await refreshActivationToken();
        if (!_activated || LicenseGateService.instance.isBlocked) {
          return false;
        }
        final response = await _postVerifyActivation();
        return await _processVerifyResponse(response);
      } on DioException catch (retry) {
        return _handleVerifyDioError(retry);
      }
    }

    if (shouldTreatAsDeviceRevocation(e)) {
      await handleRevokedByServer(reason: messageForRevocation(e));
    }
    return false;
  }

  Future<bool> _handleActivationEnforcementBody(
    Map<String, dynamic> data,
  ) async {
    final action = ApiEnforcementParser.actionFromActivationBody(data);
    final message = ApiEnforcementParser.messageFromData(data);
    final code = ApiEnforcementParser.codeFromData(data);

    switch (action) {
      case ApiEnforcementAction.blockLicense:
        await LicenseGateService.instance.blockFromApiCode(
          code ?? ApiEnforcementCodes.licenseSuspended,
          message: message,
        );
        return true;
      case ApiEnforcementAction.revokeDevice:
        await handleRevokedByServer(
          reason: message ?? kDefaultServerRevokeMessage,
        );
        return true;
      case ApiEnforcementAction.refreshToken:
      case ApiEnforcementAction.none:
        return false;
    }
  }

  /// Calls POST /activation/refresh with the stored refresh token.
  ///
  /// On success: persists the new access + refresh tokens and updates
  /// [ApiClient] so the next request uses the fresh Bearer.
  ///
  /// Throws [DioException] on network error or server rejection (4xx/5xx) —
  /// the caller is responsible for deciding whether to revoke activation.
  Future<void> refreshActivationToken() async {
    final localLicenseKey = await DatabaseService.instance.getAppMeta(
      'activation_license_key',
    );
    if (_nonEmpty(localLicenseKey)) return;

    final storedRefreshToken = await SecureActivationTokenStore.instance
        .readRefreshToken();
    if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
      throw Exception('No refresh token stored — re-activation required.');
    }

    final Response<Map<String, dynamic>> response;
    try {
      response = await ApiClient.instance.post<Map<String, dynamic>>(
        kEndpointRefreshToken,
        data: {'refreshToken': storedRefreshToken},
      );
    } on DioException catch (e) {
      if (await LicenseGateService.instance.handleDioException(e)) {
        rethrow;
      }
      if (ApiEnforcementParser.requiresDeviceRevoke(e)) {
        await handleRevokedByServer(reason: messageForRevocation(e));
        rethrow;
      }
      rethrow;
    }

    final data = response.data;
    if (data == null) throw Exception('Empty refresh response from server.');

    final newAccessToken = data['accessToken'] as String?;
    final newRefreshToken = data['refreshToken'] as String?;
    if (newAccessToken == null || newRefreshToken == null) {
      throw Exception('Malformed refresh response — missing tokens.');
    }

    await SecureActivationTokenStore.instance.saveTokens(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    );
    await _syncLicenseExpiresFromActivationBody(data);

    ApiClient.instance.setAccessToken(newAccessToken);
    await LicenseGateService.instance.unblock();
    if (kDebugMode) debugPrint('ActivationService: access token refreshed');
  }

  /// Clears all activation state — tokens, IDs, sync metadata.
  ///
  /// Safe to call multiple times and from any context.
  /// Does NOT delete outbox events or local business data.
  /// Callers that manage sync services (e.g. [BackgroundSyncService] and the
  /// deactivation UI) are responsible for stopping them separately — this
  /// method avoids importing sync services to prevent circular dependencies.
  Future<void> revokeActivation() async {
    _activated = false;
    _businessId = null;
    _branchId = null;
    _serverDeviceId = null;
    _offerAdminPinOnNextLogin = false;

    final db = DatabaseService.instance;

    await SecureActivationTokenStore.instance.clearTokens();
    await DatabaseService.instance.setAppMeta(kMetaLicenseKey, '');
    await db.setAppMeta(kMetaBusinessJson, '');
    await db.setAppMeta(kMetaLastCheckAt, '');
    await _clearLegacyTokenMeta(db);

    await db.setAppMeta(_kCompleted, '');
    await db.setAppMeta(_kBusinessId, '');
    await db.setAppMeta(_kBranchId, '');
    await db.setAppMeta(_kDeviceId, '');
    await db.setAppMeta(_kLicenseExpiresAt, '');
    await db.setAppMeta(kMetaOfferAdminPin, '');

    await LicenseGateService.instance.clearForRevocation();
    ActivationLicenseController.instance.clearInMemory();

    await db.setAppMeta('sync_last_error', '');
    await db.setAppMeta('sync_last_push_at', '');
    await db.setAppMeta('sync_last_pull_at', '');
    await db.setAppMeta('sync_last_success_at', '');
    await db.setAppMeta('sync_pull_cursor', '');

    ApiClient.instance.clearAccessToken();
    DatabaseSchema.clearActivatedTenant();
    ActivationStateController.instance.setActivated(false);
    if (kDebugMode) {
      debugPrint(
        'ActivationService: local activation reset — tokens and sync metadata cleared',
      );
    }
  }

  // ── private ───────────────────────────────────────────────────────────────

  Future<void> _persistActivation(
    ActivationResponse r, {
    String? businessName,
    String? licenseKey,
    SellixBusinessProfile? business,
    SellixLicenseInfo? license,
    bool liftUi = true,
  }) async {
    final db = DatabaseService.instance;
    final previousId = await db.getAppMeta(_kBusinessId);
    final lastId = await db.getAppMeta(
      LocalTenantDataService.kLastBusinessIdKey,
    );

    _businessId = r.businessId;
    _branchId = r.branchId;
    _serverDeviceId = r.deviceId;
    _activated = true;

    final businessChanged =
        (previousId != null &&
            previousId.isNotEmpty &&
            previousId != r.businessId) ||
        (lastId != null && lastId.isNotEmpty && lastId != r.businessId);

    if (businessChanged) {
      await db.setAppMeta('sync_pull_cursor', '');
      await db.setAppMeta('sync_last_error', '');
      await db.setAppMeta('sync_last_push_at', '');
      await db.setAppMeta('sync_last_pull_at', '');
      await db.setAppMeta('sync_last_success_at', '');
    }

    await db.setAppMeta(_kBusinessId, r.businessId);
    await DatabaseService.instance.setAppMeta(_kBranchId, r.branchId);
    await DatabaseService.instance.setAppMeta(_kDeviceId, r.deviceId);
    final key = (licenseKey ?? r.accessToken).trim();
    await db.setAppMeta(kMetaLicenseKey, key);
    final refresh = (r.refreshToken ?? key).trim();
    await SecureActivationTokenStore.instance.saveTokens(
      accessToken: key,
      refreshToken: refresh.isEmpty ? key : refresh,
    );
    await _clearLegacyTokenMeta(db);
    final expires =
        r.licenseExpiresAt ?? parseSellixDateTime(license?.expiresAt);
    if (expires != null) {
      await ActivationLicenseController.instance.setExpiresAt(expires);
    }
    await DatabaseService.instance.setAppMeta(_kCompleted, 'true');

    ApiClient.instance.setAccessToken(key);
    DatabaseSchema.setActivatedTenant(
      businessId: r.businessId,
      branchId: r.branchId,
    );
    if (liftUi) {
      ActivationStateController.instance.setActivated(true);
    }

    await LocalTenantDataService.instance.recordActivatedTenant(
      businessId: r.businessId,
      businessName: businessName,
    );
    if (businessName != null && businessName.isNotEmpty) {
      await db.setAppMeta('activation_business_name', businessName);
    }
    if (business != null) {
      await db.setAppMeta(kMetaBusinessJson, jsonEncode(business.toJson()));
      await _applyBusinessToCompany(business);
    }
    await db.setAppMeta(
      kMetaLastCheckAt,
      DateTime.now().toUtc().toIso8601String(),
    );
    _offerAdminPinOnNextLogin = true;
    await db.setAppMeta(kMetaOfferAdminPin, '1');
    if (liftUi) {
      await LicenseGateService.instance.unblock();
    }
  }

  static String _businessIdFor(SellixBusinessProfile business, String key) {
    if (business.nui.trim().isNotEmpty) return 'slx-${business.nui.trim()}';
    return 'slx-${key.hashCode.abs()}';
  }

  Future<void> _applyBusinessToCompany(SellixBusinessProfile business) async {
    try {
      if (business.name.trim().isNotEmpty) {
        await DatabaseService.instance.updateCompanyName(business.name.trim());
      }
      await DatabaseService.instance.updateEscPosSettings(
        businessAddress: business.formattedAddress.isEmpty
            ? null
            : business.formattedAddress,
        businessPhone: business.phone.isEmpty ? null : business.phone,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ActivationService: apply company profile failed: $e');
      }
    }
  }

  Future<void> _cacheSuccessfulCheck(SellixLicenseResponse result) async {
    final db = DatabaseService.instance;
    await db.setAppMeta(kMetaBusinessJson, jsonEncode(result.business.toJson()));
    await db.setAppMeta(
      kMetaLastCheckAt,
      DateTime.now().toUtc().toIso8601String(),
    );
    final expires = parseSellixDateTime(result.license.expiresAt);
    if (expires != null) {
      await ActivationLicenseController.instance.setExpiresAt(expires);
    }
    if (result.business.name.isNotEmpty) {
      await db.setAppMeta('activation_business_name', result.business.name);
      await _applyBusinessToCompany(result.business);
    }
  }

  Future<bool> _allowOfflineGrace() async {
    await LicenseGateService.instance.checkAndBlockIfLocallyExpired();
    if (LicenseGateService.instance.isBlocked) return false;
    final raw = await DatabaseService.instance.getAppMeta(kMetaLastCheckAt);
    final last = raw == null ? null : DateTime.tryParse(raw);
    if (last == null) return true;
    final age = DateTime.now().toUtc().difference(last.toUtc());
    if (age > kOfflineGrace) {
      await LicenseGateService.instance.block(
        code: LicenseBlockCode.licenseSuspended,
        message:
            'Nuk ka lidhje me serverin prej disa ditësh. '
            'Lidhuni me internet për të verifikuar licencën.',
      );
      return false;
    }
    return true;
  }

  Future<String?> activatedBusinessName() =>
      DatabaseService.instance.getAppMeta('activation_business_name');

  /// Ditë të mbetura deri në skadimin e licencës (`null` = pa datë të ruajtur).
  Future<int?> licenseDaysRemaining() async {
    if (ActivationLicenseController.instance.expiresAtIso == null) {
      await ActivationLicenseController.instance.reloadFromStorage();
    }
    return ActivationLicenseController.instance.daysRemaining;
  }

  Future<void> _syncLicenseExpiresFromActivationBody(
    Map<String, dynamic> data, {
    String source = 'activation_api',
  }) async {
    final oldIso = ActivationLicenseController.instance.expiresAtIso;
    final parsed = parseLicenseExpiresAtValue(data['licenseExpiresAt']);
    if (parsed == null) {
      if (kDebugMode) {
        debugPrint(
          '[LicenseExpiry] source=$source missing licenseExpiresAt '
          '(raw=${data['licenseExpiresAt']}) — keeping cache old=$oldIso',
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('[LicenseExpiry] source=$source old=$oldIso new=$parsed');
    }
    await ActivationLicenseController.instance.setExpiresAt(parsed);
    if (kDebugMode) {
      final saved = await DatabaseService.instance.getAppMeta(
        LicenseGateService.kLicenseExpiresAtMeta,
      );
      debugPrint(
        '[LicenseExpiry] saved app_meta=$saved '
        'days=${ActivationLicenseController.instance.daysRemaining}',
      );
    }
  }

  static String _detectPlatform() {
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'desktop';
    }
  }

  static String _detectHostname() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'pos-terminal';
    }
  }

  void _assertProductionApiConfig() {
    if (RuntimeConfigService.instance.isBlockedInRelease) {
      throw StateError(RuntimeConfigService.productionConfigErrorTitle);
    }
  }

  static Future<void> _clearLegacyTokenMeta(DatabaseService db) async {
    await db.setAppMeta(SecureActivationTokenStore.legacyAccessTokenKey, '');
    await db.setAppMeta(SecureActivationTokenStore.legacyRefreshTokenKey, '');
  }
}
