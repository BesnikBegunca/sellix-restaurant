import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'manager/manager_data.dart';
import 'screens/login_screen.dart';
import 'screens/waiter_selection_screen.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite requires the FFI implementation on desktop platforms.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Ensure ManagerData finishes DB loading before deciding the first screen.
  while (ManagerData.instance.isLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  runApp(const PosSystemApp());
}

class PosSystemApp extends StatelessWidget {
  const PosSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = ManagerData.instance.loginMode;

    return MaterialApp(
      title: 'POS System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.beige,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
          surface: AppColors.white,
        ),
        textTheme: const TextTheme().apply(
          bodyColor: AppColors.darkGreenText,
          displayColor: AppColors.darkGreenText,
        ),
      ),
      home: mode == 'NAMEMODE'
          ? const WaiterSelectionScreen()
          : const LoginScreen(),
    );
  }
}
