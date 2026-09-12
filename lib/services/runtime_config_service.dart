import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../l10n/tr.dart';

const String _kFallbackUrl = 'http://127.0.0.1:3000';
const String _kEnvVar = 'POS_API_BASE_URL';
const String _kConfigFile = 'app_config.json';

/// How the API base URL was resolved.
enum ApiConfigSource {
  /// `app_config.json` beside the executable (or macOS bundle parent).
  file,

  /// `POS_API_BASE_URL` environment variable.
  envVar,

  /// `release/app_config.json` in the project tree (debug / profile only).
  releaseDevFile,

  /// `http://127.0.0.1:3000` when nothing else matched (debug operations only).
  fallback,
}

/// Resolves the API base URL (priority):
///   1. `app_config.json` beside the executable (+ macOS bundle parent)
///   2. `POS_API_BASE_URL`
///   3. `release/app_config.json` (debug / profile only — not release builds)
///   4. localhost fallback (debug operations only; blocked in release)
class RuntimeConfigService {
  RuntimeConfigService._();
  static final RuntimeConfigService instance = RuntimeConfigService._();

  static String get productionConfigErrorTitle => tr.apiNukEshteKonfiguruar;

  static String get productionConfigErrorBody => tr.localhostNotAllowed;

  static String get syncConfigErrorMessage => productionConfigErrorTitle;

  String _apiBaseUrl = _kFallbackUrl;
  bool _usingFallback = true;
  ApiConfigSource _source = ApiConfigSource.fallback;
  String? _resolvedFromPath;

  String get apiBaseUrl => _apiBaseUrl;

  bool get isUsingFallback => _usingFallback;

  ApiConfigSource get configSource => _source;

  /// Path of the config file that was loaded, when applicable.
  String? get resolvedConfigPath => _resolvedFromPath;

  /// Short source id for logs (`file`, `env`, `release_file`, `fallback`).
  String get sourceLogLabel {
    switch (_source) {
      case ApiConfigSource.file:
        return 'file';
      case ApiConfigSource.envVar:
        return 'env';
      case ApiConfigSource.releaseDevFile:
        return 'release_file';
      case ApiConfigSource.fallback:
        return 'fallback';
    }
  }

  /// Path where release builds expect `app_config.json` (beside the executable).
  String get expectedConfigFilePath {
    try {
      final execDir = File(Platform.resolvedExecutable).parent;
      return '${execDir.path}${Platform.pathSeparator}$_kConfigFile';
    } catch (_) {
      return _kConfigFile;
    }
  }

  bool get configFileExists {
    try {
      return File(expectedConfigFilePath).existsSync();
    } catch (_) {
      return false;
    }
  }

  String get sourceLabel {
    switch (_source) {
      case ApiConfigSource.file:
        return 'app_config.json';
      case ApiConfigSource.envVar:
        return 'POS_API_BASE_URL';
      case ApiConfigSource.releaseDevFile:
        return 'app_config.json';
      case ApiConfigSource.fallback:
        return 'fallback_localhost';
    }
  }

  bool get isLocalhost => isLocalhostUrl(_apiBaseUrl);

  bool get isBlockedInRelease =>
      kReleaseMode && (isUsingFallback || isLocalhost);

  String getApiBaseUrl() => _apiBaseUrl;

  Future<void> load() async {
    _resolvedFromPath = null;

    for (final path in _executableConfigPaths()) {
      if (kDebugMode) debugPrint('[RuntimeConfig] checking: $path');
      final url = await _readConfigFile(path);
      if (url != null) {
        _applyResolved(url, ApiConfigSource.file, usingFallback: false, path: path);
        _logResolved();
        return;
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[RuntimeConfig] checking: env $_kEnvVar=${Platform.environment[_kEnvVar] != null ? "(set)" : "(not set)"}',
      );
    }
    final fromEnv = _loadFromEnv();
    if (fromEnv != null) {
      _applyResolved(fromEnv, ApiConfigSource.envVar, usingFallback: false);
      _logResolved();
      return;
    }

    if (!kReleaseMode) {
      for (final path in _debugReleaseConfigPaths()) {
        if (kDebugMode) debugPrint('[RuntimeConfig] checking: $path');
        final url = await _readConfigFile(path);
        if (url != null) {
          _applyResolved(
            url,
            ApiConfigSource.releaseDevFile,
            usingFallback: false,
            path: path,
          );
          _logResolved();
          return;
        }
      }
    }

    _applyResolved(
      _kFallbackUrl,
      ApiConfigSource.fallback,
      usingFallback: true,
    );
    _logResolved();
  }

  Future<void> reloadConfig() => load();

  static bool isLocalhostUrl(String url) {
    try {
      final host = Uri.parse(url.trim()).host.toLowerCase();
      return host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '::1' ||
          host == '0.0.0.0';
    } catch (_) {
      return false;
    }
  }

  void _applyResolved(
    String url,
    ApiConfigSource source, {
    required bool usingFallback,
    String? path,
  }) {
    _apiBaseUrl = url;
    _source = source;
    _usingFallback = usingFallback;
    _resolvedFromPath = path;
  }

  void _logResolved() {
    // ignore: avoid_print
    print('[RuntimeConfig] source=$sourceLabel');
    if (kReleaseMode && isBlockedInRelease) {
      // ignore: avoid_print
      print('[RuntimeConfig] ERROR: No production API configuration found.');
    }
    if (kDebugMode) {
      debugPrint('[RuntimeConfig] url=$_apiBaseUrl');
      debugPrint('[RuntimeConfig] localhost=$isLocalhost');
      if (_resolvedFromPath != null) {
        debugPrint('[RuntimeConfig] configPath=$_resolvedFromPath');
      }
    }
  }

  /// Beside executable; macOS also checks Contents/Resources (Bundle Resource,
  /// signed with the app) and the folder that contains the .app bundle.
  List<String> _executableConfigPaths() {
    final sep = Platform.pathSeparator;
    final paths = <String>[];

    try {
      final execDir = File(Platform.resolvedExecutable).parent;
      // Windows / Linux: beside the .exe
      // macOS: Contents/MacOS/ (not used — file should not be there)
      paths.add('${execDir.path}$sep$_kConfigFile');

      if (Platform.isMacOS) {
        // Contents/Resources/ — Bundle Resource, signed with the app
        final contentsDir = execDir.parent;
        paths.add('${contentsDir.path}${sep}Resources$sep$_kConfigFile');

        // Beside the .app (external deployment / IT admin drop)
        final bundleParent = execDir.parent.parent.parent;
        paths.add('${bundleParent.path}$sep$_kConfigFile');
      }
    } catch (_) {}

    return paths;
  }

  /// Debug/profile-only paths under the project tree.
  List<String> _debugReleaseConfigPaths() {
    final sep = Platform.pathSeparator;
    final paths = <String>[];

    // Project root (cwd) — primary
    paths.add('${Directory.current.path}$sep$_kConfigFile');
    // Legacy: release/app_config.json
    paths.add('${Directory.current.path}${sep}release$sep$_kConfigFile');

    final fromWalk = _findConfigNearExecutable();
    if (fromWalk != null && !paths.contains(fromWalk)) {
      paths.add(fromWalk);
    }

    return paths;
  }

  /// Walks up from the running binary looking for `app_config.json` or
  /// `release/app_config.json` in the project tree.
  static String? _findConfigNearExecutable() {
    try {
      var dir = File(Platform.resolvedExecutable).parent;
      for (var depth = 0; depth < 14; depth++) {
        final sep = Platform.pathSeparator;

        // Direct app_config.json (new canonical location)
        final direct = '${dir.path}$sep$_kConfigFile';
        if (File(direct).existsSync()) return direct;

        // Legacy release/app_config.json
        final legacy = '${dir.path}${sep}release$sep$_kConfigFile';
        if (File(legacy).existsSync()) return legacy;

        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _readConfigFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>?;
      return _validate(json?['apiBaseUrl'] as String?);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RuntimeConfig] read error $path: $e');
      }
      return null;
    }
  }

  String? _loadFromEnv() {
    return _validate(Platform.environment[_kEnvVar]);
  }

  static String? _validate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      if (kDebugMode) {
        debugPrint(
          '[RuntimeConfig] invalid URL (must start with http:// or https://): $raw',
        );
      }
      return null;
    }
    return trimmed;
  }
}
