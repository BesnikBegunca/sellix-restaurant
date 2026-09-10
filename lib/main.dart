import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'manager/manager_data.dart';
import 'screens/activation_screen.dart';
import 'screens/device_revoked_screen.dart';
import 'navigation/app_route_observer.dart';
import 'screens/login_screen.dart';
import 'services/activation_service.dart';
import 'services/activation_state_controller.dart';
import 'services/license_gate_service.dart';
import 'services/app_language_service.dart';
import 'theme/app_colors.dart';
import 'widgets/license_blocked_overlay.dart';

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
  await AppLanguageService.instance.load();

  // Restore activation from SQLite metadata + secure token store (survives hot restart).
  final activationRestored = await ActivationService.instance
      .loadPersistedActivation();
  final activationState = ActivationStateController.instance;
  activationState.setActivated(activationRestored);

  if (kDebugMode) {
    debugPrint(
      '[Activation] startup restored=$activationRestored '
      'controller=${activationState.isActivated}',
    );
  }

  if (ActivationService.instance.isActivated) {
    await LicenseGateService.instance.loadPersistedState();
    await LicenseGateService.instance.checkAndBlockIfLocallyExpired();

    if (!LicenseGateService.instance.isBlocked) {
      await ActivationService.instance.verifyActivation();
    }

    if (!ActivationService.instance.isActivated &&
        !activationState.serverRevoked &&
        !LicenseGateService.instance.isBlocked) {
      activationState.setActivated(false);
    }
  }

  runApp(const PosSystemApp());
}

class PosSystemApp extends StatefulWidget {
  const PosSystemApp({super.key});

  @override
  State<PosSystemApp> createState() => _PosSystemAppState();
}

class _PosSystemAppState extends State<PosSystemApp> {
  final _activation = ActivationStateController.instance;
  final _language = AppLanguageService.instance;
  @override
  void initState() {
    super.initState();
    ManagerData.instance.addListener(_onData);
    _activation.addListener(_onActivationChanged);
    _language.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    ManagerData.instance.removeListener(_onData);
    _activation.removeListener(_onActivationChanged);
    _language.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onData() => setState(() {});

  void _onActivationChanged() => setState(() {});
  void _onLanguageChanged() => setState(() {});

  Widget _buildHome() {
    if (_activation.isActivated) {
      return const LoginScreen();
    }
    if (_activation.serverRevoked) {
      return DeviceRevokedScreen(message: _activation.serverRevokeMessage);
    }
    return const ActivationScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) =>
          LicenseBlockedOverlay(child: child ?? const SizedBox.shrink()),
      title: 'POS System',
      locale: _language.locale,
      supportedLocales: const [Locale('sq'), Locale('en')],
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
        fontFamily: 'DMSans',
        textTheme: const TextTheme().apply(
          fontFamily: 'DMSans',
          bodyColor: AppColors.darkGreenText,
          displayColor: AppColors.darkGreenText,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lightGreenBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lightGreenBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primaryGreen,
              width: 2,
            ),
          ),
          hintStyle: const TextStyle(
            color: AppColors.lightGreenText,
            fontSize: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryGreen,
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: AppColors.lightGreenBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.lightGreenBorder,
          thickness: 1,
          space: 1,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.lightGreenBorder),
          ),
          margin: EdgeInsets.zero,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryGreen,
          contentTextStyle: TextStyle(color: AppColors.white),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.lightGreenBg,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGreenText,
            fontFamily: 'DMSans',
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14,
            color: AppColors.darkGreenText,
            fontFamily: 'DMSans',
          ),
        ),
      ),
      navigatorObservers: [appRouteObserver],
      home: _buildHome(),
    );
  }
}
