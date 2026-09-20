import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_system/config/api_config.dart';
import 'package:pos_system/services/api_enforcement_parser.dart';
import 'package:pos_system/services/database_service.dart';
import 'package:pos_system/services/license_gate_service.dart';
import 'package:pos_system/services/license_heartbeat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await LicenseGateService.instance.clearForRevocation();
    await LicenseGateService.clearPersistedStateQuietly();
  });

  group('LicenseGateService.enforceOrThrow', () {
    test('throws when blocked', () async {
      await LicenseGateService.instance.block(
        code: LicenseBlockCode.licenseExpired,
      );
      expect(
        () => LicenseGateService.instance.enforceOrThrow(),
        throwsA(isA<LicenseBlockedException>()),
      );
    });
  });

  group('LicenseGateService.handleDioException', () {
    test('LICENSE_EXPIRED sets blocked', () async {
      final error = DioException(
        requestOptions: RequestOptions(path: kEndpointVerifyActivation),
        response: Response(
          requestOptions: RequestOptions(path: kEndpointVerifyActivation),
          statusCode: 403,
          data: {
            'code': ApiEnforcementCodes.licenseExpired,
            'message': 'License has expired',
          },
        ),
        type: DioExceptionType.badResponse,
      );
      expect(
        await LicenseGateService.instance.handleDioException(error),
        isTrue,
      );
      expect(LicenseGateService.instance.isBlocked, isTrue);
      expect(LicenseGateService.instance.code, LicenseBlockCode.licenseExpired);
    });
  });

  group('LicenseGateService persistence', () {
    test('blocked state restores from app_meta', () async {
      await DatabaseService.instance.database;
      await LicenseGateService.instance.block(
        code: LicenseBlockCode.businessSuspended,
        message: 'Biznesi pezulluar',
      );
      expect(
        await DatabaseService.instance.getAppMeta(
          LicenseGateService.kMetaBlocked,
        ),
        'true',
      );

      await LicenseGateService.instance.clearForRevocation();
      expect(LicenseGateService.instance.isBlocked, isFalse);

      await LicenseGateService.instance.loadPersistedState();
      // Meta was cleared by clearForRevocation — simulate restart with meta only
      await DatabaseService.instance.setAppMeta(
        LicenseGateService.kMetaBlocked,
        'true',
      );
      await DatabaseService.instance.setAppMeta(
        LicenseGateService.kMetaCode,
        LicenseBlockCode.businessSuspended.name,
      );
      await DatabaseService.instance.setAppMeta(
        LicenseGateService.kMetaMessage,
        'Biznesi pezulluar',
      );

      await LicenseGateService.instance.loadPersistedState();
      expect(LicenseGateService.instance.isBlocked, isTrue);
      expect(
        LicenseGateService.instance.code,
        LicenseBlockCode.businessSuspended,
      );
    });
  });

  group('local expiry strict mode', () {
    test('blocks when activation_license_expires_at is past', () async {
      await DatabaseService.instance.database;
      final past = DateTime.now().toUtc().subtract(const Duration(days: 1));
      await DatabaseService.instance.setAppMeta(
        LicenseGateService.kLicenseExpiresAtMeta,
        past.toIso8601String(),
      );
      final blocked = await LicenseGateService.instance
          .checkAndBlockIfLocallyExpired();
      expect(blocked, isTrue);
      expect(LicenseGateService.instance.isBlocked, isTrue);
    });
  });

  group('unblock', () {
    test('clears persisted meta', () async {
      await DatabaseService.instance.database;
      await LicenseGateService.instance.block(
        code: LicenseBlockCode.licenseSuspended,
      );
      await LicenseGateService.instance.unblock();
      expect(LicenseGateService.instance.isBlocked, isFalse);
      expect(
        await DatabaseService.instance.getAppMeta(
          LicenseGateService.kMetaBlocked,
        ),
        '',
      );
    });

    test('fires onUnblocked so sync resumes without a restart', () async {
      await DatabaseService.instance.database;
      var blockedCalls = 0;
      var unblockedCalls = 0;
      LicenseGateService.instance.onBlocked = () => blockedCalls++;
      LicenseGateService.instance.onUnblocked = () => unblockedCalls++;
      addTearDown(() {
        LicenseGateService.instance.onBlocked = null;
        LicenseGateService.instance.onUnblocked = null;
      });

      await LicenseGateService.instance.block(
        code: LicenseBlockCode.licenseRevoked,
      );
      expect(blockedCalls, 1);
      expect(unblockedCalls, 0);

      await LicenseGateService.instance.unblock();
      expect(unblockedCalls, 1);

      // Already clear — no spurious resume.
      await LicenseGateService.instance.unblock();
      expect(unblockedCalls, 1);
    });
  });

  group('revoked license', () {
    test('LICENSE_REVOKED from the API blocks and names SelliX', () async {
      await DatabaseService.instance.database;
      final error = DioException(
        requestOptions: RequestOptions(path: kEndpointVerifyActivation),
        response: Response(
          requestOptions: RequestOptions(path: kEndpointVerifyActivation),
          statusCode: 403,
          data: {'code': ApiEnforcementCodes.licenseRevoked},
        ),
        type: DioExceptionType.badResponse,
      );
      expect(
        await LicenseGateService.instance.handleDioException(error),
        isTrue,
      );
      expect(LicenseGateService.instance.code, LicenseBlockCode.licenseRevoked);
      expect(LicenseGateService.instance.message, contains('SelliX'));
    });

    test('heartbeat polls faster while the app is blocked', () async {
      await DatabaseService.instance.database;
      final heartbeat = LicenseHeartbeatService.instance;
      addTearDown(heartbeat.debugReset);

      expect(heartbeat.nextInterval(), LicenseHeartbeatService.kActiveInterval);

      await LicenseGateService.instance.block(
        code: LicenseBlockCode.licenseRevoked,
      );
      expect(heartbeat.nextInterval(), LicenseHeartbeatService.kBlockedInterval);

      await LicenseGateService.instance.unblock();
      expect(heartbeat.nextInterval(), LicenseHeartbeatService.kActiveInterval);
    });
  });
}
