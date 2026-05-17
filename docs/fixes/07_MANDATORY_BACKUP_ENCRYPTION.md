# Fix 07 — Mandatory Backup Encryption

## Problem

The backup export flow in `BackupService.exportDatabase()` accepted `password: null`,
which allowed backups to be saved as unencrypted `.db` or `.zip` files.  A stolen,
misplaced, or mis-synced backup file would expose the full POS database — customers,
sales, waiter PINs (hashed but recoverable offline) — with no protection whatsoever.

Auto-backups via `DatabaseBackupManager` also had no encryption support and produced
plaintext `.db`/`.zip` files regardless of settings.

## Risk

| Threat | Impact before fix |
|---|---|
| Backup file copied to USB / cloud | Full plaintext database readable by anyone |
| Old backup found on shared drive | No way to know if it was ever encrypted |
| Auto-backup to network share | All scheduled backups readable by share members |

## Files Changed

| File | Change type |
|---|---|
| `lib/services/backup_service.dart` | Mandatory encryption guard, removed plaintext paths |
| `lib/services/database_backup_manager.dart` | Password config, always-encrypt in auto-backup |
| `lib/services/restore_service.dart` | `onPlaintextWarning` callback for legacy backups |
| `lib/services/audit_log_service.dart` | Added `backupRestoreAttempt` action + helper |
| `lib/screens/admin_settings_screen.dart` | UI: password-only export dialog, auto-backup password UI, plaintext restore warning |

## Exact Changes

### `lib/services/backup_service.dart`

**Before:** `password` was optional; plaintext export was allowed when `password == null`.

**After:**
- Guard added at the top of `exportDatabase()`:
  ```dart
  if (password == null || password.length < 8) {
    throw Exception('A backup password of at least 8 characters is required.');
  }
  ```
- Extension logic simplified — always `.enc.db` or `.enc.zip`:
  ```dart
  final String outerExt = compressed ? '.enc.zip' : '.enc.db';
  final String innerExt = compressed ? '.enc.db' : '';
  ```
- Encryption step is now unconditional (no `if (encrypted)` wrapper):
  ```dart
  await BackupCryptoService.instance.encryptFile(current, encTemp, password);
  ```
- Removed the `password != null` branch and all plaintext output paths.

### `lib/services/database_backup_manager.dart`

- Added `noPasswordConfigured` to `AutoBackupResult` enum.
- Added config helpers:
  ```dart
  Future<String?> getAutoBackupPassword()
  Future<bool>    hasAutoBackupPassword()
  Future<void>    setAutoBackupPassword(String password)
  ```
- `performAutoBackupIfNeeded()` and `performAutoBackup()` return
  `AutoBackupResult.noPasswordConfigured` if no password is stored.
- `_runBackup()` now takes `required String password` and always calls
  `BackupCryptoService.instance.encryptFile()`.
- File naming in `_runBackup()` changed: `$base.enc.db` / `$base.enc.zip`.
- `_pruneOldBackups()` now also matches `.enc.db` and `.enc.zip` extensions.

### `lib/services/restore_service.dart`

- Added optional callback `Future<bool> Function()? onPlaintextWarning` to
  `restoreDatabase()`.
- After the decryption block, if the file is not encrypted:
  ```dart
  } else if (onPlaintextWarning != null) {
    final proceed = await onPlaintextWarning();
    if (!proceed) return false;
  }
  ```
  The restore aborts cleanly if the user declines.

### `lib/services/audit_log_service.dart`

- Added action constant `backupRestoreAttempt = 'backup_restore_attempt'`.
- Added helper:
  ```dart
  void logBackupRestoreAttempt() => log(
    actionType: AuditAction.backupRestoreAttempt, entityType: 'backup',
    performedBy: 'manager', performedRole: 'manager',
  );
  ```

### `lib/screens/admin_settings_screen.dart`

- `_showExportOptionsDialog()` rewritten: only two options (`.enc.db` and
  `.enc.zip`), password fields always shown, 8-character minimum enforced,
  match validation, inline `errorMsg` via `StatefulBuilder`.
- `_restoreDatabase()`: calls `logBackupRestoreAttempt()` before the try block;
  passes `onPlaintextWarning: _warnUnencryptedBackup` to `RestoreService`.
- New `_warnUnencryptedBackup()`: shows a modal warning dialog, returns `bool`.
- New `_setAutoBackupPassword()`: dialog to set/change the auto-backup password
  with 8-char minimum and match validation.
- Auto-backup section: password status row added (lock icon, status text,
  Set/Change Password button).
- `_createBackupNow()` switch: handles `AutoBackupResult.noPasswordConfigured`.

## Backup Behaviour After Fix

| Action | Result |
|---|---|
| Export without password | Exception thrown, no file written |
| Export with password < 8 chars | Exception thrown, no file written |
| Export with valid password (uncompressed) | `pos_backup_YYYY_MM_DD.enc.db` |
| Export with valid password (compressed) | `pos_backup_YYYY_MM_DD.enc.zip` |
| Auto-backup, no password configured | Returns `noPasswordConfigured`, no file |
| Auto-backup, password set | `pos_backup_YYYY_MM_DD_HHMM.enc.db` / `.enc.zip` |
| Restore `.enc.db` or `.enc.zip` | Password prompt, normal pipeline |
| Restore old plaintext `.db` | Warning dialog; user can abort or proceed |

## What Was Not Changed

- `BackupCryptoService` (AES-256-CBC, POSENC1 header) — unchanged.
- Restore pipeline steps 1–12 — unchanged; only the plaintext warning hook added.
- Database schema — unchanged.
- PIN / auth logic — unchanged.
- Any screen other than `admin_settings_screen.dart` — unchanged.

## Manual Test Checklist

- [ ] Open Admin Settings → Backup → Export; confirm only encrypted options shown.
- [ ] Try exporting with no password → see error message.
- [ ] Try exporting with 7-character password → see error message.
- [ ] Export with valid password (uncompressed) → file saved as `.enc.db`.
- [ ] Export with valid password (compressed) → file saved as `.enc.zip`.
- [ ] Restore the `.enc.db` with correct password → success, data intact.
- [ ] Restore the `.enc.db` with wrong password → clear error, DB unchanged.
- [ ] Restore an old plaintext `.db` file → warning dialog appears; decline aborts.
- [ ] Set auto-backup password in settings → lock icon changes to set status.
- [ ] Trigger auto-backup with no password configured → snackbar "Set an encryption password...".
- [ ] Trigger auto-backup with password set → file created with `.enc.db`/`.enc.zip`.
- [ ] Confirm no password string appears in audit log entries.
- [ ] Run `flutter analyze` → exactly 78 issues.

## Next Step

Add session timeout / re-authentication: automatically lock the admin session after
a configurable idle period and require the admin PIN to resume.
