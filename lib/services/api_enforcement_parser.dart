import 'package:dio/dio.dart';

/// Standard pos_api enforcement `code` values (response body).
abstract final class ApiEnforcementCodes {
  static const licenseExpired = 'LICENSE_EXPIRED';
  static const licenseSuspended = 'LICENSE_SUSPENDED';
  static const licenseRevoked = 'LICENSE_REVOKED';
  static const businessSuspended = 'BUSINESS_SUSPENDED';
  static const deviceSuspended = 'DEVICE_SUSPENDED';
  static const deviceRevoked = 'DEVICE_REVOKED';
  static const tokenExpired = 'TOKEN_EXPIRED';
  static const invalidRefreshToken = 'INVALID_REFRESH_TOKEN';
}

enum ApiEnforcementAction {
  blockLicense,
  revokeDevice,
  refreshToken,
  none,
}

class ApiEnforcementParser {
  ApiEnforcementParser._();

  static String? codeFromData(dynamic data) {
    if (data is! Map) return null;
    final code = data['code'];
    if (code is String && code.isNotEmpty) return code;
    return null;
  }

  static String? messageFromData(dynamic data) {
    if (data is! Map) return null;
    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;
    if (message is List && message.isNotEmpty) {
      return message.first.toString();
    }
    return null;
  }

  static bool? validFromData(dynamic data) {
    if (data is! Map) return null;
    final valid = data['valid'];
    if (valid is bool) return valid;
    return null;
  }

  static ApiEnforcementAction actionForCode(String? code) {
    switch (code) {
      case ApiEnforcementCodes.licenseExpired:
      case ApiEnforcementCodes.licenseSuspended:
      case ApiEnforcementCodes.licenseRevoked:
      case ApiEnforcementCodes.businessSuspended:
      case ApiEnforcementCodes.deviceSuspended:
        return ApiEnforcementAction.blockLicense;
      case ApiEnforcementCodes.deviceRevoked:
      case ApiEnforcementCodes.invalidRefreshToken:
        return ApiEnforcementAction.revokeDevice;
      case ApiEnforcementCodes.tokenExpired:
        return ApiEnforcementAction.refreshToken;
      default:
        return ApiEnforcementAction.none;
    }
  }

  static ApiEnforcementAction actionFromDio(DioException error) {
    final code = codeFromData(error.response?.data);
    if (code != null) return actionForCode(code);

    final status = error.response?.statusCode;
    if (status == 401) return ApiEnforcementAction.revokeDevice;
    if (status == 403) return ApiEnforcementAction.blockLicense;
    return ApiEnforcementAction.none;
  }

  static ApiEnforcementAction actionFromActivationBody(dynamic data) {
    final code = codeFromData(data);
    if (code != null) return actionForCode(code);
    if (validFromData(data) == false) {
      return ApiEnforcementAction.blockLicense;
    }
    return ApiEnforcementAction.none;
  }

  static bool requiresLicenseBlock(DioException error) {
    return actionFromDio(error) == ApiEnforcementAction.blockLicense;
  }

  static bool requiresDeviceRevoke(DioException error) {
    return actionFromDio(error) == ApiEnforcementAction.revokeDevice;
  }

  static bool requiresTokenRefresh(DioException error) {
    return actionFromDio(error) == ApiEnforcementAction.refreshToken;
  }
}
