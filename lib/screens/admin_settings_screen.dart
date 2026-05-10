import 'package:flutter/material.dart';
import '../manager/manager_data.dart';
import '../theme/app_colors.dart';

/// Admin Settings Screen - allows changing login mode between PIN and NAME.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final ManagerData _m = ManagerData.instance;
  late String _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = _m.loginMode;
    _m.addListener(_onDataChanged);
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
            // Login Mode Section
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
                    // PIN Mode Option
                    _buildModeOption(
                      mode: 'PINMODE',
                      title: '🔐 PIN Mode',
                      description:
                          'Waiters enter their PIN to access their tables',
                      isSelected: _selectedMode == 'PINMODE',
                      onTap: () => _changeMode('PINMODE'),
                    ),
                    const SizedBox(height: 16),
                    // Name Mode Option
                    _buildModeOption(
                      mode: 'NAMEMODE',
                      title: '👤 Name Mode',
                      description: 'Waiters select their name from a list',
                      isSelected: _selectedMode == 'NAMEMODE',
                      onTap: () => _changeMode('NAMEMODE'),
                    ),
                    const SizedBox(height: 24),
                    // Description
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.beige,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '📋 Current Mode Details:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• PIN Mode: Each waiter has a unique PIN (4-6 digits)\n'
                            '• Name Mode: All waiter names are displayed, no PIN required',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                        ],
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login mode changed to ${newMode == 'PINMODE' ? 'PIN' : 'Name'} Mode'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }
}
