import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/services/support_bundle_redaction.dart';

void main() {
  group('support bundle redaction', () {
    test('redactSensitiveValue redacts token keys', () {
      expect(redactSensitiveValue('accessToken', 'secret-value'), '<redacted>');
      expect(redactSensitiveValue('refresh_token', 'x'), '<redacted>');
    });

    test('redactSensitiveValue redacts pin and password keys', () {
      expect(redactSensitiveValue('adminPinHash', 'abc'), '<redacted>');
      expect(redactSensitiveValue('password', 'p'), '<redacted>');
      expect(redactSensitiveValue('activationKey', 'k'), '<redacted>');
    });

    test('redactSensitiveValue keeps safe keys', () {
      expect(redactSensitiveValue('businessId', 'biz-1'), 'biz-1');
      expect(redactSensitiveValue('lastError', 'network'), 'network');
    });

    test('redactMap deep-redacts nested maps', () {
      final out = redactMap({
        'entityType': 'sales',
        'payload': {'uuid': 'sale-1', 'accessToken': 'must-not-appear'},
      });
      expect(out['entityType'], 'sales');
      final payload = out['payload'] as Map<String, dynamic>;
      expect(payload['uuid'], 'sale-1');
      expect(payload['accessToken'], '<redacted>');
    });
  });
}
