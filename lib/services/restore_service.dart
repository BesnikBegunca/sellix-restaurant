import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'backup_crypto_service.dart';
import 'database_service.dart';

/// Magic bytes of a valid SQLite 3 file.
const List<int> _sqliteMagic = [
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, // "SQLite f"
  0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00, // "ormat 3\0"
];

/// ZIP file magic (first 4 bytes: "PK\x03\x04").
const List<int> _zipMagic = [0x50, 0x4b, 0x03, 0x04];

/// Tables that must exist in a valid POS database.
const List<String> _criticalTables = [
  'company', 'waiters', 'products', 'categories', 'sales', 'tables',
];

/// Handles importing a backup file and safely replacing the live database.
///
/// ## Supported input formats
/// | Format         | Extension     | Detection                          |
/// |----------------|---------------|------------------------------------|
/// | Plain SQLite   | .db           | SQLite magic header                |
/// | ZIP archive    | .zip / .enc.zip | ZIP magic (PK\x03\x04)           |
/// | Encrypted      | .enc.db       | POSENC1\x00 magic header           |
/// | Zip + Encrypted| .enc.zip      | Outer ZIP contains inner .enc.db   |
///
/// ## Full restore pipeline
/// 1. User picks file via OS picker.
/// 2. If ZIP → extract the first `.db` or `.enc.db` entry to a temp dir.
/// 3. If encrypted → call [onPasswordRequired], decrypt to temp file.
/// 4. Validate SQLite magic bytes.
/// 5. Copy prepared file to temp path (nothing destructive yet).
/// 6. Close live DB connection.
/// 7. Copy live DB to `.pre_restore_backup` (permanent sidecar).
/// 8. Move temp file to live DB path.
/// 9. Reopen DB (triggers schema upgrades automatically).
/// 10. **PRAGMA integrity_check** — if not "ok": auto-rollback, throw.
/// 11. **Verify critical tables** — if any missing: auto-rollback, throw.
/// 12. Call [onReloadData] to refresh in-memory state.
///
/// ## Undo restore
/// [undoLastRestore] reverses the most recent restore using the
/// `.pre_restore_backup` sidecar.  It runs the same integrity + table checks
/// before committing the rollback, and deletes the sidecar afterwards.
class RestoreService {
  RestoreService._();
  static final RestoreService instance = RestoreService._();

  bool _isRestoring = false;

  /// True while any restore/undo operation is in progress.
  bool get isRestoring => _isRestoring;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns [true] if a `.pre_restore_backup` sidecar exists, meaning
  /// [undoLastRestore] is available.
  Future<bool> hasUndoAvailable() async {
    final dbDir = await getDatabasesPath();
    return File(p.join(dbDir, 'pos_system.db.pre_restore_backup')).existsSync();
  }

  /// Prompts the user to select a backup file and restores it.
  ///
  /// [onReloadData]     — called after a successful restore to refresh state.
  /// [onPasswordRequired] — called when an encrypted file is detected; must
  ///                        return the password string or [null] to cancel.
  ///
  /// Returns [true] on success, [false] if the user cancelled any picker or
  /// password prompt.  Throws a descriptive [Exception] on error; the live
  /// database is never left in a corrupted state.
  Future<bool> restoreDatabase({
    required Future<void> Function() onReloadData,
    Future<String?> Function()? onPasswordRequired,
    Future<bool> Function()? onPlaintextWarning,
  }) async {
    if (_isRestoring) {
      throw Exception('A restore operation is already in progress.');
    }
    _isRestoring = true;

    final dbDir = await getDatabasesPath();
    final livePath = p.join(dbDir, 'pos_system.db');
    final safetyPath = '$livePath.pre_restore_backup';
    final liveTemp = '$livePath.restore_tmp';

    // Temp directory for ZIP extraction / decryption work.
    final workDir = await Directory.systemTemp.createTemp('pos_restore_');

    try {
      // ── Step 1: pick file ────────────────────────────────────────────────
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select database backup file',
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return false;

      final selectedPath = result.files.first.path;
      if (selectedPath == null) {
        throw Exception('Could not read the selected file path.');
      }

      final selectedFile = File(selectedPath);
      if (!await selectedFile.exists()) {
        throw Exception('The selected file no longer exists.');
      }
      if (await selectedFile.length() < 100) {
        throw Exception('The selected file is too small to be a valid backup.');
      }

      // ── Step 2: un-ZIP if needed ─────────────────────────────────────────
      String workingPath = selectedPath;
      if (await _isZipFile(workingPath)) {
        workingPath = await _extractDbFromZip(workingPath, workDir.path);
      }

      // ── Step 3: decrypt if needed ────────────────────────────────────────
      if (await BackupCryptoService.instance.isEncryptedFile(workingPath)) {
        if (onPasswordRequired == null) {
          throw Exception(
            'This backup is encrypted but no password was provided.',
          );
        }
        final password = await onPasswordRequired();
        if (password == null || password.isEmpty) return false; // cancelled

        final decryptedPath = p.join(workDir.path, 'decrypted.db');
        await BackupCryptoService.instance.decryptFile(
          workingPath,
          decryptedPath,
          password,
        );
        workingPath = decryptedPath;
      } else if (onPlaintextWarning != null) {
        // Backup is not encrypted — give the caller a chance to warn and abort.
        final proceed = await onPlaintextWarning();
        if (!proceed) return false;
      }

      // ── Step 4: validate SQLite header ───────────────────────────────────
      await _assertSQLiteHeader(File(workingPath));

      // ── Step 5: copy to temp path (before touching live DB) ──────────────
      await File(workingPath).copy(liveTemp);

      // ── Step 6: close live DB connection ─────────────────────────────────
      await DatabaseService.instance.closeDatabase();

      // ── Step 7: safety sidecar of the current live DB ────────────────────
      final liveFile = File(livePath);
      if (await liveFile.exists()) {
        await liveFile.copy(safetyPath);
      }

      // ── Step 8: place the restored DB ────────────────────────────────────
      try {
        await File(liveTemp).rename(livePath);
      } catch (_) {
        await File(liveTemp).copy(livePath);
        await _tryDelete(liveTemp);
      }

      // ── Step 9: reopen (triggers onUpgrade for older backups) ─────────────
      await DatabaseService.instance.reopenDatabase();

      // ── Step 10 & 11: integrity + table checks ────────────────────────────
      await _runPostRestoreChecks(livePath, safetyPath);

      // ── Step 12: reload in-memory state ───────────────────────────────────
      await onReloadData();
      return true;
    } catch (e) {
      // Ensure the DB is open regardless of where the error occurred.
      try {
        await DatabaseService.instance.reopenDatabase();
      } catch (_) {}
      rethrow;
    } finally {
      _isRestoring = false;
      await _tryDelete(liveTemp);
      await _tryDeleteDir(workDir);
    }
  }

  /// Reverts the most recent restore using the `.pre_restore_backup` sidecar.
  ///
  /// [onReloadData] — called after a successful undo to refresh state.
  ///
  /// Returns [true] on success, [false] if no sidecar exists.
  /// Throws on integrity failure or I/O error.
  Future<bool> undoLastRestore({
    required Future<void> Function() onReloadData,
  }) async {
    if (_isRestoring) {
      throw Exception('A restore operation is already in progress.');
    }
    _isRestoring = true;

    final dbDir = await getDatabasesPath();
    final livePath = p.join(dbDir, 'pos_system.db');
    final safetyPath = '$livePath.pre_restore_backup';
    final undoTemp = '$livePath.undo_tmp';

    try {
      if (!File(safetyPath).existsSync()) return false;

      // Validate the sidecar before doing anything destructive.
      await _assertSQLiteHeader(File(safetyPath));

      // Copy sidecar to temp (everything after this is "critical path").
      await File(safetyPath).copy(undoTemp);

      await DatabaseService.instance.closeDatabase();

      try {
        await File(undoTemp).rename(livePath);
      } catch (_) {
        await File(undoTemp).copy(livePath);
        await _tryDelete(undoTemp);
      }

      await DatabaseService.instance.reopenDatabase();

      // Run the same checks as a normal restore.
      // Pass an empty safetyPath — there is nothing to roll back to here.
      await _runPostRestoreChecks(livePath, null);

      // Only delete the sidecar after the checks pass.
      await _tryDelete(safetyPath);

      await onReloadData();
      return true;
    } catch (e) {
      try {
        await DatabaseService.instance.reopenDatabase();
      } catch (_) {}
      rethrow;
    } finally {
      _isRestoring = false;
      await _tryDelete(undoTemp);
    }
  }

  // ── Post-restore checks ────────────────────────────────────────────────────

  /// Runs PRAGMA integrity_check and verifies that all critical tables exist.
  ///
  /// [safetyPath] — if non-null and checks fail, the live DB is automatically
  /// rolled back to this path before the exception is thrown.
  Future<void> _runPostRestoreChecks(
    String livePath,
    String? safetyPath,
  ) async {
    try {
      final db = await DatabaseService.instance.database;

      // PRAGMA integrity_check returns one row per problem, or a single "ok".
      final rows = await db.rawQuery('PRAGMA integrity_check');
      final result =
          rows.isNotEmpty ? (rows.first.values.first?.toString() ?? '') : '';
      if (result != 'ok') {
        throw Exception(
          'PRAGMA integrity_check failed: $result',
        );
      }

      // Verify every critical table exists.
      for (final table in _criticalTables) {
        final count = await db.rawQuery(
          "SELECT COUNT(*) AS c FROM sqlite_master "
          "WHERE type='table' AND name=?",
          [table],
        );
        final n = count.isNotEmpty
            ? (count.first['c'] as int? ?? 0)
            : 0;
        if (n == 0) {
          throw Exception(
            'Critical table "$table" is missing from the restored database.',
          );
        }
      }
    } catch (integrityError) {
      // Auto-rollback: restore the safety sidecar if one was provided.
      if (safetyPath != null && File(safetyPath).existsSync()) {
        try {
          await DatabaseService.instance.closeDatabase();
          File(safetyPath).copySync(livePath);
          await DatabaseService.instance.reopenDatabase();
        } catch (_) {}
        throw Exception(
          'The backup failed validation and was automatically rolled back.\n'
          'Details: $integrityError',
        );
      }
      rethrow;
    }
  }

  // ── File-format helpers ────────────────────────────────────────────────────

  /// Reads up to 4 bytes and checks the ZIP magic header.
  Future<bool> _isZipFile(String path) async {
    try {
      final bytes = <int>[];
      await for (final chunk in File(path).openRead(0, 4)) {
        bytes.addAll(chunk);
        if (bytes.length >= 4) break;
      }
      if (bytes.length < 4) return false;
      for (int i = 0; i < _zipMagic.length; i++) {
        if (bytes[i] != _zipMagic[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Extracts the first `.db` or `.enc.db` file from the ZIP at [zipPath]
  /// into [extractDir] and returns its path.
  Future<String> _extractDbFromZip(String zipPath, String extractDir) async {
    final zipBytes = await File(zipPath).readAsBytes();
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e) {
      throw Exception('Invalid or corrupt ZIP archive: $e');
    }

    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name.endsWith('.db') || name.endsWith('.enc.db')) {
        final content = entry.content;
        if (content is! List<int>) {
          throw Exception('Unexpected archive entry type for "$name".');
        }
        final outPath = p.join(extractDir, p.basename(name));
        await File(outPath).writeAsBytes(content, flush: true);
        return outPath;
      }
    }
    throw Exception(
      'No .db or .enc.db file found inside the ZIP archive.\n'
      'Make sure you are selecting a POS backup archive.',
    );
  }

  /// Validates the first 16 bytes against the SQLite magic header.
  Future<void> _assertSQLiteHeader(File file) async {
    final bytes = <int>[];
    await for (final chunk in file.openRead(0, 16)) {
      bytes.addAll(chunk);
      if (bytes.length >= 16) break;
    }
    if (bytes.length < 16) {
      throw Exception(
        'Cannot read file header — is the file readable and at least 16 bytes?',
      );
    }
    for (int i = 0; i < _sqliteMagic.length; i++) {
      if (bytes[i] != _sqliteMagic[i]) {
        throw Exception(
          'The selected file is not a valid SQLite database.\n'
          'Please select a .db file exported from this POS system.',
        );
      }
    }
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  Future<void> _tryDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> _tryDeleteDir(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
