import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

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
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.unlocked,
    ),
    wOptions: WindowsOptions(),
    lOptions: LinuxOptions(),
  );

  static const String _kDebugCacheFileName = '.pos_activation_tokens_debug.json';

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
      await _deleteDebugCacheFile();
    } catch (e) {
      if (kReleaseMode) rethrow;
      _debugFallback = true;
      _debugAccess = accessToken;
      _debugRefresh = refreshToken;
      await _writeDebugCacheFile(accessToken, refreshToken);
      if (kDebugMode) {
        debugPrint(
          'SecureActivationTokenStore: debug cache fallback '
          '(${Platform.operatingSystem}) — $e',
        );
      }
    }
  }

  Future<String?> readAccessToken() async {
    if (_debugFallback && kDebugMode && _nonEmpty(_debugAccess)) {
      return _debugAccess;
    }
    try {
      final fromStore = await _storage.read(key: _kAccess);
      if (_nonEmpty(fromStore)) return fromStore;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureActivationTokenStore: read access failed — $e');
      }
    }
    return _restoreFromDebugCache(access: true);
  }

  Future<String?> readRefreshToken() async {
    if (_debugFallback && kDebugMode && _nonEmpty(_debugRefresh)) {
      return _debugRefresh;
    }
    try {
      final fromStore = await _storage.read(key: _kRefresh);
      if (_nonEmpty(fromStore)) return fromStore;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureActivationTokenStore: read refresh failed — $e');
      }
    }
    return _restoreFromDebugCache(access: false);
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
    await _deleteDebugCacheFile();
  }

  Future<bool> hasTokens() async => hasValidTokenPair();

  /// Both access and refresh tokens must be present (refresh may be rotated later).
  Future<bool> hasValidTokenPair() async {
    final access = await readAccessToken();
    final refresh = await readRefreshToken();
    return _nonEmpty(access) && _nonEmpty(refresh);
  }

  static bool _nonEmpty(String? value) =>
      value != null && value.trim().isNotEmpty;

  Future<File?> _debugCacheFile() async {
    if (!kDebugMode) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_kDebugCacheFileName');
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDebugCacheFile(
    String accessToken,
    String refreshToken,
  ) async {
    if (!kDebugMode) return;
    final file = await _debugCacheFile();
    if (file == null) return;
    try {
      await file.writeAsString(
        jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        }),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureActivationTokenStore: debug cache write failed — $e');
      }
    }
  }

  Future<String?> _restoreFromDebugCache({required bool access}) async {
    if (!kDebugMode) return null;
    final file = await _debugCacheFile();
    if (file == null || !file.existsSync()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>?;
      final a = json?['accessToken'] as String?;
      final r = json?['refreshToken'] as String?;
      if (_nonEmpty(a) && _nonEmpty(r)) {
        _debugAccess = a;
        _debugRefresh = r;
        _debugFallback = true;
        if (kDebugMode) {
          debugPrint(
            'SecureActivationTokenStore: restored tokens from debug cache',
          );
        }
        try {
          await _storage.write(key: _kAccess, value: a!);
          await _storage.write(key: _kRefresh, value: r!);
          _debugFallback = false;
          _debugAccess = null;
          _debugRefresh = null;
          await _deleteDebugCacheFile();
        } catch (_) {
          // Keep debug cache + memory for this session.
        }
      }
      return access ? a : r;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureActivationTokenStore: debug cache read failed — $e');
      }
      return null;
    }
  }

  Future<void> _deleteDebugCacheFile() async {
    if (!kDebugMode) return;
    final file = await _debugCacheFile();
    if (file != null && file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}
