import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'theme/theme_mode_controller.dart';
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
  await ThemeModeController.instance.load();

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
  final _themeMode = ThemeModeController.instance;
  @override
  void initState() {
    super.initState();
    ManagerData.instance.addListener(_onData);
    _activation.addListener(_onActivationChanged);
    _language.addListener(_onLanguageChanged);
    _themeMode.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ManagerData.instance.removeListener(_onData);
    _activation.removeListener(_onActivationChanged);
    _language.removeListener(_onLanguageChanged);
    _themeMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onData() => setState(() {});

  void _onActivationChanged() => setState(() {});
  void _onLanguageChanged() => setState(() {});
  void _onThemeChanged() => setState(() {});

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
      key: ValueKey<String>(
        'pos-system-${_themeMode.isDark ? 'dark' : 'light'}',
      ),
      builder: (context, child) =>
          LicenseBlockedOverlay(child: child ?? const SizedBox.shrink()),
      title: 'POS System',
      locale: _language.locale,
      supportedLocales: const [Locale('sq'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode.isDark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: Duration.zero,
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
              inherit: false,
              fontFamily: 'DMSans',
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
              inherit: false,
              fontFamily: 'DMSans',
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
              inherit: false,
              fontFamily: 'DMSans',
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
          contentTextStyle: TextStyle(
            inherit: false,
            fontFamily: 'DMSans',
            color: AppColors.white,
          ),
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
            inherit: false,
            fontFamily: 'DMSans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGreenText,
          ),
          contentTextStyle: const TextStyle(
            inherit: false,
            fontFamily: 'DMSans',
            fontSize: 14,
            color: AppColors.darkGreenText,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F83CC),
          brightness: Brightness.dark,
          primary: const Color(0xFF7EA6E0),
          onPrimary: Colors.white,
          secondary: const Color(0xFF91A9D2),
          surface: const Color(0xFF111C2E),
          onSurface: const Color(0xFFE7EEF9),
          surfaceContainerHighest: const Color(0xFF1A2940),
          outline: const Color(0xFF3A5275),
        ),
        fontFamily: 'DMSans',
        textTheme: const TextTheme().apply(
          fontFamily: 'DMSans',
          bodyColor: Color(0xFFE7EEF9),
          displayColor: Color(0xFFE7EEF9),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7EA6E0),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              inherit: false,
              fontFamily: 'DMSans',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7EA6E0),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              inherit: false,
              fontFamily: 'DMSans',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB7CCF0),
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: Color(0xFF3A5275)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              inherit: false,
              fontFamily: 'DMSans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF16243A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3A5275)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3A5275)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7EA6E0), width: 2),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF111C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF3A5275)),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF3A5275)),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF7EA6E0),
          contentTextStyle: TextStyle(
            inherit: false,
            color: Colors.white,
            fontFamily: 'DMSans',
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF111C2E),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            inherit: false,
            fontFamily: 'DMSans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE7EEF9),
          ),
          contentTextStyle: const TextStyle(
            inherit: false,
            fontFamily: 'DMSans',
            fontSize: 14,
            color: Color(0xFFC6D5EC),
          ),
        ),
      ),
      navigatorObservers: [appRouteObserver],
      home: _buildHome(),
    );
  }
}
