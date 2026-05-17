import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'backup_crypto_service.dart';
import 'database_service.dart';

/// Handles exporting the live database to a user-chosen or platform-default
/// destination, with optional ZIP compression and/or AES-256 encryption.
///
/// ## Export pipeline
/// ```
///   source DB  ──►  VACUUM INTO (or file copy)  ──►  [encrypt?]  ──►  [zip?]  ──►  dest
/// ```
/// Every intermediate artefact is written to a `.tmp` sidecar so a crash or
/// disk-full error at any stage leaves the destination untouched.
///
/// ## File naming
/// | Options                | Extension  |
/// |------------------------|------------|
/// | plain                  | .db        |
/// | compressed only        | .zip       |
/// | encrypted only         | .enc.db    |
/// | encrypted + compressed | .enc.zip   |
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  /// Exports the current database.
  ///
  /// [compressed] — wrap the output in a ZIP archive.
  /// [password]   — if non-empty, AES-256-CBC encrypt the output before saving.
  ///
  /// Returns the full path of the saved file, or [null] if the user cancelled
  /// the destination picker.
  Future<String?> exportDatabase({
    bool compressed = false,
    String? password,
  }) async {
    // Encryption is mandatory for all exports.
    if (password == null || password.length < 8) {
      throw Exception(
        'A backup password of at least 8 characters is required.',
      );
    }

    final sourcePath = await getDatabaseFilePath();
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Database file not found at: $sourcePath');
    }

    // Encryption is always applied; extension reflects compression choice.
    final now = DateTime.now();
    final base = 'pos_backup_${now.year}_${_pad(now.month)}_${_pad(now.day)}';

    final String outerExt = compressed ? '.enc.zip' : '.enc.db';
    final String innerExt = compressed ? '.enc.db' : '';

    final fileName = '$base$outerExt';
    final destPath = await _resolveDestination(fileName);
    if (destPath == null) return null; // user cancelled

    // Temp paths are scoped to the destination filename to avoid collisions.
    final rawTemp = '$destPath.raw_tmp';
    final encTemp = '$destPath.enc_tmp';
    final zipTemp = '$destPath.zip_tmp';

    try {
      // ── Step 1: raw DB snapshot via VACUUM INTO (or file-copy fallback) ───
      await _createRawBackup(sourcePath, rawTemp);
      String current = rawTemp;

      // ── Step 2: encrypt ────────────────────────────────────────────────────
      await BackupCryptoService.instance.encryptFile(
        current,
        encTemp,
        password,
      );
      await _tryDelete(current);
      current = encTemp;

      // ── Step 3: optional ZIP compression ──────────────────────────────────
      if (compressed) {
        final entryName = '$base$innerExt';
        await _compressToZip(current, zipTemp, entryName);
        await _tryDelete(current);
        current = zipTemp;
      }

      // ── Step 4: move to final destination ─────────────────────────────────
      try {
        await File(current).rename(destPath);
      } catch (_) {
        // Cross-device (e.g. different Windows drive): copy then delete.
        await File(current).copy(destPath);
        await _tryDelete(current);
      }

      return destPath;
    } catch (e) {
      // Clean up every temp artefact so nothing is left on disk.
      await _tryDelete(rawTemp);
      await _tryDelete(encTemp);
      await _tryDelete(zipTemp);
      rethrow;
    }
  }

  /// Returns the filesystem path of the active pos_system.db file.
  Future<String> getDatabaseFilePath() async {
    final dbDir = await getDatabasesPath();
    return p.join(dbDir, 'pos_system.db');
  }

  // ── Raw DB snapshot ────────────────────────────────────────────────────────

  /// Tries VACUUM INTO first (consistent read-only snapshot, SQLite 3.27.0+).
  /// Falls back to a plain file copy if VACUUM INTO is unsupported.
  Future<void> _createRawBackup(String sourcePath, String destPath) async {
    final ok = await DatabaseService.instance.vacuumInto(destPath);
    if (!ok) {
      // Older SQLite: plain file copy (still guarded by the outer temp strategy).
      await File(sourcePath).copy(destPath);
    }
  }

  // ── ZIP compression ────────────────────────────────────────────────────────

  Future<void> _compressToZip(
    String sourcePath,
    String zipPath,
    String entryName,
  ) async {
    final sourceBytes = await File(sourcePath).readAsBytes();
    final archive = Archive()
      ..addFile(
        ArchiveFile(entryName, sourceBytes.length, sourceBytes),
      );
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw Exception('ZIP encoding produced no output.');
    await File(zipPath).writeAsBytes(encoded, flush: true);
  }

  // ── Destination resolution ─────────────────────────────────────────────────

  Future<String?> _resolveDestination(String fileName) async {
    if (Platform.isAndroid) {
      return p.join(await _androidExportDir(), fileName);
    }
    if (Platform.isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      return p.join(docs.path, fileName);
    }
    // Desktop: show a native folder picker.
    final chosen = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select backup destination folder',
    );
    if (chosen == null) return null;
    return p.join(chosen, fileName);
  }

  Future<String> _androidExportDir() async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext.path;
    } catch (_) {}
    return (await getApplicationDocumentsDirectory()).path;
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  Future<void> _tryDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
