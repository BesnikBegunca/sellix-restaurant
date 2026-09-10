import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/activation_response.dart';
import '../models/activation_validate_response.dart';
import '../models/device_transfer_required_response.dart';
import '../models/device_transfer_response.dart';
import 'activation_api_log.dart';
import 'api_client.dart';
import 'device_transfer_exception.dart';
import 'database_schema.dart';
import 'database_service.dart';
import 'activation_state_controller.dart';
import 'activation_license_controller.dart';
import 'api_enforcement_parser.dart';
import 'license_gate_service.dart';
import 'local_tenant_data_service.dart';
import 'runtime_config_service.dart';
import 'local_license_service.dart';
import 'secure_activation_token_store.dart';

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
  static const String kDefaultServerRevokeMessage =
      'Kjo pajisje është çaktivizuar nga administratori. '
      'Aktivizojeni përsëri me një çelës të ri.';

  /// pos_api `PATCH /devices/:id/revoke` is SuperAdmin-only today.
  /// When the API allows device self-revoke, set this to `true`.
  static const bool kServerRevokeAvailableToDesktop = false;

  // ── app_meta keys ─────────────────────────────────────────────────────────
  static const String kMetaBusinessId = 'activation_business_id';
  static const String kMetaBranchId = 'activation_branch_id';
  static const String kMetaDeviceId = 'activation_device_id';

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

  bool get isActivated => _activated;
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
    final accessToken = await store.readAccessToken();
    final refreshToken = await store.readRefreshToken();

    final completedOk = completed == 'true';
    final businessOk = _nonEmpty(businessId);
    final branchOk = _nonEmpty(branchId);
    final deviceOk = _nonEmpty(deviceId);
    final accessOk = _nonEmpty(accessToken);
    final refreshOk = _nonEmpty(refreshToken);

    if (kDebugMode) {
      debugPrint('[Activation] loadPersistedActivation:');
      debugPrint('[Activation]   activation_completed=$completedOk');
      debugPrint('[Activation]   businessId=${businessOk ? "yes" : "no"}');
      debugPrint('[Activation]   branchId=${branchOk ? "yes" : "no"}');
      debugPrint('[Activation]   deviceId=${deviceOk ? "yes" : "no"}');
      debugPrint('[Activation]   secureAccessToken=${accessOk ? "yes" : "no"}');
      debugPrint(
        '[Activation]   secureRefreshToken=${refreshOk ? "yes" : "no"}',
      );
    }

    if (!completedOk) {
      _activated = false;
      if (kDebugMode) debugPrint('[Activation]   final activated=false');
      return false;
    }

    final metadataOk = businessOk && branchOk && deviceOk;
    final tokensOk = accessOk && refreshOk;

    if (!metadataOk || !tokensOk) {
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

    _businessId = businessId;
    _branchId = branchId;
    _serverDeviceId = deviceId;
    _activated = true;

    ApiClient.instance.setAccessToken(accessToken!);
    DatabaseSchema.setActivatedTenant(
      businessId: businessId!,
      branchId: branchId!,
    );
    ActivationStateController.instance.setActivated(true);

    if (kDebugMode) debugPrint('[Activation]   final activated=true');
    await ActivationLicenseController.instance.reloadFromStorage();
    return true;
  }

  /// Public for unit tests and diagnostics.
  static bool nonEmptyMeta(String? value) => _nonEmpty(value);

  static bool _nonEmpty(String? value) =>
      value != null && value.trim().isNotEmpty;

  /// POST /activation/validate-key — checks key before desktop activation.
  Future<ActivationValidateResponse> validateActivationKey({
    required String activationKey,
  }) async {
    final local = LocalLicenseService.instance.validate(activationKey);
    if (local == null) {
      throw StateError('Çelësi lokal është i pavlefshëm ose ka skaduar.');
    }
    return ActivationValidateResponse(
      valid: true,
      businessId: 'local-${local.licenseId}',
      businessName: local.ownerName,
      branchCode: null,
      licenseStatus: 'active',
      licenseExpiresAt: local.expiresAt.toIso8601String(),
    );
    /*
    _assertProductionApiConfig();
    final trimmed = activationKey.trim();
    final body = <String, dynamic>{'activationKey': trimmed};
    logActivationRequest(
      endpoint: kEndpointValidateKey,
      bodyKeys: body.keys.toSet(),
    );

    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        kEndpointValidateKey,
        data: body,
      );
      logActivationResponse(response);
      final data = response.data;
      if (data == null) {
        throw Exception('Empty validate-key response from server.');
      }
      final result = ActivationValidateResponse.fromJson(data);
      if (!result.valid) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: result.message ?? 'Çelësi i aktivizimit nuk është i vlefshëm.',
        );
      }
      return result;
    } on DioException catch (e) {
      logActivationError(e);
      rethrow;
    }
    */
  }

  /// Sends POST /activation/desktop and persists the server response locally.
  ///
  /// Uses the stable device UUID from [app_meta] (same key as [AuditContextService]).
  ///
  /// Throws [DeviceTransferRequiredException] when the license is already bound
  /// to another device — a transfer request is submitted automatically before
  /// throwing, so the UI only needs to show the pending-approval message.
  Future<ActivationResponse> activateDesktop({
    required String activationKey,
    required String branchCode,
    String? businessName,
  }) async {
    final local = LocalLicenseService.instance.validate(activationKey);
    if (local == null) {
      throw StateError('Çelësi lokal është i pavlefshëm ose ka skaduar.');
    }
    final businessId = 'local-${local.licenseId}';
    final response = ActivationResponse(
      businessId: businessId,
      branchId: 'local-${branchCode.trim().toLowerCase()}',
      deviceId: await DatabaseService.instance.syncDeviceId(),
      accessToken: 'local-access-${local.licenseId}',
      refreshToken: 'local-refresh-${local.licenseId}',
      licenseExpiresAt: local.expiresAt.toIso8601String(),
    );
    await _persistActivation(
      response,
      businessName: businessName ?? local.ownerName,
    );
    await DatabaseService.instance.setAppMeta(
      'activation_license_key',
      activationKey.trim(),
    );
    return response;
    /*
    _assertProductionApiConfig();
    final deviceUuid = await DatabaseService.instance.syncDeviceId();
    final deviceName = _detectHostname();
    final body = <String, dynamic>{
      'activationKey': activationKey.trim(),
      'branchCode': branchCode.trim(),
      'deviceUuid': deviceUuid,
      'deviceName': deviceName,
      'platform': _detectPlatform(),
    };
    logActivationRequest(
      endpoint: kEndpointActivateDesktop,
      bodyKeys: body.keys.toSet(),
    );

    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        kEndpointActivateDesktop,
        data: body,
      );
      logActivationResponse(response);
      final data = response.data;
      if (data == null) {
        throw Exception('Empty activation response from server.');
      }

      if (data['requiresTransferApproval'] == true) {
        final required = DeviceTransferRequiredResponse.fromJson(data);
        final transfer = await requestDeviceTransfer(
          licenseId: required.licenseId,
          oldDeviceId: required.oldDeviceId,
          oldDeviceName: required.oldDeviceName,
          newDeviceFingerprint: deviceUuid,
          newDeviceName: deviceName,
        );
        throw DeviceTransferRequiredException(transfer);
      }

      final activation = ActivationResponse.fromJson(data);
      await _persistActivation(activation, businessName: businessName);
      return activation;
    } on DeviceTransferRequiredException {
      rethrow;
    } on DioException catch (e) {
      final errorData = e.response?.data;
      if (errorData is Map<String, dynamic> &&
          errorData['requiresTransferApproval'] == true) {
        final required = DeviceTransferRequiredResponse.fromJson(errorData);
        final transfer = await requestDeviceTransfer(
          licenseId: required.licenseId,
          oldDeviceId: required.oldDeviceId,
          oldDeviceName: required.oldDeviceName,
          newDeviceFingerprint: deviceUuid,
          newDeviceName: deviceName,
        );
        throw DeviceTransferRequiredException(transfer);
      }
      logActivationError(e);
      rethrow;
    }
    */
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

  /// Clears local activation only (does not call SuperAdmin revoke API).
  ///
  /// Does NOT delete local sales or SQLite business data.
  Future<void> resetLocalActivation() async {
    ActivationStateController.instance.clearServerRevoked();
    await revokeActivation();
    ActivationStateController.instance.setActivated(false);
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

  /// POST /activation/verify with stored access token (pos_api contract).
  ///
  /// Returns `true` when activation is valid and license is not blocked.
  /// Returns `false` on network error (offline) unless locally expired (strict).
  Future<bool> verifyActivation() async {
    if (!_activated) return false;
    if (LicenseGateService.instance.isBlocked) return false;

    final key = await DatabaseService.instance.getAppMeta(
      'activation_license_key',
    );
    final local = key == null
        ? null
        : LocalLicenseService.instance.validate(key);
    if (local == null) {
      await LicenseGateService.instance.checkAndBlockIfLocallyExpired();
      return !LicenseGateService.instance.isBlocked;
    }

    await ActivationLicenseController.instance.setExpiresAt(
      local.expiresAt.toIso8601String(),
    );
    return true;

    /*
    try {
      final response = await _postVerifyActivation();
      return await _processVerifyResponse(response);
    } on DioException catch (e) {
      return _handleVerifyDioError(e);
    } catch (_) {
      return false;
    }
    */
  }

  Future<LocalLicenseData> replaceLocalLicenseKey(String key) async {
    final license = LocalLicenseService.instance.validate(key);
    if (license == null) {
      throw StateError(
        'Çelësi i licencës është i pavlefshëm ose ka skaduar.',
      );
    }
    await DatabaseService.instance.setAppMeta(
      'activation_license_key',
      key.trim(),
    );
    await ActivationLicenseController.instance.setExpiresAt(
      license.expiresAt.toIso8601String(),
    );
    return license;
  }

  /// Refreshes license expiry from API (verify) for UI badge without reinstall.
  Future<void> syncLicenseExpiryFromApiIfActivated() async {
    if (!_activated) return;
    await verifyActivation();
  }

  /// Parses `licenseExpiresAt` from activation API JSON (string or ISO-like).
  @visibleForTesting
  static String? parseLicenseExpiresAtValue(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      if (DateTime.tryParse(trimmed) != null) return trimmed;
      return null;
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

    final db = DatabaseService.instance;

    await SecureActivationTokenStore.instance.clearTokens();
    await DatabaseService.instance.setAppMeta('activation_license_key', '');
    await _clearLegacyTokenMeta(db);

    await db.setAppMeta(_kCompleted, '');
    await db.setAppMeta(_kBusinessId, '');
    await db.setAppMeta(_kBranchId, '');
    await db.setAppMeta(_kDeviceId, '');
    await db.setAppMeta(_kLicenseExpiresAt, '');

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
    final refresh = r.refreshToken?.trim() ?? '';
    if (refresh.isEmpty) {
      throw StateError(
        'Serveri nuk ktheu refresh token — aktivizimi nuk mund të ruhet.',
      );
    }
    await SecureActivationTokenStore.instance.saveTokens(
      accessToken: r.accessToken,
      refreshToken: refresh,
    );
    await _clearLegacyTokenMeta(db);
    if (r.licenseExpiresAt != null) {
      await ActivationLicenseController.instance.setExpiresAt(
        r.licenseExpiresAt,
      );
    }
    await DatabaseService.instance.setAppMeta(_kCompleted, 'true');

    ApiClient.instance.setAccessToken(r.accessToken);
    DatabaseSchema.setActivatedTenant(
      businessId: r.businessId,
      branchId: r.branchId,
    );
    ActivationStateController.instance.setActivated(true);

    await LocalTenantDataService.instance.recordActivatedTenant(
      businessId: r.businessId,
      businessName: businessName,
    );
    if (businessName != null && businessName.isNotEmpty) {
      await db.setAppMeta('activation_business_name', businessName);
    }
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
