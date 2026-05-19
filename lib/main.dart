import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'manager/manager_data.dart';
import 'screens/activation_screen.dart';
import 'screens/config_error_screen.dart';
import 'screens/device_revoked_screen.dart';
import 'screens/login_screen.dart';
import 'services/database_service.dart';
import 'services/activation_service.dart';
import 'services/activation_state_controller.dart';
import 'services/api_client.dart';
import 'services/background_sync_service.dart';
import 'services/connectivity_service.dart';
import 'services/license_gate_service.dart';
import 'services/runtime_config_service.dart';
import 'services/sync_status_service.dart';
import 'theme/app_colors.dart';
import 'widgets/license_blocked_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite requires the FFI implementation on desktop platforms.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Resolve API base URL from app_config.json / env var / fallback.
  await RuntimeConfigService.instance.load();
  final runtimeConfig = RuntimeConfigService.instance;
  ApiClient.instance.configureBaseUrl(runtimeConfig.apiBaseUrl);

  ApiClient.instance.onUnauthorizedRevoke = (error) async {
    if (!ActivationService.instance.isActivated) return;
    if (LicenseGateService.isLicenseSuspendedError(error)) return;
    if (!ActivationService.shouldTreatAsDeviceRevocation(error)) return;
    BackgroundSyncService.instance.stop();
    SyncStatusService.instance.stop();
    await ActivationService.instance.handleRevokedByServer(
      reason: ActivationService.messageForRevocation(error),
    );
  };

  if (kDebugMode) {
    debugPrint(
      'POS API: baseUrl=${runtimeConfig.apiBaseUrl} | '
      'source=${runtimeConfig.sourceLabel} | '
      'blockedInRelease=${runtimeConfig.isBlockedInRelease}',
    );
  }

  // Ensure ManagerData finishes DB loading before deciding the first screen.
  while (ManagerData.instance.isLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  final configBlocked = runtimeConfig.isBlockedInRelease;

  await ConnectivityService.instance.initialize();
  await BackgroundSyncService.instance.initialize();

  // Restore activation from SQLite metadata + secure token store (survives hot restart).
  final activationRestored =
      await ActivationService.instance.loadPersistedActivation();
  final activationState = ActivationStateController.instance;
  activationState.setActivated(activationRestored);

  if (kDebugMode) {
    debugPrint(
      '[Activation] startup restored=$activationRestored '
      'controller=${activationState.isActivated}',
    );
  }

  if (configBlocked) {
    BackgroundSyncService.instance.stop();
    await DatabaseService.instance.setAppMeta(
      'sync_last_error',
      RuntimeConfigService.syncConfigErrorMessage,
    );
  } else if (ActivationService.instance.isActivated) {
    // Verify token with backend — revokes locally on 401; continues on network error.
    await ActivationService.instance.verifyActivation();
    if (ActivationService.instance.isActivated) {
      BackgroundSyncService.instance.start();
    } else if (activationState.serverRevoked) {
      // verifyActivation → handleRevokedByServer already notified controller.
    } else if (!activationState.serverRevoked) {
      activationState.setActivated(false);
    }
  }

  SyncStatusService.instance.start();

  runApp(const PosSystemApp());
}

class PosSystemApp extends StatefulWidget {
  const PosSystemApp({super.key});

  @override
  State<PosSystemApp> createState() => _PosSystemAppState();
}

class _PosSystemAppState extends State<PosSystemApp> {
  final _activation = ActivationStateController.instance;
  late bool _configOk = !RuntimeConfigService.instance.isBlockedInRelease;

  @override
  void initState() {
    super.initState();
    ManagerData.instance.addListener(_onData);
    _activation.addListener(_onActivationChanged);
  }

  @override
  void dispose() {
    ManagerData.instance.removeListener(_onData);
    _activation.removeListener(_onActivationChanged);
    super.dispose();
  }

  void _onData() => setState(() {});

  void _onActivationChanged() => setState(() {});

  Future<void> _retryRuntimeConfig() async {
    await RuntimeConfigService.instance.reloadConfig();
    final config = RuntimeConfigService.instance;
    ApiClient.instance.configureBaseUrl(config.apiBaseUrl);
    if (!mounted) return;

    final ok = !config.isBlockedInRelease;
    setState(() => _configOk = ok);

    if (!ok) {
      BackgroundSyncService.instance.stop();
      await DatabaseService.instance.setAppMeta(
        'sync_last_error',
        RuntimeConfigService.syncConfigErrorMessage,
      );
      return;
    }

    await DatabaseService.instance.setAppMeta('sync_last_error', '');
    if (ActivationService.instance.isActivated) {
      await ActivationService.instance.verifyActivation();
      if (!mounted) return;
      if (ActivationService.instance.isActivated) {
        _activation.setActivated(true);
        BackgroundSyncService.instance.start();
      } else if (!_activation.serverRevoked) {
        _activation.setActivated(false);
      }
    }
    unawaited(SyncStatusService.instance.refresh());
  }

  Widget _buildHome() {
    if (!_configOk) {
      return ConfigErrorScreen(onRetry: _retryRuntimeConfig);
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
      home: _buildHome(),
    );
  }
}
