import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/config/api_config.dart';
import 'package:pos_system/services/activation_service.dart';

void main() {
  group('deviceRevokeEndpoint', () {
    test('encodes device id in path', () {
      expect(
        deviceRevokeEndpoint('abc-123'),
        '/devices/abc-123/revoke',
      );
    });
  });

  group('shouldTreatAsDeviceRevocation', () {
    test('401 on sync is revocation', () {
      final error = DioException(
        requestOptions: RequestOptions(path: kEndpointSyncPush),
        response: Response(
          requestOptions: RequestOptions(path: kEndpointSyncPush),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );
      expect(ActivationService.shouldTreatAsDeviceRevocation(error), isTrue);
    });

    test('401 on validate-key is not revocation', () {
      final error = DioException(
        requestOptions: RequestOptions(path: kEndpointValidateKey),
        response: Response(
          requestOptions: RequestOptions(path: kEndpointValidateKey),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );
      expect(ActivationService.shouldTreatAsDeviceRevocation(error), isFalse);
    });

    test('403 LICENSE_SUSPENDED is not device revocation', () {
      final error = DioException(
        requestOptions: RequestOptions(path: kEndpointVerifyActivation),
        response: Response(
          requestOptions: RequestOptions(path: kEndpointVerifyActivation),
          statusCode: 403,
          data: {
            'code': 'LICENSE_SUSPENDED',
            'message': 'License suspended',
          },
        ),
        type: DioExceptionType.badResponse,
      );
      expect(ActivationService.shouldTreatAsDeviceRevocation(error), isFalse);
    });

    test('403 DEVICE_REVOKED is device revocation', () {
      final error = DioException(
        requestOptions: RequestOptions(path: kEndpointVerifyActivation),
        response: Response(
          requestOptions: RequestOptions(path: kEndpointVerifyActivation),
          statusCode: 403,
          data: {
            'code': 'DEVICE_REVOKED',
            'message': 'Device revoked',
          },
        ),
        type: DioExceptionType.badResponse,
      );
      expect(ActivationService.shouldTreatAsDeviceRevocation(error), isTrue);
    });
  });
}
