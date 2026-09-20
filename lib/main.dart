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
import 'services/api_client.dart';
import 'services/background_sync_service.dart';
import 'services/license_gate_service.dart';
import 'services/license_heartbeat_service.dart';
import 'services/runtime_config_service.dart';
import 'services/app_language_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';
import 'widgets/license_blocked_overlay.dart';
import 'l10n/tr.dart';

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

  await RuntimeConfigService.instance.load();
  ApiClient.instance.configureBaseUrl(RuntimeConfigService.instance.apiBaseUrl);
  await BackgroundSyncService.instance.initialize();

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

  // A block must cut the app off live; lifting it must resume it live.
  LicenseGateService.instance.onBlocked = BackgroundSyncService.instance.stop;
  LicenseGateService.instance.onUnblocked = BackgroundSyncService.instance.start;

  if (ActivationService.instance.isActivated) {
    await LicenseGateService.instance.loadPersistedState();
    await LicenseGateService.instance.checkAndBlockIfLocallyExpired();

    // Runs even when the gate is blocked: a license re-activated in the portal
    // clears the block on the next beat instead of waiting for a restart.
    await ActivationService.instance.verifyActivation(force: true);

    if (!ActivationService.instance.isActivated &&
        !activationState.serverRevoked &&
        !LicenseGateService.instance.isBlocked) {
      activationState.setActivated(false);
    } else if (ActivationService.instance.isActivated &&
        !LicenseGateService.instance.isBlocked) {
      BackgroundSyncService.instance.start();
    }

    if (ActivationService.instance.isActivated) {
      LicenseHeartbeatService.instance.start(checkImmediately: false);
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
      builder: (context, child) =>
          LicenseBlockedOverlay(child: child ?? const SizedBox.shrink()),
      title: tr.posSystem,
      locale: _language.locale,
      supportedLocales: AppLanguageService.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode.isDark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: Duration.zero,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      navigatorObservers: [appRouteObserver],
      home: _buildHome(),
    );
  }
}
