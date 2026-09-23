import 'dart:async';
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
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';
import 'widgets/license_blocked_overlay.dart';
import 'l10n/tr.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Paint the first frame immediately. Heavy init runs after the window exists.
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
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    ManagerData.instance.addListener(_onData);
    _activation.addListener(_onActivationChanged);
    _language.addListener(_onLanguageChanged);
    _themeMode.addListener(_onThemeChanged);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final started = DateTime.now();
      while (ManagerData.instance.isLoading) {
        if (DateTime.now().difference(started) > const Duration(seconds: 15)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await AppLanguageService.instance.load();
      await ThemeModeController.instance.load();

      await RuntimeConfigService.instance.load();
      ApiClient.instance.configureBaseUrl(
        RuntimeConfigService.instance.apiBaseUrl,
      );
      await BackgroundSyncService.instance.initialize();

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

      LicenseGateService.instance.onBlocked =
          BackgroundSyncService.instance.stop;
      LicenseGateService.instance.onUnblocked =
          BackgroundSyncService.instance.start;

      if (ActivationService.instance.isActivated) {
        await LicenseGateService.instance.loadPersistedState();
        await LicenseGateService.instance.checkAndBlockIfLocallyExpired();

        await ActivationService.instance
            .verifyActivation(force: true)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          debugPrint('[Activation] verify timed out — continuing');
          return ActivationService.instance.isActivated;
        });

        if (!ActivationService.instance.isActivated &&
            !activationState.serverRevoked &&
            !LicenseGateService.instance.isBlocked) {
          activationState.setActivated(false);
        } else if (ActivationService.instance.isActivated &&
            !LicenseGateService.instance.isBlocked) {
          BackgroundSyncService.instance.start();
        }

        if (ActivationService.instance.isActivated) {
          // Expired / pezulluar: heartbeat pret extend/vazhdim nga webi.
          // New key: overlay kërkon çelësin e ri; heartbeat ndalet vetë.
          LicenseHeartbeatService.instance.start(
            checkImmediately:
                LicenseGateService.instance.waitsForWebRestore,
          );
        }
      }
    } catch (e, st) {
      debugPrint('PosSystemApp bootstrap failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _ready = true);
    }
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
    if (!_ready) {
      return const _StartupSplash();
    }
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

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 20),
            Text(
              'SelliX',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
