import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/config/api_config.dart';
import 'package:pos_system/services/api_enforcement_parser.dart';
import 'package:pos_system/services/activation_service.dart';

void main() {
  group('ApiEnforcementParser.actionForCode', () {
    test('license codes block', () {
      expect(
        ApiEnforcementParser.actionForCode(ApiEnforcementCodes.licenseExpired),
        ApiEnforcementAction.blockLicense,
      );
      expect(
        ApiEnforcementParser.actionForCode(
          ApiEnforcementCodes.businessSuspended,
        ),
        ApiEnforcementAction.blockLicense,
      );
    });

    test('device revoked revokes', () {
      expect(
        ApiEnforcementParser.actionForCode(ApiEnforcementCodes.deviceRevoked),
        ApiEnforcementAction.revokeDevice,
      );
      expect(
        ApiEnforcementParser.actionForCode(
          ApiEnforcementCodes.invalidRefreshToken,
        ),
        ApiEnforcementAction.revokeDevice,
      );
    });

    test('token expired refreshes', () {
      expect(
        ApiEnforcementParser.actionForCode(ApiEnforcementCodes.tokenExpired),
        ApiEnforcementAction.refreshToken,
      );
    });
  });

  group('ApiEnforcementParser.actionFromDio', () {
    DioException err(int? status, Map<String, dynamic>? data) => DioException(
      requestOptions: RequestOptions(path: kEndpointSyncPush),
      response: data == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: kEndpointSyncPush),
              statusCode: status,
              data: data,
            ),
      type: DioExceptionType.badResponse,
    );

    test('LICENSE_EXPIRED blocks', () {
      final e = err(403, {
        'code': ApiEnforcementCodes.licenseExpired,
        'message': 'License has expired',
      });
      expect(ApiEnforcementParser.requiresLicenseBlock(e), isTrue);
      expect(ApiEnforcementParser.requiresDeviceRevoke(e), isFalse);
    });

    test('DEVICE_REVOKED revokes not block', () {
      final e = err(403, {
        'code': ApiEnforcementCodes.deviceRevoked,
        'message': 'Device revoked',
      });
      expect(ApiEnforcementParser.requiresLicenseBlock(e), isFalse);
      expect(ApiEnforcementParser.requiresDeviceRevoke(e), isTrue);
    });

    test('TOKEN_EXPIRED on 401 refreshes', () {
      final e = err(401, {'code': ApiEnforcementCodes.tokenExpired});
      expect(ApiEnforcementParser.requiresTokenRefresh(e), isTrue);
      expect(ActivationService.shouldTreatAsDeviceRevocation(e), isFalse);
    });
  });

  group('ApiEnforcementParser.actionFromActivationBody', () {
    test('valid false with code blocks', () {
      expect(
        ApiEnforcementParser.actionFromActivationBody({
          'valid': false,
          'code': ApiEnforcementCodes.licenseExpired,
        }),
        ApiEnforcementAction.blockLicense,
      );
    });
  });
}
