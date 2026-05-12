import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

/// Manages automatic daily backups of the POS database.
///
/// ## Configuration
/// Persisted in `{documentsDir}/pos_backup_config.json` — a file that lives
/// **outside** the main database so it survives a database restore.
///
/// Config keys:
/// | Key                | Type    | Meaning                                  |
/// |--------------------|---------|------------------------------------------|
/// | `autoBackupFolder` | String? | Destination directory for auto-backups   |
/// | `lastBackupDate`   | String? | Date of last successful backup YYYY-MM-DD|
/// | `useCompression`   | bool    | Wrap backups in a ZIP archive            |
///
/// ## Policy
/// - One backup per calendar day (at most).
/// - Keeps the newest [_maxBackups] files; older ones are deleted automatically.
/// - Pruning considers both `.db` and `.zip` files whose name starts with
///   `pos_backup_`.
///
/// Call [performAutoBackupIfNeeded] once on every app open (or whenever Admin
/// Settings is opened) — it returns early without doing anything if today's
/// backup already exists or no folder has been configured.
class DatabaseBackupManager {
  DatabaseBackupManager._();
  static final DatabaseBackupManager instance = DatabaseBackupManager._();

  static const int _maxBackups = 7;
  static const String _configFileName = 'pos_backup_config.json';

  // ── Config I/O ─────────────────────────────────────────────────────────────

  Future<File> _configFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _configFileName));
  }

  Future<Map<String, dynamic>> _readConfig() async {
    try {
      final file = await _configFile();
      if (!await file.exists()) return {};
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveConfig(Map<String, dynamic> cfg) async {
    try {
      final file = await _configFile();
      await file.writeAsString(jsonEncode(cfg));
    } catch (_) {}
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the configured auto-backup folder, or [null] if none is set.
  Future<String?> getAutoBackupFolder() async {
    return (await _readConfig())['autoBackupFolder'] as String?;
  }

  /// Whether auto-backups are compressed into ZIP archives.
  Future<bool> getUseCompression() async {
    return (await _readConfig())['useCompression'] as bool? ?? false;
  }

  /// Persists the compression preference.
  Future<void> setUseCompression(bool value) async {
    final cfg = await _readConfig();
    cfg['useCompression'] = value;
    await _saveConfig(cfg);
  }

  /// Opens a folder picker and saves the chosen path as the auto-backup
  /// destination.  Returns the chosen path, or [null] if the user cancelled.
  Future<String?> pickAndSetAutoBackupFolder() async {
    final chosen = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select automatic backup destination folder',
    );
    if (chosen == null) return null;
    final cfg = await _readConfig();
    cfg['autoBackupFolder'] = chosen;
    await _saveConfig(cfg);
    return chosen;
  }

  /// Creates an auto-backup if one has not been made today.
  ///
  /// Returns immediately with [AutoBackupResult.noFolderConfigured] if no
  /// destination folder has been set — safe to call on every app open.
  Future<AutoBackupResult> performAutoBackupIfNeeded() async {
    final folder = await getAutoBackupFolder();
    if (folder == null) return AutoBackupResult.noFolderConfigured;

    final cfg = await _readConfig();
    if ((cfg['lastBackupDate'] as String?) == _todayKey()) {
      return AutoBackupResult.alreadyBackedUpToday;
    }
    return _runBackup(folder, compress: cfg['useCompression'] as bool? ?? false);
  }

  /// Forces an immediate backup regardless of whether one was already made
  /// today.  If no folder is configured, defaults to
  /// `{documents}/POS_Backups` and saves that as the configured folder.
  Future<AutoBackupResult> performAutoBackup() async {
    final cfg = await _readConfig();
    String folder = cfg['autoBackupFolder'] as String? ??
        await _ensureDefaultFolder(cfg);
    return _runBackup(
      folder,
      compress: cfg['useCompression'] as bool? ?? false,
    );
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<String> _ensureDefaultFolder(Map<String, dynamic> cfg) async {
    final docs = await getApplicationDocumentsDirectory();
    final path = p.join(docs.path, 'POS_Backups');
    cfg['autoBackupFolder'] = path;
    await _saveConfig(cfg);
    return path;
  }

  Future<AutoBackupResult> _runBackup(
    String folder, {
    required bool compress,
  }) async {
    try {
      final dir = Directory(folder);
      if (!await dir.exists()) await dir.create(recursive: true);

      final dbDir = await getDatabasesPath();
      final sourceFile = File(p.join(dbDir, 'pos_system.db'));
      if (!await sourceFile.exists()) return AutoBackupResult.sourceNotFound;

      final now = DateTime.now();
      final base =
          'pos_backup_${now.year}_${_pad(now.month)}_${_pad(now.day)}'
          '_${_pad(now.hour)}${_pad(now.minute)}';

      final String finalName = compress ? '$base.zip' : '$base.db';
      final destPath = p.join(folder, finalName);
      final tempPath = '$destPath.tmp';

      // ── Raw snapshot via VACUUM INTO (or file-copy fallback) ──────────────
      final rawTempPath = '$destPath.raw_tmp';
      final ok = await DatabaseService.instance.vacuumInto(rawTempPath);
      if (!ok) await sourceFile.copy(rawTempPath);

      String current = rawTempPath;

      // ── Optional ZIP compression ──────────────────────────────────────────
      if (compress) {
        final sourceBytes = await File(current).readAsBytes();
        final archive = Archive()
          ..addFile(ArchiveFile('$base.db', sourceBytes.length, sourceBytes));
        final encoded = ZipEncoder().encode(archive);
        if (encoded == null) throw Exception('ZIP encoding failed.');
        await File(tempPath).writeAsBytes(encoded, flush: true);
        await _tryDelete(current);
        current = tempPath;
      } else {
        // Move the raw snapshot to the final temp name.
        try {
          await File(current).rename(tempPath);
        } catch (_) {
          await File(current).copy(tempPath);
          await _tryDelete(current);
        }
        current = tempPath;
      }

      // ── Move to final destination ─────────────────────────────────────────
      try {
        await File(current).rename(destPath);
      } catch (_) {
        await File(current).copy(destPath);
        await _tryDelete(current);
      }

      // ── Update config ─────────────────────────────────────────────────────
      final cfg = await _readConfig();
      cfg['lastBackupDate'] = _todayKey();
      await _saveConfig(cfg);

      await _pruneOldBackups(dir);
      return AutoBackupResult.success;
    } catch (_) {
      return AutoBackupResult.error;
    }
  }

  /// Keeps only the newest [_maxBackups] backup files in [dir].
  /// Matches files starting with `pos_backup_` with `.db` or `.zip` extension.
  Future<void> _pruneOldBackups(Directory dir) async {
    try {
      final files = <File>[];
      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.startsWith('pos_backup_') &&
              (name.endsWith('.db') || name.endsWith('.zip'))) {
            files.add(entity);
          }
        }
      }
      if (files.length <= _maxBackups) return;

      files.sort(
        (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
      );
      for (final f in files.sublist(0, files.length - _maxBackups)) {
        await f.delete();
      }
    } catch (_) {}
  }

  Future<void> _tryDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${_pad(n.month)}-${_pad(n.day)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

enum AutoBackupResult {
  success,
  alreadyBackedUpToday,
  noFolderConfigured,
  sourceNotFound,
  error,
}
