import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Local license issuer/validator. No network or external service is used.
class LocalLicenseService {
  LocalLicenseService._();
  static final LocalLicenseService instance = LocalLicenseService._();

  static const String _secret = 'pos-system-local-license-v1';
  static const String _prefix = 'POS-LOCAL-';

  String generateLicense({required String ownerName, required int days}) {
    if (days < 1 || days > 3650) {
      throw ArgumentError.value(days, 'days', 'must be between 1 and 3650');
    }
    final expiry = DateTime.now().toUtc().add(Duration(days: days));
    final payload = jsonEncode({
      'id': _randomId(),
      'owner': ownerName.trim().isEmpty ? 'Owner' : ownerName.trim(),
      'expiresAt': expiry.toIso8601String(),
    });
    final encoded = base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
    final signature = _sign(encoded);
    return '$_prefix$encoded.$signature';
  }

  LocalLicenseData? validate(String code) {
    final value = code.trim();
    if (!value.startsWith(_prefix)) return null;
    final raw = value.substring(_prefix.length);
    final separator = raw.lastIndexOf('.');
    if (separator <= 0) return null;
    final encoded = raw.substring(0, separator);
    final signature = raw.substring(separator + 1);
    if (!_constantTimeEquals(signature, _sign(encoded))) return null;
    try {
      final normalized = base64Url.normalize(encoded);
      final json = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      final id = json['id'] as String?;
      final owner = json['owner'] as String?;
      final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
      if (id == null || owner == null || expiresAt == null) return null;
      if (!expiresAt.isAfter(DateTime.now().toUtc())) return null;
      return LocalLicenseData(
        licenseId: id,
        ownerName: owner,
        expiresAt: expiresAt,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  String _sign(String value) =>
      sha256.convert(utf8.encode('$_secret.$value')).toString();

  String _randomId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

class LocalLicenseData {
  const LocalLicenseData({
    required this.licenseId,
    required this.ownerName,
    required this.expiresAt,
  });

  final String licenseId;
  final String ownerName;
  final DateTime expiresAt;
}
