import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/sellix_license.dart';
import 'api_client.dart';

class SellixLicenseException implements Exception {
  SellixLicenseException(this.reason, {this.statusCode});

  final String reason;
  final int? statusCode;

  @override
  String toString() => sellixLicenseReasonMessage(reason);
}

/// Thin client for `POST /api/license/activate` and `/api/license/check`.
class SellixLicenseClient {
  SellixLicenseClient._();
  static final SellixLicenseClient instance = SellixLicenseClient._();

  Future<SellixLicenseResponse> activate({
    required String licenseKey,
    required String deviceId,
    String? deviceName,
  }) {
    return _post(
      kEndpointLicenseActivate,
      licenseKey: licenseKey,
      deviceId: deviceId,
      extra: {
        if (deviceName != null && deviceName.trim().isNotEmpty)
          'deviceName': deviceName.trim(),
      },
    );
  }

  Future<SellixLicenseResponse> check({
    required String licenseKey,
    required String deviceId,
  }) {
    return _post(
      kEndpointLicenseCheck,
      licenseKey: licenseKey,
      deviceId: deviceId,
    );
  }

  Future<SellixLicenseResponse> _post(
    String path, {
    required String licenseKey,
    required String deviceId,
    Map<String, dynamic>? extra,
  }) async {
    final key = normalizeSellixLicenseKey(licenseKey);
    final body = <String, dynamic>{
      'licenseKey': key,
      'deviceId': deviceId,
      ...?extra,
    };
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(
          headers: {kHeaderLicenseKey: key},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final data = response.data;
      if (data == null) {
        throw SellixLicenseException('empty_response', statusCode: response.statusCode);
      }
      final parsed = SellixLicenseResponse.fromJson(data);
      if (!parsed.valid) {
        throw SellixLicenseException(
          parsed.reason ?? 'invalid',
          statusCode: response.statusCode,
        );
      }
      return parsed;
    } on SellixLicenseException {
      rethrow;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        final reason = (data['reason'] as String?)?.trim();
        if (reason != null && reason.isNotEmpty) {
          throw SellixLicenseException(reason, statusCode: e.response?.statusCode);
        }
      }
      if (_isNetworkError(e)) {
        throw SellixLicenseException('network', statusCode: e.response?.statusCode);
      }
      if (kDebugMode) {
        debugPrint('SellixLicenseClient: $path failed: $e');
      }
      throw SellixLicenseException('invalid', statusCode: e.response?.statusCode);
    }
  }

  static bool _isNetworkError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      default:
        return e.response == null;
    }
  }
}
