import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/developer_auth_response.dart';
import '../models/license_extension_response.dart';
import 'api_client.dart';

/// Authenticates trusted developers against the external licensing API.
///
/// Developer credentials never leave this service except for the HTTPS login
/// request. The token is kept in memory and is discarded when the app closes.
class DeveloperAuthService {
  DeveloperAuthService._();
  static final DeveloperAuthService instance = DeveloperAuthService._();

  String? _accessToken;
  String? _developerName;

  bool get isAuthenticated => _accessToken != null;
  String? get developerName => _developerName;

  Future<DeveloperAuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      kEndpointDeveloperLogin,
      data: {'email': email.trim(), 'password': password},
    );
    final result = DeveloperAuthResponse.fromJson(response.data ?? const {});
    _accessToken = result.accessToken;
    _developerName = result.developerName;
    return result;
  }

  Future<LicenseExtensionResponse> extendLicense({
    required String licenseKey,
    required int days,
  }) async {
    final token = _accessToken;
    if (token == null) {
      throw StateError('Developer authentication is required');
    }
    if (days < 1 || days > 3650) {
      throw ArgumentError.value(days, 'days', 'must be between 1 and 3650');
    }

    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      kEndpointDeveloperExtendLicense,
      data: {'licenseKey': licenseKey.trim(), 'days': days},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return LicenseExtensionResponse.fromJson(response.data ?? const {});
  }

  void logout() {
    _accessToken = null;
    _developerName = null;
  }
}
