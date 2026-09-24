import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as aes;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../windows_dpapi.dart';

/// OS-backed storage for the ATK signing key — never SQLite plaintext.
///
/// This key signs tax documents. Whoever holds it can issue coupons in the
/// business's name, so it gets the same protection as the activation tokens:
/// Windows DPAPI (tied to the Windows user account), or an AES-encrypted file
/// on other desktops.
///
/// ATK's own rule is that the private key must never leave the machine it was
/// generated on, so there is deliberately no export-to-cloud path here.
class SecureFiscalKeyStore {
  SecureFiscalKeyStore._();
  static final SecureFiscalKeyStore instance = SecureFiscalKeyStore._();

  static const String storageLabel = 'Secure (OS DPAPI / encrypted file)';
  static const String _fileName = 'pos_fiscal_key.bin';

  String? _cachedPrivateKey;
  String? _cachedCertificate;

  Future<File> _keyFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<void> save({
    required String privateKeyPem,
    String certificatePem = '',
  }) async {
    final payload = <String, String>{
      'privateKey': privateKeyPem,
      'certificate': certificatePem,
    };
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    final bytes = WindowsDpapi.isAvailable
        ? WindowsDpapi.protect(plaintext)
        : _aesProtect(plaintext);
    final file = await _keyFile();
    await file.writeAsBytes(bytes, flush: true);
    _cachedPrivateKey = privateKeyPem;
    _cachedCertificate = certificatePem;
  }

  Future<String?> readPrivateKey() async {
    if (_cachedPrivateKey != null) return _cachedPrivateKey;
    await _load();
    return _cachedPrivateKey;
  }

  Future<String?> readCertificate() async {
    if (_cachedCertificate != null) return _cachedCertificate;
    await _load();
    return _cachedCertificate;
  }

  Future<bool> hasKey() async {
    final key = await readPrivateKey();
    return key != null && key.trim().isNotEmpty;
  }

  Future<void> clear() async {
    _cachedPrivateKey = null;
    _cachedCertificate = null;
    try {
      final file = await _keyFile();
      if (file.existsSync()) await file.delete();
    } catch (e) {
      debugPrint('SecureFiscalKeyStore.clear failed: $e');
    }
  }

  Future<void> _load() async {
    try {
      final file = await _keyFile();
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      final plaintext = WindowsDpapi.isAvailable
          ? WindowsDpapi.unprotect(Uint8List.fromList(bytes))
          : _aesUnprotect(Uint8List.fromList(bytes));
      final json = jsonDecode(utf8.decode(plaintext));
      if (json is! Map) return;
      _cachedPrivateKey = '${json['privateKey'] ?? ''}';
      _cachedCertificate = '${json['certificate'] ?? ''}';
    } catch (e) {
      debugPrint('SecureFiscalKeyStore.read failed: $e');
    }
  }

  static Uint8List _aesKey() {
    final material =
        'pos-system-fiscal-key-v1|${Platform.localHostname}|${Platform.operatingSystem}';
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
      throw StateError('Encrypted fiscal key file is too short.');
    }
    final key = aes.Key(_aesKey());
    final iv = aes.IV(blob.sublist(0, 16));
    final encrypter = aes.Encrypter(aes.AES(key, mode: aes.AESMode.cbc));
    return Uint8List.fromList(
      encrypter.decryptBytes(aes.Encrypted(blob.sublist(16)), iv: iv),
    );
  }
}
