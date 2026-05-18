import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

const String _kFallbackUrl = 'http://127.0.0.1:3000';
const String _kEnvVar = 'POS_API_BASE_URL';
const String _kConfigFile = 'app_config.json';

/// Resolves the API base URL from (in priority order):
///   1. `app_config.json` beside the executable
///   2. Environment variable `POS_API_BASE_URL`
///   3. Fallback `http://127.0.0.1:3000`
class RuntimeConfigService {
  RuntimeConfigService._();
  static final RuntimeConfigService instance = RuntimeConfigService._();

  String _apiBaseUrl = _kFallbackUrl;
  bool _usingFallback = true;

  String get apiBaseUrl => _apiBaseUrl;

  bool get isUsingFallback => _usingFallback;

  String getApiBaseUrl() => _apiBaseUrl;

  /// Loads config from file or env var. Safe to call multiple times.
  Future<void> load() async {
    final fromFile = await _loadFromFile();
    if (fromFile != null) {
      _apiBaseUrl = fromFile;
      _usingFallback = false;
      if (kDebugMode) debugPrint('RuntimeConfigService: source = file');
    } else {
      final fromEnv = _loadFromEnv();
      if (fromEnv != null) {
        _apiBaseUrl = fromEnv;
        _usingFallback = false;
        if (kDebugMode) debugPrint('RuntimeConfigService: source = env var ($_kEnvVar)');
      } else {
        _apiBaseUrl = _kFallbackUrl;
        _usingFallback = true;
        if (kDebugMode) debugPrint('RuntimeConfigService: source = fallback (WARNING: localhost)');
      }
    }
    if (kDebugMode) debugPrint('RuntimeConfigService: resolved API base URL = $_apiBaseUrl');
  }

  Future<void> reloadConfig() => load();

  Future<String?> _loadFromFile() async {
    try {
      final execDir = File(Platform.resolvedExecutable).parent.path;
      final configFile = File('$execDir${Platform.pathSeparator}$_kConfigFile');
      if (!configFile.existsSync()) return null;
      final contents = await configFile.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>?;
      final raw = json?['apiBaseUrl'] as String?;
      return _validate(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('RuntimeConfigService: file read error: $e');
      return null;
    }
  }

  String? _loadFromEnv() {
    final raw = Platform.environment[_kEnvVar];
    return _validate(raw);
  }

  static String? _validate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      if (kDebugMode) {
        debugPrint('RuntimeConfigService: invalid URL (must start with http:// or https://): $raw');
      }
      return null;
    }
    return trimmed;
  }
}
