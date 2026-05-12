import 'dart:io' show Platform;
import 'dart:math';

import 'database_service.dart';

const String _kAppVersion = '1.0.0';

/// Provides device-level forensic context that is stamped on every audit log.
///
/// - [deviceId]     — stable UUID stored in `app_meta`; survives app restarts.
/// - [sessionId]    — ephemeral UUID rotated on each manager/waiter login.
/// - [terminalName] — OS hostname.
/// - [platform]     — dart:io platform string (windows / linux / macos / …).
/// - [appVersion]   — bumped in [_kAppVersion] with each release.
///
/// All fields are optional in the DB; null-safe reads in [AuditLogRow.fromMap].
class AuditContextService {
  AuditContextService._();
  static final AuditContextService instance = AuditContextService._();

  String? _deviceId;
  String _sessionId = _generateUuid();
  String? _platform;
  String? _terminalName;
  bool _initialized = false;

  /// Idempotent — safe to call on every log write.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _loadOrCreateDeviceId();
    _platform = _detectPlatform();
    _terminalName = _detectHostname();
  }

  /// Rotate the session token — called on every manager/waiter login so each
  /// session's actions are forensically distinguishable.
  void rotateSession() => _sessionId = _generateUuid();

  String? get deviceId    => _deviceId;
  String  get sessionId   => _sessionId;
  String? get platform    => _platform;
  String? get terminalName => _terminalName;
  String  get appVersion  => _kAppVersion;

  // ── internals ──────────────────────────────────────────────────────────────

  Future<void> _loadOrCreateDeviceId() async {
    try {
      final existing = await DatabaseService.instance.getAppMeta('audit_device_id');
      if (existing != null && existing.isNotEmpty) {
        _deviceId = existing;
      } else {
        _deviceId = _generateUuid();
        await DatabaseService.instance.setAppMeta('audit_device_id', _deviceId!);
      }
    } catch (_) {
      _deviceId ??= _generateUuid();
    }
  }

  static String _detectPlatform() {
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  static String _detectHostname() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'pos-terminal';
    }
  }

  static String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
