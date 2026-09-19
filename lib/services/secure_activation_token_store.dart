import 'dart:convert';
import 'dart:io' show Directory, File, Platform;

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as aes;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'windows_dpapi.dart';

/// OS-backed storage for activation tokens (not SQLite plaintext).
///
/// Windows uses DPAPI via Dart FFI (no `flutter_secure_storage` C++ / ATL).
/// Other desktops use an AES-encrypted file in the app support directory.
class SecureActivationTokenStore {
  SecureActivationTokenStore._();
  static final SecureActivationTokenStore instance =
      SecureActivationTokenStore._();

  static const String legacyAccessTokenKey = 'activation_access_token';
  static const String legacyRefreshTokenKey = 'activation_refresh_token';

  static const String storageLabel = 'Secure (OS DPAPI / encrypted file)';

  static const String _fileName = 'pos_activation_tokens.bin';
  static const String _kDebugCacheFileName = '.pos_activation_tokens_debug.json';

  String? _debugAccess;
  String? _debugRefresh;
  bool _debugFallback = false;
  String? _cachedAccess;
  String? _cachedRefresh;

  bool get usesDebugFallback => _debugFallback && kDebugMode;

  String get diagnosticsStorageLabel => usesDebugFallback
      ? 'Debug memory (secure storage unavailable)'
      : storageLabel;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (accessToken.isEmpty) {
      throw ArgumentError.value(accessToken, 'accessToken', 'must not be empty');
    }
    try {
      await _writeProtected({
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      });
      _cachedAccess = accessToken;
      _cachedRefresh = refreshToken;
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
    if (_nonEmpty(_cachedAccess)) return _cachedAccess;
    try {
      final map = await _readProtected();
      _cachedAccess = map?['accessToken'];
      _cachedRefresh = map?['refreshToken'];
      if (_nonEmpty(_cachedAccess)) return _cachedAccess;
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
    if (_nonEmpty(_cachedRefresh)) return _cachedRefresh;
    try {
      final map = await _readProtected();
      _cachedAccess = map?['accessToken'];
      _cachedRefresh = map?['refreshToken'];
      if (_nonEmpty(_cachedRefresh)) return _cachedRefresh;
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
    _cachedAccess = null;
    _cachedRefresh = null;
    try {
      final file = await _tokenFile();
      if (file.existsSync()) await file.delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureActivationTokenStore: clear failed — $e');
      }
    }
    await _deleteDebugCacheFile();
  }

  Future<bool> hasTokens() async => hasValidTokenPair();

  Future<bool> hasValidTokenPair() async {
    final access = await readAccessToken();
    final refresh = await readRefreshToken();
    return _nonEmpty(access) && _nonEmpty(refresh);
  }

  static bool _nonEmpty(String? value) =>
      value != null && value.trim().isNotEmpty;

  Future<File> _tokenFile() async {
    final dir = await getApplicationSupportDirectory();
    await Directory(dir.path).create(recursive: true);
    return File(p.join(dir.path, _fileName));
  }

  Future<void> _writeProtected(Map<String, String> tokens) async {
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(tokens)));
    final bytes = WindowsDpapi.isAvailable
        ? WindowsDpapi.protect(plaintext)
        : _aesProtect(plaintext);
    final file = await _tokenFile();
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<Map<String, String>?> _readProtected() async {
    final file = await _tokenFile();
    if (!file.existsSync()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    final plaintext = WindowsDpapi.isAvailable
        ? WindowsDpapi.unprotect(Uint8List.fromList(bytes))
        : _aesUnprotect(Uint8List.fromList(bytes));
    final json = jsonDecode(utf8.decode(plaintext));
    if (json is! Map) return null;
    return {
      'accessToken': '${json['accessToken'] ?? ''}',
      'refreshToken': '${json['refreshToken'] ?? ''}',
    };
  }

  static Uint8List _aesKey() {
    final material =
        'pos-system-activation-v1|${Platform.localHostname}|${Platform.operatingSystem}';
    return Uint8List.fromList(sha256.convert(utf8.encode(material)).bytes);
  }

  static Uint8List _aesProtect(Uint8List plaintext) {
    final key = aes.Key(_aesKey());
    final iv = aes.IV.fromSecureRandom(16);
    final encrypter = aes.Encrypter(aes.AES(key, mode: aes.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plaintext, iv: iv);
    return Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
  }

  static Uint8List _aesUnprotect(Uint8List blob) {
    if (blob.length < 17) {
      throw StateError('Encrypted token file is too short.');
    }
    final key = aes.Key(_aesKey());
    final iv = aes.IV(blob.sublist(0, 16));
    final encrypter = aes.Encrypter(aes.AES(key, mode: aes.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(
      aes.Encrypted(blob.sublist(16)),
      iv: iv,
    );
    return Uint8List.fromList(decrypted);
  }

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
        try {
          await saveTokens(accessToken: a!, refreshToken: r!);
        } catch (_) {}
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
