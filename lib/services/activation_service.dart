import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/activation_response.dart';
import '../models/activation_validate_response.dart';
import 'activation_api_log.dart';
import 'api_client.dart';
import 'database_schema.dart';
import 'database_service.dart';
import 'license_gate_service.dart';

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

  // ── app_meta keys ─────────────────────────────────────────────────────────
  static const String _kBusinessId = 'activation_business_id';
  static const String _kBranchId = 'activation_branch_id';
  static const String _kDeviceId = 'activation_device_id';
  static const String _kAccessToken = 'activation_access_token';
  static const String _kRefreshToken = 'activation_refresh_token';
  static const String _kLicenseExpiresAt = 'activation_license_expires_at';
  static const String _kCompleted = 'activation_completed';

  // ── in-memory state ───────────────────────────────────────────────────────
  String? _businessId;
  String? _branchId;
  String? _serverDeviceId;
  bool _activated = false;

  bool get isActivated => _activated;
  String? get businessId => _businessId;
  String? get branchId => _branchId;
  String? get serverDeviceId => _serverDeviceId;

  // ── public API ────────────────────────────────────────────────────────────

  /// Loads activation state from [app_meta] and wires [ApiClient] + tenant IDs.
  ///
  /// Idempotent — safe to call multiple times; only restores if
  /// `activation_completed = 'true'` is found in [app_meta].
  Future<void> loadPersistedActivation() async {
    final completed = await DatabaseService.instance.getAppMeta(_kCompleted);
    if (completed != 'true') return;

    final businessId = await DatabaseService.instance.getAppMeta(_kBusinessId);
    final branchId = await DatabaseService.instance.getAppMeta(_kBranchId);
    final deviceId = await DatabaseService.instance.getAppMeta(_kDeviceId);
    final accessToken = await DatabaseService.instance.getAppMeta(
      _kAccessToken,
    );

    if (businessId == null || branchId == null || accessToken == null) return;

    _businessId = businessId;
    _branchId = branchId;
    _serverDeviceId = deviceId;
    _activated = true;

    ApiClient.instance.setAccessToken(accessToken);
    DatabaseSchema.setActivatedTenant(
      businessId: businessId,
      branchId: branchId,
    );
  }

  /// POST /activation/validate-key — checks key before desktop activation.
  Future<ActivationValidateResponse> validateActivationKey({
    required String activationKey,
  }) async {
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
  }

  /// Sends POST /activation/desktop and persists the server response locally.
  ///
  /// Uses the stable device UUID from [app_meta] (same key as [AuditContextService]).
  Future<ActivationResponse> activateDesktop({
    required String activationKey,
    required String branchCode,
  }) async {
    final deviceUuid = await DatabaseService.instance.syncDeviceId();
    final body = <String, dynamic>{
      'activationKey': activationKey.trim(),
      'branchCode': branchCode.trim(),
      'deviceUuid': deviceUuid,
      'deviceName': _detectHostname(),
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
      final activation = ActivationResponse.fromJson(data);
      await _persistActivation(activation);
      return activation;
    } on DioException catch (e) {
      logActivationError(e);
      rethrow;
    }
  }

  /// Clears all local activation state and returns to a fresh activation flow.
  ///
  /// Does NOT delete local sales or SQLite business data.
  Future<void> resetLocalActivation() => revokeActivation();

  /// Calls GET /activation/verify with the stored Bearer token.
  ///
  /// Returns `true` if the token is valid.
  /// Returns `false` on any network error — the app continues in offline mode.
  /// On **401 Unauthorized** the local activation is revoked and `false` is returned.
  Future<bool> verifyActivation() async {
    if (!_activated) return false;
    try {
      await ApiClient.instance.get(kEndpointVerifyActivation);
      return true;
    } on DioException catch (e) {
      if (LicenseGateService.isLicenseSuspendedError(e)) {
        LicenseGateService.instance.block();
        if (kDebugMode) {
          debugPrint('ActivationService: license suspended (403 on verify)');
        }
        return false;
      }
      if (e.response?.statusCode == 401) {
        await revokeActivation();
        if (kDebugMode) {
          debugPrint(
            'ActivationService: token revoked by server (401 on verify)',
          );
        }
      }
      return false;
    } catch (_) {
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
    final storedRefreshToken = await DatabaseService.instance.getAppMeta(
      _kRefreshToken,
    );
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
      if (LicenseGateService.isLicenseSuspendedError(e)) {
        LicenseGateService.instance.block();
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

    await DatabaseService.instance.setAppMeta(_kAccessToken, newAccessToken);
    await DatabaseService.instance.setAppMeta(_kRefreshToken, newRefreshToken);
    final expiresAt = data['licenseExpiresAt'] as String?;
    if (expiresAt != null) {
      await DatabaseService.instance.setAppMeta(_kLicenseExpiresAt, expiresAt);
    }

    ApiClient.instance.setAccessToken(newAccessToken);
    LicenseGateService.instance.unblock();
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

    await db.setAppMeta(_kCompleted, '');
    await db.setAppMeta(_kAccessToken, '');
    await db.setAppMeta(_kRefreshToken, '');
    await db.setAppMeta(_kBusinessId, '');
    await db.setAppMeta(_kBranchId, '');
    await db.setAppMeta(_kDeviceId, '');
    await db.setAppMeta(_kLicenseExpiresAt, '');

    await db.setAppMeta('sync_last_error', '');
    await db.setAppMeta('sync_last_push_at', '');
    await db.setAppMeta('sync_last_pull_at', '');
    await db.setAppMeta('sync_last_success_at', '');
    await db.setAppMeta('sync_pull_cursor', '');

    ApiClient.instance.clearAccessToken();
    DatabaseSchema.clearActivatedTenant();
    if (kDebugMode) {
      debugPrint(
        'ActivationService: local activation reset — tokens and sync metadata cleared',
      );
    }
  }

  // ── private ───────────────────────────────────────────────────────────────

  Future<void> _persistActivation(ActivationResponse r) async {
    _businessId = r.businessId;
    _branchId = r.branchId;
    _serverDeviceId = r.deviceId;
    _activated = true;

    await DatabaseService.instance.setAppMeta(_kBusinessId, r.businessId);
    await DatabaseService.instance.setAppMeta(_kBranchId, r.branchId);
    await DatabaseService.instance.setAppMeta(_kDeviceId, r.deviceId);
    await DatabaseService.instance.setAppMeta(_kAccessToken, r.accessToken);
    if (r.refreshToken != null) {
      await DatabaseService.instance.setAppMeta(
        _kRefreshToken,
        r.refreshToken!,
      );
    }
    if (r.licenseExpiresAt != null) {
      await DatabaseService.instance.setAppMeta(
        _kLicenseExpiresAt,
        r.licenseExpiresAt!,
      );
    }
    await DatabaseService.instance.setAppMeta(_kCompleted, 'true');

    ApiClient.instance.setAccessToken(r.accessToken);
    DatabaseSchema.setActivatedTenant(
      businessId: r.businessId,
      branchId: r.branchId,
    );
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
}
