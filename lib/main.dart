import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'manager/manager_data.dart';
import 'screens/login_screen.dart';
import 'screens/waiter_selection_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_tokens.dart';

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
          seedColor: AppColors.deepForestGreen,
          brightness: Brightness.light,
          primary: AppColors.deepForestGreen,
          onPrimary: AppColors.pureWhite,
          surface: AppColors.pureWhite,
          onSurface: AppColors.charcoalText,
        ),
        textTheme: const TextTheme().apply(
          bodyColor: AppColors.charcoalText,
          displayColor: AppColors.charcoalText,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.cardRadius),
            side: const BorderSide(color: AppColors.lightGreenBorder),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.lightGreenBorder,
          thickness: 1,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: AppColors.deepForestGreen,
            foregroundColor: AppColors.pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.controlRadius),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: AppColors.deepForestGreen,
            side: const BorderSide(color: AppColors.lightGreenBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.controlRadius),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.pureWhite,
          hintStyle: TextStyle(
            color: AppColors.mutedGray.withValues(alpha: 0.85),
            fontSize: AppTokens.tableTextSize,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.controlRadius),
            borderSide: const BorderSide(color: AppColors.lightGreenBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.controlRadius),
            borderSide: const BorderSide(color: AppColors.lightGreenBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.controlRadius),
            borderSide: const BorderSide(
              color: AppColors.deepForestGreen,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.deepForestGreen,
          contentTextStyle: TextStyle(
            color: AppColors.pureWhite,
            fontSize: AppTokens.tableTextSize,
          ),
        ),
      ),
      home: mode == 'NAMEMODE'
          ? const WaiterSelectionScreen()
          : const LoginScreen(),
    );
  }
}
