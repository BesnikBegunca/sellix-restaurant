import 'package:flutter/material.dart';

import '../manager/manager_data.dart';
import '../services/audit_log_service.dart';
import '../services/backup_service.dart';
import '../services/database_backup_manager.dart';
import '../services/escpos/escpos_printer_service.dart';
import '../services/escpos/printer_profile.dart';
import '../services/printer_settings_store.dart';
import '../services/restore_service.dart';
import '../services/windows_printers_service.dart';
import 'login_screen.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

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
  bool _autoBackupPasswordSet = false;

  // ── ESC/POS + receipt settings ────────────────────────────────────────────
  bool _useEscPos         = true;
  bool _cashDrawerEnabled = false;
  int  _paperWidthMm      = 80;
  final _footerCtrl  = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  bool _isTesting = false;
  bool _isOpeningDrawer = false;

  @override
  void initState() {
    super.initState();
    _selectedMode       = _m.loginMode;
    _useEscPos          = _m.useEscPos;
    _cashDrawerEnabled  = _m.cashDrawerEnabled;
    _paperWidthMm       = _m.paperWidthMm;
    _footerCtrl.text    = _m.receiptFooter;
    _addressCtrl.text   = _m.businessAddress ?? '';
    _phoneCtrl.text     = _m.businessPhone ?? '';
    _m.addListener(_onDataChanged);
    _loadPrinters();
    _loadBackupInfo();
    _triggerAutoBackup();
  }

  @override
  void dispose() {
    _m.removeListener(_onDataChanged);
    _footerCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    setState(() {
      _selectedMode      = _m.loginMode;
      _useEscPos         = _m.useEscPos;
      _cashDrawerEnabled = _m.cashDrawerEnabled;
      _paperWidthMm      = _m.paperWidthMm;
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
                    Text(
                      'Login Mode',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select how waiters log in to the system',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildModeOption(
                      mode: 'PINMODE',
                      title: tr.pinMode,
                      description:
                          tr.waitersEnterTheirPinAccessTheir,
                      isSelected: _selectedMode == 'PINMODE',
                      onTap: () => _changeMode('PINMODE'),
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
                    Text(
                      'Printers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select the Windows printer used for POS80 receipts.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loadingPrinters)
                      CircularProgressIndicator()
                    else if (_printers.isEmpty)
                      Text(
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
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: tr.windowsPrinter,
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
                    if (_selectedPrinter.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      // Capability preview
                      Builder(builder: (_) {
                        final profile = PrinterProfile.detectFromName(_selectedPrinter);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detected profile: ${profile.name}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkGreenText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Paper: ${profile.paperWidthMm}mm  ·  '
                              'Cut: ${profile.supportsCut ? "✓" : "✗"}  ·  '
                              'Drawer: ${profile.supportsDrawer ? "✓" : "✗"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.lightGreenText,
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 12),
                      // Test Print + Open Cash Drawer buttons
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: AppColors.white,
                            ),
                            onPressed: _isTesting ? null : _testPrint,
                            icon: _isTesting
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : const Icon(Icons.print_outlined, size: 18),
                            label: const Text('Test Print'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isOpeningDrawer ? null : _openDrawer,
                            icon: _isOpeningDrawer
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.point_of_sale_outlined, size: 18),
                            label: const Text('Open Cash Drawer'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildReceiptSettingsCard(),
          ],
        ),
      ),
    );
  }

  // ── Receipt settings card ─────────────────────────────────────────────────

  Widget _buildReceiptSettingsCard() {
    return Card(
      elevation: 2,
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receipt Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure ESC/POS mode, paper size, cash drawer, and receipt content.',
              style: TextStyle(fontSize: 14, color: AppColors.darkGreenText),
            ),
            const SizedBox(height: 20),

            // ESC/POS toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'ESC/POS mode',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
              subtitle: Text(
                'Send raw ESC/POS commands (recommended). Disable to use legacy text-mode printing.',
                style: TextStyle(fontSize: 12, color: AppColors.lightGreenText),
              ),
              value: _useEscPos,
              activeColor: AppColors.primaryGreen,
              onChanged: (v) async {
                setState(() => _useEscPos = v);
                await _m.saveEscPosSettings(useEscPos: v);
              },
            ),

            const SizedBox(height: 12),

            // Cash drawer toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Open cash drawer after payment',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
              subtitle: Text(
                'Sends ESC p command after a successful sale. Requires a compatible drawer.',
                style: TextStyle(fontSize: 12, color: AppColors.lightGreenText),
              ),
              value: _cashDrawerEnabled,
              activeColor: AppColors.primaryGreen,
              onChanged: (v) async {
                setState(() => _cashDrawerEnabled = v);
                await _m.saveEscPosSettings(cashDrawerEnabled: v);
              },
            ),

            const SizedBox(height: 16),

            // Paper width selector
            Text(
              'Paper width',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _paperWidthChip(80),
                const SizedBox(width: 12),
                _paperWidthChip(58),
              ],
            ),

            const SizedBox(height: 20),

            // Footer text
            TextField(
              controller: _footerCtrl,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: tr.receiptFooterText,
                hintText: tr.juFaleminderit,
              ),
              onSubmitted: (_) => _saveReceiptText(),
              onEditingComplete: _saveReceiptText,
            ),
            const SizedBox(height: 12),

            // Business address
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: tr.businessAddressOptional,
                hintText: tr.rrugaShembullNr1Tirane,
              ),
              onSubmitted: (_) => _saveReceiptText(),
              onEditingComplete: _saveReceiptText,
            ),
            const SizedBox(height: 12),

            // Business phone
            TextField(
              controller: _phoneCtrl,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: tr.businessPhoneOptional,
                hintText: tr.k355691234567,
              ),
              onSubmitted: (_) => _saveReceiptText(),
              onEditingComplete: _saveReceiptText,
            ),
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                ),
                onPressed: _saveReceiptText,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save Receipt Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paperWidthChip(int mm) {
    final selected = _paperWidthMm == mm;
    return ChoiceChip(
      label: Text('${mm}mm'),
      selected: selected,
      selectedColor: AppColors.primaryGreen,
      labelStyle: TextStyle(
        color: selected ? AppColors.white : AppColors.darkGreenText,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) async {
        setState(() => _paperWidthMm = mm);
        await _m.saveEscPosSettings(paperWidthMm: mm);
      },
    );
  }

  Future<void> _saveReceiptText() async {
    await _m.saveEscPosSettings(
      receiptFooter:   _footerCtrl.text.trim().isEmpty ? tr.juFaleminderit : _footerCtrl.text.trim(),
      businessAddress: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      businessPhone:   _phoneCtrl.text.trim().isEmpty  ? null : _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receipt settings saved.'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _testPrint() async {
    if (_selectedPrinter.trim().isEmpty) return;
    setState(() => _isTesting = true);
    try {
      final profile = PrinterProfile.detectFromName(_selectedPrinter)
          .withPaperWidth(_paperWidthMm);
      final ok = await EscPosPrinterService.instance.printTestPage(
        printerName: _selectedPrinter,
        companyName: _m.companyName ?? tr.posSystem,
        profile: profile,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Test page sent to printer.' : 'Test print failed. Check printer connection.'),
          backgroundColor: ok ? AppColors.primaryGreen : AppColors.negativeText,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _openDrawer() async {
    if (_selectedPrinter.trim().isEmpty) return;
    setState(() => _isOpeningDrawer = true);
    try {
      await EscPosPrinterService.instance.openCashDrawer(_selectedPrinter);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cash drawer command sent.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningDrawer = false);
    }
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
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
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
            Text(
              'Database Backup',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
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
                      side: BorderSide(color: AppColors.primaryGreen),
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
              Row(
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
            Text(
              'Auto-Backup',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
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
                Text(
                  'Compress backups (.zip)',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.darkGreenText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _autoBackupPasswordSet
                      ? Icons.lock_outlined
                      : Icons.lock_open_outlined,
                  size: 16,
                  color: _autoBackupPasswordSet
                      ? AppColors.primaryGreen
                      : AppColors.negativeText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _autoBackupPasswordSet
                        ? 'Encryption password configured'
                        : 'No encryption password — auto-backup disabled',
                    style: TextStyle(
                      fontSize: 12,
                      color: _autoBackupPasswordSet
                          ? AppColors.primaryGreen
                          : AppColors.negativeText,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      _isBackupOperation ? null : _setAutoBackupPassword,
                  child: Text(
                    _autoBackupPasswordSet
                        ? 'Change Password'
                        : 'Set Password',
                    style: const TextStyle(fontSize: 12),
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
                    Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _autoBackupFolder!,
                        style: TextStyle(
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
                    side: BorderSide(color: AppColors.primaryGreen),
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
                    side: BorderSide(color: AppColors.primaryGreen),
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
    final passwordSet =
        await DatabaseBackupManager.instance.hasAutoBackupPassword();
    if (!mounted) return;
    setState(() {
      _autoBackupFolder = folder;
      _hasRestoreUndo = hasUndo;
      _useCompression = compress;
      _autoBackupPasswordSet = passwordSet;
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
      AuditLogService.instance.logBackupExported(
        path: path,
        compressed: opts.compressed,
        encrypted: true, // encryption is now mandatory
      );
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

  /// Shows a dialog letting the admin choose export format and set a required
  /// encryption password (minimum 8 characters).  Returns null if cancelled.
  Future<_ExportOptions?> _showExportOptionsDialog() async {
    // 0 = Encrypted (.enc.db), 1 = Encrypted + Compressed (.enc.zip)
    int selectedFormat = 0;
    final pwCtrl = TextEditingController();
    final pwConfirmCtrl = TextEditingController();
    String? errorMsg;

    final result = await showDialog<_ExportOptions>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                'Export Options',
                style: TextStyle(color: AppColors.darkGreenText),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                      label: tr.encryptedEncDb,
                      value: 0,
                      groupValue: selectedFormat,
                      onChanged: (v) => selectedFormat = v!,
                    ),
                    _dialogRadio(
                      ctx: ctx,
                      setState: setDialogState,
                      label: tr.encryptedCompressedEncZip,
                      value: 1,
                      groupValue: selectedFormat,
                      onChanged: (v) => selectedFormat = v!,
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Encryption Password (required, min 8 characters)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: pwCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: tr.password,
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: pwConfirmCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: tr.confirmPassword,
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMsg!,
                        style: TextStyle(
                          color: AppColors.negativeText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: () {
                    if (pwCtrl.text.length < 8) {
                      setDialogState(
                        () => errorMsg =
                            'Password must be at least 8 characters.',
                      );
                      return;
                    }
                    if (pwCtrl.text != pwConfirmCtrl.text) {
                      setDialogState(
                        () => errorMsg = 'Passwords do not match.',
                      );
                      return;
                    }
                    final opts = _ExportOptions(
                      compressed: selectedFormat == 1,
                      password: pwCtrl.text,
                    );
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

    pwCtrl.dispose();
    pwConfirmCtrl.dispose();
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
          Text(label, style: TextStyle(color: AppColors.darkGreenText)),
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
        title: Text(
          'Encrypted Backup',
          style: TextStyle(color: AppColors.darkGreenText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This backup is password-protected.\nEnter the password to continue.',
              style: TextStyle(fontSize: 13, color: AppColors.darkGreenText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: tr.backupPassword,
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

  /// Warning dialog shown before restoring a plaintext (non-encrypted) backup.
  /// Returns true if the user confirms they want to proceed.
  Future<bool> _warnUnencryptedBackup() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Unencrypted Backup',
          style: TextStyle(color: AppColors.darkGreenText),
        ),
        content: Text(
          'This backup file is not encrypted. Restoring an unencrypted backup '
          'replaces all current data with plaintext data.\n\n'
          'Are you sure you want to continue?',
          style: TextStyle(fontSize: 13, color: AppColors.darkGreenText),
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
            child: const Text('Restore Anyway'),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  /// Dialog for setting or changing the auto-backup encryption password.
  Future<void> _setAutoBackupPassword() async {
    final pwCtrl = TextEditingController();
    final pwConfirmCtrl = TextEditingController();
    String? capturedPassword;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Auto-Backup Encryption Password',
            style: TextStyle(color: AppColors.darkGreenText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set a password to encrypt automatic backups. '
                'You will need this password to restore any auto-backup.',
                style: TextStyle(fontSize: 13, color: AppColors.darkGreenText),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pwCtrl,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: tr.passwordMin8Characters,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pwConfirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: tr.confirmPassword,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMsg!,
                  style: TextStyle(
                    color: AppColors.negativeText,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
              ),
              onPressed: () {
                if (pwCtrl.text.length < 8) {
                  setDialogState(
                    () => errorMsg =
                        'Password must be at least 8 characters.',
                  );
                  return;
                }
                if (pwCtrl.text != pwConfirmCtrl.text) {
                  setDialogState(
                    () => errorMsg = 'Passwords do not match.',
                  );
                  return;
                }
                capturedPassword = pwCtrl.text;
                Navigator.pop(ctx);
              },
              child: const Text('Set Password'),
            ),
          ],
        ),
      ),
    );

    pwCtrl.dispose();
    pwConfirmCtrl.dispose();

    if (capturedPassword == null || !mounted) return;
    await DatabaseBackupManager.instance
        .setAutoBackupPassword(capturedPassword!);
    if (!mounted) return;
    setState(() => _autoBackupPasswordSet = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-backup encryption password set.'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _undoRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Undo Last Restore',
          style: TextStyle(color: AppColors.darkGreenText),
        ),
        content: Text(
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
      AuditLogService.instance.logRestoreUndone();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
        title: Text(
          'Restore Database',
          style: TextStyle(color: AppColors.darkGreenText),
        ),
        content: Text(
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
    AuditLogService.instance.logBackupRestoreAttempt();
    try {
      final success = await RestoreService.instance.restoreDatabase(
        onReloadData: () => ManagerData.instance.reload(),
        onPasswordRequired: _promptForPassword,
        onPlaintextWarning: _warnUnencryptedBackup,
      );
      if (!mounted) return;
      if (!success) return; // user cancelled file picker or password dialog
      AuditLogService.instance.logBackupRestored();

      // Refresh the undo indicator so the button appears immediately.
      final hasUndo = await RestoreService.instance.hasUndoAvailable();
      if (!mounted) return;
      setState(() => _hasRestoreUndo = hasUndo);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database restored successfully.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      AuditLogService.instance.logFailedRestore(reason: e.toString());
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
        AutoBackupResult.noPasswordConfigured =>
          'Set an encryption password before running auto-backup.',
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
    final oldMode = _m.loginMode;
    await _m.setLoginMode(newMode);
    AuditLogService.instance.logSettingChanged(
      settingKey: 'loginMode',
      oldValue: oldMode,
      newValue: newMode,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Login mode changed to PIN Mode',
        ),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _savePrinter(String printerName) async {
    final oldPrinter = _selectedPrinter;
    await PrinterSettingsStore.saveSelectedPrinterName(printerName);
    AuditLogService.instance.logPrinterChanged(
      oldPrinter: oldPrinter.isEmpty ? null : oldPrinter,
      newPrinter: printerName,
    );
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

