import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// OS-backed storage for activation Bearer / refresh tokens (not SQLite).
///
/// Windows: DPAPI via [WindowsOptions].
/// macOS: Keychain via [MacOsOptions].
/// Linux: libsecret via [LinuxOptions] when available.
///
/// Debug-only in-memory fallback when secure storage is unavailable — never
/// used in release builds and never writes tokens to [app_meta].
class SecureActivationTokenStore {
  SecureActivationTokenStore._();
  static final SecureActivationTokenStore instance =
      SecureActivationTokenStore._();

  static const String legacyAccessTokenKey = 'activation_access_token';
  static const String legacyRefreshTokenKey = 'activation_refresh_token';

  static const String _kAccess = 'pos_activation_access_token';
  static const String _kRefresh = 'pos_activation_refresh_token';

  static const String storageLabel = 'Secure (OS keychain / DPAPI)';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(),
    wOptions: WindowsOptions(),
    lOptions: LinuxOptions(),
  );

  String? _debugAccess;
  String? _debugRefresh;
  bool _debugFallback = false;

  bool get usesDebugFallback => _debugFallback && kDebugMode;

  /// Human-readable storage mode for Sync Diagnostics (no secrets).
  String get diagnosticsStorageLabel =>
      usesDebugFallback ? 'Debug memory (secure storage unavailable)' : storageLabel;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (accessToken.isEmpty) {
      throw ArgumentError.value(accessToken, 'accessToken', 'must not be empty');
    }
    try {
      await _storage.write(key: _kAccess, value: accessToken);
      await _storage.write(key: _kRefresh, value: refreshToken);
      _debugFallback = false;
      _debugAccess = null;
      _debugRefresh = null;
    } catch (e) {
      if (kReleaseMode) rethrow;
      _debugFallback = true;
      _debugAccess = accessToken;
      _debugRefresh = refreshToken;
      if (kDebugMode) {
        debugPrint(
          'SecureActivationTokenStore: debug memory fallback '
          '(${Platform.operatingSystem}) — $e',
        );
      }
    }
  }

  Future<String?> readAccessToken() async {
    if (_debugFallback && kDebugMode) return _debugAccess;
    try {
      return await _storage.read(key: _kAccess);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureActivationTokenStore: read access failed — $e');
      }
      return _debugAccess;
    }
  }

  Future<String?> readRefreshToken() async {
    if (_debugFallback && kDebugMode) return _debugRefresh;
    try {
      return await _storage.read(key: _kRefresh);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureActivationTokenStore: read refresh failed — $e');
      }
      return _debugRefresh;
    }
  }

  Future<void> clearTokens() async {
    _debugAccess = null;
    _debugRefresh = null;
    _debugFallback = false;
    try {
      await _storage.delete(key: _kAccess);
      await _storage.delete(key: _kRefresh);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureActivationTokenStore: clear failed — $e');
      }
    }
  }

  Future<bool> hasTokens() async {
    final access = await readAccessToken();
    return access != null && access.isNotEmpty;
  }
}
