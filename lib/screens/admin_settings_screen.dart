import 'package:flutter/material.dart';

import '../manager/manager_data.dart';
import '../services/backup_service.dart';
import '../services/database_backup_manager.dart';
import '../services/printer_settings_store.dart';
import '../services/restore_service.dart';
import '../services/windows_printers_service.dart';
import 'login_screen.dart';
import 'waiter_selection_screen.dart';
import '../theme/app_colors.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final ManagerData _m = ManagerData.instance;
  late String _selectedMode;

  List<String> _printers = const [];
  String _selectedPrinter = '';
  bool _loadingPrinters = true;

  // ── Backup state ──────────────────────────────────────────────────────────
  bool _isBackupOperation = false;
  String? _autoBackupFolder;
  bool _hasRestoreUndo = false;
  bool _useCompression = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = _m.loginMode;
    _m.addListener(_onDataChanged);
    _loadPrinters();
    _loadBackupInfo();
    _triggerAutoBackup();
  }

  @override
  void dispose() {
    _m.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    setState(() {
      _selectedMode = _m.loginMode;
    });
  }

  Future<void> _loadPrinters() async {
    setState(() => _loadingPrinters = true);
    final selected = await PrinterSettingsStore.loadSelectedPrinterName();
    final printers = await WindowsPrintersService.listInstalledPrinters();
    if (!mounted) return;
    setState(() {
      _printers = printers;
      _selectedPrinter = selected;
      _loadingPrinters = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        title: const Text('Admin Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              color: AppColors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Login Mode',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select how waiters log in to the system',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildModeOption(
                      mode: 'PINMODE',
                      title: 'PIN Mode',
                      description:
                          'Waiters enter their PIN to access their tables',
                      isSelected: _selectedMode == 'PINMODE',
                      onTap: () => _changeMode('PINMODE'),
                    ),
                    const SizedBox(height: 16),
                    _buildModeOption(
                      mode: 'NAMEMODE',
                      title: 'Name Mode',
                      description: 'Waiters select their name from a list',
                      isSelected: _selectedMode == 'NAMEMODE',
                      onTap: () => _changeMode('NAMEMODE'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildBackupCard(),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              color: AppColors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Printers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select the Windows printer used for POS80 receipts.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loadingPrinters)
                      const CircularProgressIndicator()
                    else if (_printers.isEmpty)
                      const Text(
                        'No Windows printers found.',
                        style: TextStyle(color: AppColors.lightGreenText),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _printers.contains(_selectedPrinter)
                            ? _selectedPrinter
                            : null,
                        items: _printers
                            .map(
                              (name) => DropdownMenuItem<String>(
                                value: name,
                                child: Text(name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          _savePrinter(v);
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Windows Printer',
                        ),
                      ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _loadPrinters,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Printers'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required String mode,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.primaryGreen,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? AppColors.beige : AppColors.white,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: mode,
              groupValue: _selectedMode,
              onChanged: (_) => onTap(),
              activeColor: AppColors.primaryGreen,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primaryGreen,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  // ── Backup card ───────────────────────────────────────────────────────────

  Widget _buildBackupCard() {
    return Card(
      elevation: 2,
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Database Backup',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Export the database to a file or restore from a previous backup.',
              style: TextStyle(fontSize: 14, color: AppColors.darkGreenText),
            ),
            const SizedBox(height: 24),

            // Export row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isBackupOperation ? null : _exportDatabase,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export Database'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isBackupOperation ? null : _restoreDatabase,
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('Restore Database'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.negativeText,
                      side: BorderSide(color: AppColors.negativeText),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            if (_isBackupOperation) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Operation in progress…',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ],

            // ── Undo last restore (only shown when sidecar exists) ───────────
            if (_hasRestoreUndo) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isBackupOperation ? null : _undoRestore,
                icon: const Icon(Icons.undo_outlined, size: 18),
                label: const Text('Undo Last Restore'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE65100),
                  side: const BorderSide(color: Color(0xFFE65100)),
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // Auto-backup section
            const Text(
              'Auto-Backup',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Creates one backup per day automatically. Keeps the last 7 backups.',
              style: TextStyle(fontSize: 13, color: AppColors.darkGreenText),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Switch(
                  value: _useCompression,
                  onChanged: _isBackupOperation
                      ? null
                      : (v) async {
                          setState(() => _useCompression = v);
                          await DatabaseBackupManager.instance
                              .setUseCompression(v);
                        },
                  activeThumbColor: AppColors.primaryGreen,
                  activeTrackColor: AppColors.lightGreenBg,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Compress backups (.zip)',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.darkGreenText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (_autoBackupFolder != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _autoBackupFolder!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.darkGreenText,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            Row(
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _isBackupOperation ? null : _configureBackupFolder,
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: Text(
                    _autoBackupFolder == null
                        ? 'Set Backup Folder'
                        : 'Change Folder',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed:
                      _isBackupOperation ? null : _createBackupNow,
                  icon: const Icon(Icons.backup_outlined, size: 18),
                  label: const Text('Backup Now'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadBackupInfo() async {
    final folder = await DatabaseBackupManager.instance.getAutoBackupFolder();
    final hasUndo = await RestoreService.instance.hasUndoAvailable();
    final compress = await DatabaseBackupManager.instance.getUseCompression();
    if (!mounted) return;
    setState(() {
      _autoBackupFolder = folder;
      _hasRestoreUndo = hasUndo;
      _useCompression = compress;
    });
  }

  Future<void> _triggerAutoBackup() async {
    await DatabaseBackupManager.instance.performAutoBackupIfNeeded();
  }

  Future<void> _exportDatabase() async {
    // Show export options — user picks format and optional password.
    final opts = await _showExportOptionsDialog();
    if (opts == null) return; // user cancelled the dialog

    setState(() => _isBackupOperation = true);
    try {
      final path = await BackupService.instance.exportDatabase(
        compressed: opts.compressed,
        password: opts.password,
      );
      if (!mounted) return;
      if (path == null) return; // user cancelled folder picker
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup saved to:\n$path'),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.negativeText,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBackupOperation = false);
    }
  }

  /// Shows a dialog letting the admin choose export format and optional
  /// password encryption.  Returns null if cancelled.
  Future<_ExportOptions?> _showExportOptionsDialog() async {
    int selectedFormat = 0; // 0=plain, 1=zip, 2=encrypted, 3=enc+zip
    final pwCtrl = TextEditingController();
    final pwConfirmCtrl = TextEditingController();

    final result = await showDialog<_ExportOptions>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isEncrypted = selectedFormat >= 2;
            return AlertDialog(
              title: const Text(
                'Export Options',
                style: TextStyle(color: AppColors.darkGreenText),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Format',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _dialogRadio(
                      ctx: ctx,
                      setState: setDialogState,
                      label: 'Standard (.db)',
                      value: 0,
                      groupValue: selectedFormat,
                      onChanged: (v) => selectedFormat = v!,
                    ),
                    _dialogRadio(
                      ctx: ctx,
                      setState: setDialogState,
                      label: 'Compressed (.zip)',
                      value: 1,
                      groupValue: selectedFormat,
                      onChanged: (v) => selectedFormat = v!,
                    ),
                    _dialogRadio(
                      ctx: ctx,
                      setState: setDialogState,
                      label: 'Encrypted (.enc.db)',
                      value: 2,
                      groupValue: selectedFormat,
                      onChanged: (v) => selectedFormat = v!,
                    ),
                    _dialogRadio(
                      ctx: ctx,
                      setState: setDialogState,
                      label: 'Encrypted + Compressed (.enc.zip)',
                      value: 3,
                      groupValue: selectedFormat,
                      onChanged: (v) => selectedFormat = v!,
                    ),
                    if (isEncrypted) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: pwCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: pwConfirmCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    pwCtrl.dispose();
                    pwConfirmCtrl.dispose();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: () {
                    if (isEncrypted) {
                      if (pwCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a password.'),
                          ),
                        );
                        return;
                      }
                      if (pwCtrl.text != pwConfirmCtrl.text) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match.'),
                          ),
                        );
                        return;
                      }
                    }
                    final opts = _ExportOptions(
                      compressed: selectedFormat == 1 || selectedFormat == 3,
                      password: isEncrypted ? pwCtrl.text : null,
                    );
                    pwCtrl.dispose();
                    pwConfirmCtrl.dispose();
                    Navigator.pop(ctx, opts);
                  },
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  Widget _dialogRadio({
    required BuildContext ctx,
    required StateSetter setState,
    required String label,
    required int value,
    required int groupValue,
    required void Function(int?) onChanged,
  }) {
    return InkWell(
      onTap: () => setState(() => onChanged(value)),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          Radio<int>(
            value: value,
            groupValue: groupValue,
            onChanged: (v) => setState(() => onChanged(v)),
            activeColor: AppColors.primaryGreen,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(label, style: const TextStyle(color: AppColors.darkGreenText)),
        ],
      ),
    );
  }

  /// Shows a password-entry dialog used when restoring an encrypted backup.
  /// Returns the entered password, or [null] if the user cancelled.
  Future<String?> _promptForPassword() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Encrypted Backup',
          style: TextStyle(color: AppColors.darkGreenText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This backup is password-protected.\nEnter the password to continue.',
              style: TextStyle(fontSize: 13, color: AppColors.darkGreenText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Backup password',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => Navigator.pop(ctx, ctrl.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ctrl.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
            ),
            onPressed: () {
              final pw = ctrl.text;
              ctrl.dispose();
              Navigator.pop(ctx, pw);
            },
            child: const Text('Decrypt'),
          ),
        ],
      ),
    );
    return (result == null || result.isEmpty) ? null : result;
  }

  Future<void> _undoRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Undo Last Restore',
          style: TextStyle(color: AppColors.darkGreenText),
        ),
        content: const Text(
          'This will replace the current database with the one that was active '
          'before the last restore.\n\nAre you sure?',
          style: TextStyle(color: AppColors.darkGreenText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Undo Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBackupOperation = true);
    try {
      final success = await RestoreService.instance.undoLastRestore(
        onReloadData: () => ManagerData.instance.reload(),
      );
      if (!mounted) return;
      if (!success) return;

      final newMode = ManagerData.instance.loginMode;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => newMode == 'NAMEMODE'
              ? const WaiterSelectionScreen()
              : const LoginScreen(),
        ),
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore undone successfully.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Undo failed: $e'),
          backgroundColor: AppColors.negativeText,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBackupOperation = false;
          _hasRestoreUndo = false;
        });
      }
    }
  }

  Future<void> _restoreDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Restore Database',
          style: TextStyle(color: AppColors.darkGreenText),
        ),
        content: const Text(
          'This will replace ALL current data with the selected backup.\n\n'
          'The app will restart after the restore is complete.\n\n'
          'Are you sure you want to continue?',
          style: TextStyle(color: AppColors.darkGreenText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negativeText,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBackupOperation = true);
    try {
      final success = await RestoreService.instance.restoreDatabase(
        onReloadData: () => ManagerData.instance.reload(),
        onPasswordRequired: _promptForPassword,
      );
      if (!mounted) return;
      if (!success) return; // user cancelled file picker or password dialog

      // Refresh the undo indicator so the button appears immediately.
      final hasUndo = await RestoreService.instance.hasUndoAvailable();
      if (!mounted) return;
      setState(() => _hasRestoreUndo = hasUndo);

      final newMode = ManagerData.instance.loginMode;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => newMode == 'NAMEMODE'
              ? const WaiterSelectionScreen()
              : const LoginScreen(),
        ),
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database restored successfully.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: AppColors.negativeText,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBackupOperation = false);
    }
  }

  Future<void> _createBackupNow() async {
    setState(() => _isBackupOperation = true);
    try {
      final result =
          await DatabaseBackupManager.instance.performAutoBackup();
      if (!mounted) return;

      final folder =
          await DatabaseBackupManager.instance.getAutoBackupFolder();
      if (!mounted) return;
      setState(() => _autoBackupFolder = folder);

      final msg = switch (result) {
        AutoBackupResult.success =>
          'Backup created in:\n${folder ?? 'backup folder'}',
        AutoBackupResult.error => 'Backup failed. Check available disk space.',
        AutoBackupResult.sourceNotFound => 'Database file not found.',
        _ => 'Backup complete.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: result == AutoBackupResult.success
              ? AppColors.primaryGreen
              : AppColors.negativeText,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBackupOperation = false);
    }
  }

  Future<void> _configureBackupFolder() async {
    final path =
        await DatabaseBackupManager.instance.pickAndSetAutoBackupFolder();
    if (!mounted) return;
    if (path != null) {
      setState(() => _autoBackupFolder = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-backup folder set to:\n$path'),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _changeMode(String newMode) async {
    await _m.setLoginMode(newMode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Login mode changed to ${newMode == 'PINMODE' ? 'PIN' : 'Name'} Mode',
        ),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _savePrinter(String printerName) async {
    await PrinterSettingsStore.saveSelectedPrinterName(printerName);
    if (!mounted) return;
    setState(() => _selectedPrinter = printerName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Printer selected: $printerName'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }
}

// ── Data class ─────────────────────────────────────────────────────────────────

class _ExportOptions {
  const _ExportOptions({required this.compressed, this.password});
  final bool compressed;
  final String? password;
}

