import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as aes;

/// AES-256-CBC encryption/decryption for exported backup files.
///
/// ## On-disk format
/// ```
///  Offset  Len   Field
///  ──────  ───   ─────
///       0    8   Magic      "POSENC1\x00"  (identifies POS encrypted backup)
///       8   16   Salt       random bytes   (for key derivation)
///      24   16   IV         random bytes   (AES initialisation vector)
///      40   32   Checksum   SHA-256 of the original plaintext
///      72    N   Ciphertext AES-256-CBC + PKCS7 padding
/// ```
///
/// ## Key derivation
/// An iterated SHA-256 chain rooted in (password ‖ salt):
/// ```
///   k₀ = SHA256(password_bytes ‖ salt)
///   kᵢ = SHA256(kᵢ₋₁)          for i = 1 … _iterations-1
/// ```
/// 100 000 iterations ≈ 35–80 ms on typical hardware, making brute-force
/// dictionary attacks impractical without slowing normal usage.
///
/// ## Wrong-password detection
/// The SHA-256 checksum of the plaintext is stored in the header (plain, not
/// encrypted).  After decryption the checksum is recomputed and compared.
/// This catches both PKCS7 padding failures and the rare case where a wrong
/// key produces valid-looking padding.
class BackupCryptoService {
  BackupCryptoService._();
  static final BackupCryptoService instance = BackupCryptoService._();

  static const List<int> _magic = [
    0x50, 0x4f, 0x53, 0x45, 0x4e, 0x43, 0x31, 0x00, // "POSENC1\0"
  ];
  static const int _iterations = 100000;
  // Header = magic(8) + salt(16) + iv(16) + checksum(32) = 72
  static const int _headerSize = 72;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Reads [sourcePath], encrypts it with [password], and writes the result to
  /// [destPath].  [destPath] is written atomically via a temp file so a crash
  /// mid-write never leaves a partial encrypted file.
  Future<void> encryptFile(
    String sourcePath,
    String destPath,
    String password,
  ) async {
    final plaintext = await File(sourcePath).readAsBytes();

    final rng = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => rng.nextInt(256)),
    );
    final iv = Uint8List.fromList(
      List<int>.generate(16, (_) => rng.nextInt(256)),
    );

    final key = _deriveKey(password, salt);
    final checksum = Uint8List.fromList(sha256.convert(plaintext).bytes);

    final encrypter = aes.Encrypter(
      aes.AES(aes.Key(key), mode: aes.AESMode.cbc),
    );
    final encrypted = encrypter.encryptBytes(plaintext, iv: aes.IV(iv));

    final builder = BytesBuilder(copy: false);
    builder.add(_magic);
    builder.add(salt);
    builder.add(iv);
    builder.add(checksum);
    builder.add(encrypted.bytes);

    // Write to temp first, then rename — never a partial file at destPath.
    final tempPath = '$destPath.enc_write_tmp';
    try {
      await File(tempPath).writeAsBytes(builder.toBytes(), flush: true);
      try {
        await File(tempPath).rename(destPath);
      } catch (_) {
        await File(tempPath).copy(destPath);
        await File(tempPath).delete();
      }
    } catch (e) {
      await _tryDelete(tempPath);
      rethrow;
    }
  }

  /// Decrypts [sourcePath] (written by [encryptFile]) and writes the plaintext
  /// to [destPath].
  ///
  /// Throws [Exception] with a human-readable message if:
  /// - the magic header is wrong (not a POS encrypted backup)
  /// - the file is too short
  /// - PKCS7 unpadding fails (almost always a wrong password)
  /// - the plaintext SHA-256 checksum does not match (wrong password or
  ///   corruption that happened to produce valid padding)
  Future<void> decryptFile(
    String sourcePath,
    String destPath,
    String password,
  ) async {
    final data = await File(sourcePath).readAsBytes();

    // ── Header validation ────────────────────────────────────────────────────
    if (data.length < _headerSize + 16) {
      throw Exception(
        'The file is too small to be a valid encrypted backup '
        '(${data.length} bytes).',
      );
    }
    for (int i = 0; i < _magic.length; i++) {
      if (data[i] != _magic[i]) {
        throw Exception(
          'Not a POS encrypted backup — the file header does not match.',
        );
      }
    }

    final salt = data.sublist(8, 24);
    final iv = data.sublist(24, 40);
    final storedChecksum = data.sublist(40, 72);
    final ciphertext = data.sublist(72);

    // ── Decrypt ──────────────────────────────────────────────────────────────
    final key = _deriveKey(password, salt);
    late List<int> plaintext;
    try {
      final encrypter = aes.Encrypter(
        aes.AES(aes.Key(key), mode: aes.AESMode.cbc),
      );
      plaintext = encrypter.decryptBytes(
        aes.Encrypted(Uint8List.fromList(ciphertext)),
        iv: aes.IV(Uint8List.fromList(iv)),
      );
    } catch (_) {
      // PKCS7 unpadding failure → almost certainly a wrong password.
      throw Exception(
        'Decryption failed — the password is incorrect or the file is corrupted.',
      );
    }

    // ── Checksum verification ─────────────────────────────────────────────────
    final actualChecksum = sha256.convert(plaintext).bytes;
    for (int i = 0; i < 32; i++) {
      if (actualChecksum[i] != storedChecksum[i]) {
        throw Exception(
          'Password accepted but the decrypted content is corrupt.\n'
          'The backup file may have been damaged.',
        );
      }
    }

    // ── Write output ─────────────────────────────────────────────────────────
    final tempPath = '$destPath.dec_write_tmp';
    try {
      await File(tempPath).writeAsBytes(plaintext, flush: true);
      try {
        await File(tempPath).rename(destPath);
      } catch (_) {
        await File(tempPath).copy(destPath);
        await File(tempPath).delete();
      }
    } catch (e) {
      await _tryDelete(tempPath);
      rethrow;
    }
  }

  /// Returns [true] if [path] begins with the POSENC1 magic header.
  Future<bool> isEncryptedFile(String path) async {
    try {
      final bytes = <int>[];
      await for (final chunk in File(path).openRead(0, 8)) {
        bytes.addAll(chunk);
        if (bytes.length >= 8) break;
      }
      if (bytes.length < 8) return false;
      for (int i = 0; i < _magic.length; i++) {
        if (bytes[i] != _magic[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Key derivation ─────────────────────────────────────────────────────────

  Uint8List _deriveKey(String password, List<int> salt) {
    final seed = Uint8List.fromList([...utf8.encode(password), ...salt]);
    // Iteration 0: hash password + salt together so the key depends on both.
    var current = sha256.convert(seed).bytes;
    for (int i = 1; i < _iterations; i++) {
      current = sha256.convert(current).bytes;
    }
    return Uint8List.fromList(current);
  }

  Future<void> _tryDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
