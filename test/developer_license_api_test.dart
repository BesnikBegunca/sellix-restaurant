import 'package:flutter_test/flutter_test.dart';

import 'package:pos_system/models/developer_auth_response.dart';
import 'package:pos_system/models/license_extension_response.dart';

void main() {
  test('parses developer login response', () {
    final response = DeveloperAuthResponse.fromJson({
      'accessToken': 'token',
      'developerName': 'Support',
    });

    expect(response.accessToken, 'token');
    expect(response.developerName, 'Support');
  });

  test('rejects developer login without a token', () {
    expect(
      () => DeveloperAuthResponse.fromJson(const {}),
      throwsA(isA<FormatException>()),
    );
  });

  test('parses license extension response', () {
    final response = LicenseExtensionResponse.fromJson({
      'licenseKey': 'POS-123',
      'licenseExpiresAt': '2026-10-10T00:00:00.000Z',
    });

    expect(response.licenseKey, 'POS-123');
    expect(response.licenseExpiresAt, contains('2026-10-10'));
  });
}
