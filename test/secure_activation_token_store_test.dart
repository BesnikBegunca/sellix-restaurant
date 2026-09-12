import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/services/secure_activation_token_store.dart';

void main() {
  group('SecureActivationTokenStore', () {
    test('legacy app_meta keys are defined for migration', () {
      expect(
        SecureActivationTokenStore.legacyAccessTokenKey,
        'activation_access_token',
      );
      expect(
        SecureActivationTokenStore.legacyRefreshTokenKey,
        'activation_refresh_token',
      );
    });

    test('storageLabel describes OS-backed storage', () {
      expect(SecureActivationTokenStore.storageLabel, contains('Secure'));
    });
  });
}
