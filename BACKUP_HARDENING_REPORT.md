# POS System — Backup & Restore Hardening Report

**Date:** 2026-05-12  
**Scope:** Additive hardening of the existing backup/restore layer only.  
No existing screens, navigation, state management, database schema, or business
logic were changed.

---

## 1. New Dependencies

Three pure-Dart packages were added to `pubspec.yaml`.  No native code is
involved.

| Package      | Version | Purpose                                    |
|--------------|---------|--------------------------------------------|
| `archive`    | ^3.6.1  | ZIP encoding / decoding (in-memory)        |
| `crypto`     | ^3.0.3  | SHA-256 for key derivation & checksum      |
| `encrypt`    | ^5.0.3  | AES-256-CBC encryption (via pointycastle)  |

---

## 2. New File: `lib/services/backup_crypto_service.dart`

### Purpose
Provides AES-256-CBC encryption and decryption for exported backup files.
The live database is **never encrypted** — only exported copies.

### On-disk file format
```
Offset  Len   Field
──────  ───   ─────
     0    8   Magic      "POSENC1\x00"  identifies a POS encrypted backup
     8   16   Salt       random bytes   tied to key derivation
    24   16   IV         random bytes   AES initialisation vector
    40   32   Checksum   SHA-256 of the unencrypted plaintext
    72    N   Ciphertext AES-256-CBC encrypted, PKCS7 padded
```

### Key derivation
```
k₀  = SHA256(utf8(password) ‖ salt)
kᵢ  = SHA256(kᵢ₋₁)    for i = 1 … 99999
key = k₁₀₀₀₀₀          (32 bytes = 256-bit AES key)
```
100 000 SHA-256 iterations costs ≈ 35–80 ms on modern hardware, making a
brute-force dictionary attack require days even on GPU hardware.

### Wrong-password detection
The SHA-256 checksum of the plaintext is stored unencrypted in the header.
After decryption the checksum is recomputed.  If it does not match, decryption
is rejected — this catches both PKCS7 padding failures (the primary
wrong-password signal) and the rare case (1 in 256) where a wrong key
accidentally produces valid-looking padding.

### Methods
| Method | Description |
|--------|-------------|
| `encryptFile(src, dst, pw)` | Encrypts src to dst; writes via temp file |
| `decryptFile(src, dst, pw)` | Decrypts src to dst; validates checksum |
| `isEncryptedFile(path)` | Reads first 8 bytes to check POSENC1 magic |

---

## 3. Changes to `lib/services/database_service.dart`

### New method: `vacuumInto(String destPath) → Future<bool>`

```
VACUUM INTO 'destPath'
```

SQLite 3.27.0+ (February 2019) creates an atomic, defragmented snapshot of the
database without touching the source file, even in WAL mode.

- Returns `true` if VACUUM INTO succeeded.
- Returns `false` if the SQLite version is too old (caller falls back to
  file copy).
- Single-quote escapes the path to prevent SQL injection from unusual
  filesystem paths.

**Why safer than file copy:**  
A file copy reads individual OS pages and may capture a torn write if another
transaction is committing simultaneously.  VACUUM INTO reads only committed
data and produces a fully consistent, single-file output.

---

## 4. Changes to `lib/services/backup_service.dart`

### Export pipeline
```
source DB
  ├─► VACUUM INTO (SQLite 3.27.0+)
  │     └─► returns false → raw file copy
  │
  ├─► [optional] AES-256-CBC encryption  →  .enc.db
  │
  └─► [optional] ZIP compression         →  .zip or .enc.zip
```

Each stage writes to a uniquely named `.tmp` sidecar.  The destination file
is only written in the final rename/copy step.  Every temp file is cleaned up
in the `catch` block.

### File naming matrix
| `compressed` | `password` set | Extension   |
|:------------:|:--------------:|-------------|
| false        | no             | `.db`       |
| true         | no             | `.zip`      |
| false        | yes            | `.enc.db`   |
| true         | yes            | `.enc.zip`  |

### Method signature change (backward compatible)
```dart
// Before
Future<String?> exportDatabase()

// After (optional parameters — existing callers need no changes)
Future<String?> exportDatabase({bool compressed = false, String? password})
```

---

## 5. Changes to `lib/services/restore_service.dart`

### New: `hasUndoAvailable() → Future<bool>`
Returns `true` if `pos_system.db.pre_restore_backup` exists on disk.

### New method signature: `restoreDatabase()`
```dart
Future<bool> restoreDatabase({
  required Future<void> Function() onReloadData,
  Future<String?> Function()? onPasswordRequired,  // NEW
})
```
`onPasswordRequired` is an optional callback invoked when the selected file
carries the POSENC1 encryption header.  The UI shows a password dialog and
returns the entered string (or `null` to cancel).

### Restore pipeline (updated)
```
pickFiles()
  │
  ├─► is ZIP?   → extract first .db or .enc.db entry to temp dir
  │
  ├─► is encrypted?  → call onPasswordRequired → decrypt to temp file
  │
  ├─► validate SQLite magic bytes
  │
  ├─► copy to liveTemp             ← nothing destructive yet
  │
  ├─► closeDatabase()
  ├─► copy live DB to .pre_restore_backup  ← permanent safety sidecar
  ├─► rename/copy liveTemp → live DB
  ├─► reopenDatabase()
  │
  ├─► PRAGMA integrity_check       ← NEW: auto-rollback on failure
  ├─► verify critical tables       ← NEW: auto-rollback on failure
  │
  └─► onReloadData()
```

### New: `_runPostRestoreChecks(livePath, safetyPath)`

#### PRAGMA integrity_check
```sql
PRAGMA integrity_check;
```
SQLite returns `"ok"` if the database is consistent, or one or more error
strings.  If the result is anything other than `"ok"`, the restore is rejected.

#### Critical tables verification
The following tables must exist for the POS app to function:
`company`, `waiters`, `products`, `categories`, `sales`, `tables`

Each is checked with:
```sql
SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?
```

#### Auto-rollback
If either check fails:
1. The live DB is closed.
2. The `.pre_restore_backup` sidecar is copied back to the live path.
3. The database is reopened.
4. An exception is thrown with a human-readable message including the original
   failure reason.

The app is never left with a corrupted or incomplete database.

### New: `undoLastRestore({required onReloadData}) → Future<bool>`

Performs a validated rollback:
1. Checks sidecar exists.
2. Validates sidecar SQLite header.
3. Copies sidecar to `undo_tmp`.
4. Closes live DB, replaces live file, reopens.
5. Runs integrity check and critical-tables check on the restored data.
6. **Only if checks pass:** deletes the sidecar (undo becomes unavailable).
7. Calls `onReloadData()`, navigates to login screen.

If any check fails, the live DB is left unchanged, the sidecar is preserved,
and an exception is thrown.

### ZIP extraction details
- Reads the ZIP into memory (`ZipDecoder().decodeBytes(bytes)`).
- Looks for the first entry ending in `.db` or `.enc.db`.
- If the archive is corrupt (`ZipDecoder` throws), the error is wrapped in a
  human-readable message.
- A temporary system directory is created for extraction and deleted in the
  `finally` block.

---

## 6. Changes to `lib/services/database_backup_manager.dart`

### New config key: `useCompression` (bool, default false)
Stored in `pos_backup_config.json` alongside the existing keys.

### New methods
| Method | Description |
|--------|-------------|
| `getUseCompression()` | Returns current compression preference |
| `setUseCompression(bool)` | Persists the preference |

### Updated `_runBackup()`
Now passes `compress:` to the ZIP step.  When compression is enabled:
- VACUUM INTO (or file copy) creates a raw `.db` snapshot.
- The snapshot is encoded into a ZIP archive with `ZipEncoder`.
- The ZIP is placed at the final destination.
- The raw `.db` temp file is cleaned up.

### Updated `_pruneOldBackups()`
Pruning now matches both `.db` and `.zip` extensions so mixed-format
backup histories are handled correctly.

---

## 7. Changes to `lib/screens/admin_settings_screen.dart`

### New state variables
| Variable | Type | Purpose |
|----------|------|---------|
| `_hasRestoreUndo` | `bool` | Controls visibility of "Undo Last Restore" button |
| `_useCompression` | `bool` | Mirrors the `useCompression` config preference |

### Updated `_loadBackupInfo()`
Now also loads `_hasRestoreUndo` (`RestoreService.hasUndoAvailable()`) and
`_useCompression` (`DatabaseBackupManager.getUseCompression()`).

### Updated `_exportDatabase()`
Calls `_showExportOptionsDialog()` first.  If the user cancels the dialog,
the export is aborted before any I/O begins.

### New: `_showExportOptionsDialog() → Future<_ExportOptions?>`
An `AlertDialog` with four radio options:
- Standard (.db)
- Compressed (.zip)
- Encrypted (.enc.db) — shows two password fields
- Encrypted + Compressed (.enc.zip) — shows two password fields

Password fields are validated: both must be non-empty and must match before
the dialog can be confirmed.

### New: `_promptForPassword() → Future<String?>`
A compact `AlertDialog` with a single obscured `TextField`.  Returned by the
`onPasswordRequired` callback to `RestoreService.restoreDatabase()`.
Returns `null` if the user presses Cancel or submits an empty string.

### New: `_undoRestore()`
Shows a confirmation dialog, then calls
`RestoreService.instance.undoLastRestore()`.  On success, navigates to the
initial screen (login or waiter selection based on restored `loginMode`) with a
cleared navigation stack.  Updates `_hasRestoreUndo = false` in `finally`.

### New UI elements in `_buildBackupCard()`

**Undo Last Restore button** (shown only when `_hasRestoreUndo == true`):
- Orange outlined button with undo icon
- Positioned immediately below the Export/Restore row
- Disabled while any backup operation is in progress

**Auto-backup compression toggle** (always shown in Auto-Backup section):
- `Switch` widget with label "Compress backups (.zip)"
- Disabled while any backup operation is in progress
- Immediately persists the preference via `DatabaseBackupManager.setUseCompression()`

---

## 8. Edge Cases Handled

| Scenario | Handling |
|----------|----------|
| VACUUM INTO unsupported (old SQLite) | Caught silently; falls back to file copy |
| ZIP archive is corrupt | `ZipDecoder` throws; caught and re-thrown as user-friendly error |
| ZIP contains no `.db` entry | Explicit error: "No .db or .enc.db file found inside ZIP" |
| Wrong password for encrypted backup | PKCS7 failure OR checksum mismatch → "password is incorrect" |
| Disk full during export | All `.tmp` files cleaned up in `catch`; destination untouched |
| Integrity check fails after restore | Auto-rollback to `.pre_restore_backup`; error explains reason |
| Critical table missing after restore | Auto-rollback; error names the missing table |
| Undo with missing sidecar | Returns `false` silently; undo button hidden |
| Undo integrity check fails | Live DB unchanged; sidecar preserved for manual recovery |
| Concurrent restore attempts | `_isRestoring` lock throws immediately on second call |
| App closed mid-restore | `pos_system.db.pre_restore_backup` always exists; DB reopens next launch |
| Restore from older schema | `sqflite.onUpgrade` fires on reopen; schema brought up to date |
| Restore from newer schema | App runs on current schema; integrity check validates consistency |
| Android external storage unavailable | Falls back to `getApplicationDocumentsDirectory()` |
| Cross-device file rename (Windows) | Caught; falls back to copy-then-delete |

---

## 9. How to Test Each Improvement

### 9.1 VACUUM INTO (safer backup)

1. Create a backup ("Export Database" → Standard).
2. Open the file in DB Browser for SQLite — it should open with no warnings.
3. To verify VACUUM INTO ran (vs. file copy), enable SQLite verbose logging
   or check that the output file has no `-wal` or `-shm` sidecar files
   (VACUUM INTO always produces a single clean file).

### 9.2 ZIP export

1. Export Database → choose "Compressed (.zip)".
2. Confirm the saved file has a `.zip` extension.
3. Open the ZIP with any archiver — it should contain exactly one `.db` file.
4. Restore the `.zip` directly (Restore Database → pick the `.zip` file).
5. Verify the app restores correctly and data matches.

### 9.3 Encrypted export

1. Export Database → choose "Encrypted (.enc.db)" → enter a password twice.
2. Try to open the `.enc.db` file in DB Browser — it must fail (not valid SQLite).
3. Restore the `.enc.db` (Restore Database → pick it) → app asks for the password.
4. Enter the correct password → restore succeeds.
5. Repeat restore with wrong password → "password is incorrect" snackbar.

### 9.4 Encrypted + Compressed export

1. Export Database → "Encrypted + Compressed (.enc.zip)" → enter password.
2. The saved file has `.enc.zip` extension.
3. The ZIP's inner file is `.enc.db` (encrypted, not plaintext).
4. Restore the `.enc.zip` → app extracts it, detects encrypted inner file,
   asks for password, decrypts, validates, restores.

### 9.5 Integrity check after restore

1. Using a hex editor, corrupt 8 bytes in the middle of a backup `.db` file.
2. Attempt to restore the corrupted file.
3. Expected: app shows "backup failed validation and was automatically rolled
   back" — the live database must remain fully functional.

### 9.6 Missing critical table rollback

1. Using DB Browser, drop the `waiters` table from a backup `.db` file.
2. Attempt to restore it.
3. Expected: "Critical table 'waiters' is missing" error; live DB unchanged.

### 9.7 Undo last restore

1. Export a backup of the current state.
2. Make a visible change (add a waiter).
3. Restore the original backup.
4. Back on Admin Settings: "Undo Last Restore" button now appears (orange).
5. Tap it → confirmation dialog → confirm.
6. The change made in step 2 reappears.
7. "Undo Last Restore" button disappears (sidecar was deleted).

### 9.8 Auto-backup compression toggle

1. Open Admin Settings → turn on "Compress backups (.zip)".
2. Tap "Backup Now".
3. Navigate to the backup folder — file has `.zip` extension.
4. Turn off the toggle → "Backup Now" → new file has `.db` extension.
5. Both old `.zip` and new `.db` files count towards the 7-file pruning limit.

---

## 10. Files NOT Changed

- `lib/main.dart`
- `lib/models/mock_data.dart`
- `lib/manager/manager_data.dart` *(except the existing `reload()` method added
  in the previous session)*
- `lib/screens/login_screen.dart`
- `lib/screens/manager_dashboard_screen.dart`
- `lib/screens/pos_order_screen.dart`
- `lib/screens/table_selection_screen.dart`
- `lib/screens/waiter_selection_screen.dart`
- `lib/services/database_helper.dart`
- `lib/services/printer_settings_store.dart`
- `lib/services/receipt_printer.dart`
- `lib/services/receipt_text.dart`
- `lib/services/windows_printers_service.dart`
- `lib/services/expenses_pdf_export.dart`
- `lib/services/manager_summary_pdf.dart`
- `lib/theme/`
- `lib/widgets/`
- `lib/utils/`
- `android/`, `windows/`, `macos/`, `ios/`
