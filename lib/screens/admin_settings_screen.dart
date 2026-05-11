import 'package:flutter/material.dart';

import '../manager/manager_data.dart';
import '../services/printer_settings_store.dart';
import '../services/windows_printers_service.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedMode = _m.loginMode;
    _m.addListener(_onDataChanged);
    _loadPrinters();
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
