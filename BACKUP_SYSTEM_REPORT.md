# POS System — Database Backup & Restore: Change Report

**Date:** 2026-05-12  
**Branch:** main  
**Scope:** Additive only — no existing logic was modified, removed, or refactored.

---

## 1. Summary

A production-ready backup and restore layer was added to the Flutter POS system. It provides:

- Manual **Export** of the SQLite database to a user-chosen folder
- Manual **Restore** from a previously exported `.db` file
- **Automatic daily backup** with configurable destination and automatic pruning (keeps last 7)

All functionality is accessible through a new card inside the existing **Admin Settings** screen. No other screens, navigation flows, colors, layouts, or business logic were changed.

---

## 2. Files Changed

### 2.1 New Files (created from scratch)

#### `lib/services/backup_service.dart`
**Purpose:** Exports (copies) the live database to a safe destination.

**What it does:**
- Locates the active `pos_system.db` file via `getDatabasesPath()`
- On **Windows / macOS / Linux**: opens a native folder-picker dialog via `file_picker`
- On **Android**: saves to the app's external storage directory (visible in the device file manager)
- Generates a timestamped filename: `pos_backup_YYYY_MM_DD.db`
- Writes to a `.tmp` file first; renames atomically to the final filename
- If rename fails (different drives / cross-device), falls back to copy-then-delete
- The source database file is **never opened for writing** — it is only read via a file-system copy

**Key method:** `BackupService.instance.exportDatabase() → Future<String?>`  
Returns the full path of the created backup file, or `null` if the user cancelled.

---

#### `lib/services/restore_service.dart`
**Purpose:** Imports a backup file and safely replaces the live database.

**Restore flow (8 steps):**

| Step | Action |
|------|--------|
| 1 | Open OS file picker — user selects a `.db` file |
| 2 | Confirm the file exists and is larger than 100 bytes |
| 3 | Validate the first 16 bytes match SQLite's magic header `"SQLite format 3\0"` — rejects any non-SQLite file |
| 4 | Copy the selected file to a temporary path `pos_system.db.restore_tmp` — nothing destructive yet |
| 5 | Close the live database connection (`DatabaseService.closeDatabase()`) |
| 6 | Copy the live database to `pos_system.db.pre_restore_backup` — a permanent safety sidecar |
| 7 | Move the temp file into place as the new `pos_system.db` |
| 8 | Reopen the database, run any needed schema upgrades, call `onReloadData()` |

**Corruption prevention:**
- The live DB is never replaced until a valid, fully written temp copy exists
- The `.pre_restore_backup` sidecar is kept on disk after every restore
- If any error occurs after the DB connection is closed, the `finally` block attempts to reopen whatever file exists — the app cannot be left with no database
- A boolean lock (`isRestoring`) prevents two concurrent restore operations

**Key method:** `RestoreService.instance.restoreDatabase({onReloadData}) → Future<bool>`  
Returns `true` on success, `false` if the user cancelled the file picker. Throws on validation or I/O errors.

---

#### `lib/services/database_backup_manager.dart`
**Purpose:** Manages automatic daily backups.

**Configuration storage:**  
A small JSON file at `{applicationDocumentsDirectory}/pos_backup_config.json` stores:
- `autoBackupFolder` — the chosen backup destination path
- `lastBackupDate` — the date of the last successful auto-backup (`YYYY-MM-DD`)

This file lives **outside the main database** intentionally — it survives a database restore.

**Auto-backup policy:**
- Maximum one backup per calendar day (checked by comparing today's date to `lastBackupDate`)
- After each backup, files in the destination matching `pos_backup_*.db` are counted; if more than 7 exist, the oldest ones (by modification time) are deleted
- If no folder has been configured, `performAutoBackup()` defaults to `{documents}/POS_Backups/` and saves that as the configured folder

**Key methods:**
- `performAutoBackupIfNeeded()` — safe to call on every app open; returns early silently if not needed
- `performAutoBackup()` — forces an immediate backup
- `pickAndSetAutoBackupFolder()` — opens a folder picker and persists the choice
- `getAutoBackupFolder()` — returns the currently configured folder path or `null`

---

### 2.2 Modified Files (minimal additions only)

#### `lib/services/database_service.dart`
**Lines added:** ~20  
**What changed:** Two new public methods appended after the existing `database` getter.

```dart
// Closes the connection and nulls the cached instance.
Future<void> closeDatabase() async { ... }

// Re-opens the connection (triggers onUpgrade if schema changed).
Future<void> reopenDatabase() async { ... }
```

**Why:** The restore flow must close the database file handle before replacing the file on disk. Without closing, the OS (especially Windows) will refuse to overwrite a file that is held open by another process.

**What was NOT changed:** All existing CRUD methods, `_initDB`, `_onCreate`, `_onUpgrade`, table definitions, seeding logic — untouched.

---

#### `lib/manager/manager_data.dart`
**Lines added:** ~6  
**What changed:** One new public method inserted before `_reloadMenu`.

```dart
Future<void> reload() async {
  await _init();
}
```

**Why:** After a restore, all in-memory caches (`_waiters`, `_categories`, `_cashierTables`, etc.) reflect the old database. Calling `reload()` re-runs the full `_init()` load sequence against the newly restored database, then calls `notifyListeners()` so every listening widget rebuilds.

**What was NOT changed:** The `_init()` method itself, all mutation methods, the singleton pattern, `ChangeNotifier` subscription logic — untouched.

---

#### `lib/screens/admin_settings_screen.dart`
**Lines added:** ~250 (new card widget + methods)  
**Lines changed:** ~10 (imports, `initState`, inserting the card into the column)

**What changed:**

1. **Imports** — added `backup_service.dart`, `restore_service.dart`, `database_backup_manager.dart`, `login_screen.dart`, `waiter_selection_screen.dart`

2. **State variables** (added to `_AdminSettingsScreenState`):
   - `bool _isBackupOperation` — disables all backup buttons during an active operation
   - `String? _autoBackupFolder` — displayed in the UI so the admin can see the configured path

3. **`initState`** — two new calls added:
   - `_loadBackupInfo()` — reads and displays the configured backup folder on screen open
   - `_triggerAutoBackup()` — silently creates today's backup if it has not been done yet

4. **New private methods:**

   | Method | Behaviour |
   |--------|-----------|
   | `_loadBackupInfo()` | Reads `autoBackupFolder` from config and puts it in state |
   | `_triggerAutoBackup()` | Fire-and-forget call to `performAutoBackupIfNeeded()` |
   | `_exportDatabase()` | Calls `BackupService.exportDatabase()`, shows success/error snackbar |
   | `_restoreDatabase()` | Shows confirmation dialog → calls `RestoreService.restoreDatabase()` → on success navigates to login screen with cleared nav stack |
   | `_createBackupNow()` | Calls `DatabaseBackupManager.performAutoBackup()`, updates folder display |
   | `_configureBackupFolder()` | Calls `pickAndSetAutoBackupFolder()`, updates folder display |
   | `_buildBackupCard()` | Builds the new UI card (see below) |

5. **New UI card** — inserted between the Login Mode card and the Printers card:
   - Title: "Database Backup" — same `TextStyle` as existing card titles
   - **Export Database** button — green `OutlinedButton.icon` with download icon
   - **Restore Database** button — red `OutlinedButton.icon` with restore icon
   - Inline progress indicator row shown while `_isBackupOperation == true`
   - **Auto-Backup** section with folder path display, "Set Backup Folder" / "Change Folder" button, "Backup Now" button
   - All colors are from `AppColors` — same as the rest of the screen

**What was NOT changed:** Login Mode card, Printers card, `_buildModeOption`, `_changeMode`, `_savePrinter`, `_loadPrinters` — untouched.

---

## 3. Dependencies

No new packages were added. All functionality uses packages already present in `pubspec.yaml`:

| Package | Used for |
|---------|----------|
| `file_picker ^6.1.1` | Folder picker (export) and file picker (restore) |
| `path_provider ^2.1.4` | Locating the DB directory and documents directory |
| `path ^1.9.0` | Safe path joining across platforms |
| `sqflite / sqflite_common_ffi` | `getDatabasesPath()` — same call used by `DatabaseService` |
| `dart:io` | File copy, rename, delete |
| `dart:convert` | JSON encode/decode for the config file |

---

## 4. How to Test

### 4.1 Export Database (Manual)

1. Open the app and log in as admin.
2. Navigate to **Admin Settings**.
3. In the **Database Backup** card, tap **Export Database**.
4. On Windows/macOS: a folder picker dialog appears — select any folder.
5. On Android: no picker appears (saves automatically).
6. A green snackbar shows the full path of the created file.
7. Navigate to that path in your file manager and confirm the file exists and is named `pos_backup_YYYY_MM_DD.db`.
8. Optionally open the file in DB Browser for SQLite and verify the tables are intact.

**Cancel test:** Tap "Export Database", then cancel the folder picker → no snackbar, no file created.

**Error test:** Make the source DB unreadable (rename it in the file manager while the app is open) → red snackbar with error message.

---

### 4.2 Restore Database (Manual)

> **Prerequisite:** You need a valid `.db` backup file from step 4.1.

1. Make some visible change in the app (add a waiter, add an expense).
2. Open **Admin Settings** → **Restore Database**.
3. A confirmation dialog appears — tap **Restore**.
4. The file picker opens — select your backup `.db` file.
5. The app navigates back to the Login Screen automatically.
6. Log back in and confirm the change you made in step 1 is gone (the old data is back).

**Cancel test (dialog):** Tap "Restore Database" → tap **Cancel** in the dialog → nothing happens.

**Cancel test (picker):** Tap "Restore Database" → confirm → cancel the file picker → nothing happens.

**Invalid file test:** Select a `.jpg` or `.txt` file → red snackbar: "The selected file is not a valid SQLite database."

**Small file test:** Select an empty file → red snackbar: "too small".

---

### 4.3 Auto-Backup

1. Open **Admin Settings**.
2. In the **Auto-Backup** section, tap **Set Backup Folder** and choose a folder.
3. The chosen path appears in the green info box.
4. Tap **Backup Now**.
5. A green snackbar confirms the backup was created in the chosen folder.
6. Navigate to that folder — confirm a file named `pos_backup_YYYY_MM_DD_HHmm.db` exists.
7. Close and reopen Admin Settings — the same folder is remembered.

**Pruning test:** Tap "Backup Now" 8 times (each will create a file with a slightly different minute timestamp). Check the folder — only the newest 7 files remain.

**Daily deduplication test:** Tap "Backup Now" twice in the same minute, then check Admin Settings again — the second call via `performAutoBackupIfNeeded()` returns `alreadyBackedUpToday` silently, no duplicate file.

**Change folder test:** Tap "Change Folder", pick a different folder, then "Backup Now" — new backup goes to the new folder.

---

### 4.4 Schema Upgrade on Restore (Edge Case)

1. If you have a backup from an older version of the app (e.g., schema version 5), restore it.
2. After the restore, sqflite's `onUpgrade` fires automatically when the DB is reopened.
3. The app should start normally with all missing tables created and singleton rows inserted.
4. Verify in the app that all screens load without errors.

---

### 4.5 Safety Sidecar Verification

After any restore:

1. Navigate to the database directory:
   - **Windows:** `%APPDATA%\{company}\{app}\databases\`
   - **Android:** `/data/data/com.example.pos_system/databases/`
2. Confirm that `pos_system.db.pre_restore_backup` exists alongside `pos_system.db`.
3. This file is the database that was live immediately before the restore — it can be manually renamed back to `pos_system.db` if a restore needs to be undone.

---

## 5. Potential Edge Cases and How They Are Handled

| Scenario | Handling |
|----------|----------|
| User taps Export twice quickly | Second tap is blocked while `_isBackupOperation == true` |
| User taps Restore twice quickly | `isRestoring` lock in `RestoreService` throws an exception |
| Export to full disk | `safelyCopy` throws; temp file is deleted; red snackbar shown |
| Restore of same-version backup | No upgrade needed; DB opens normally |
| Restore of older-version backup | sqflite `onUpgrade` runs, missing tables and columns are created |
| Restore fails mid-way (power cut) | `.pre_restore_backup` sidecar always exists; `finally` block tries to reopen |
| Auto-backup folder deleted externally | `_runBackup` calls `dir.create(recursive: true)` to recreate it |
| Config file corrupted | `_readConfig` returns `{}` on any JSON parse error; no crash |
| Android external storage unavailable | Falls back to `getApplicationDocumentsDirectory()` |

---

## 6. Files NOT Changed

The following files were not touched at all:

- `lib/main.dart`
- `lib/models/mock_data.dart`
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
- `lib/theme/app_colors.dart`
- `lib/theme/pos_grid.dart`
- `lib/widgets/`
- `lib/utils/`
- `pubspec.yaml`
- `android/`, `windows/`, `macos/`, `ios/`
