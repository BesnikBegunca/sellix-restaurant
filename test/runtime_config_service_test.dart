import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/services/runtime_config_service.dart';

void main() {
  group('RuntimeConfigService.isLocalhostUrl', () {
    test('detects loopback hosts', () {
      expect(
        RuntimeConfigService.isLocalhostUrl('http://127.0.0.1:3000'),
        isTrue,
      );
      expect(
        RuntimeConfigService.isLocalhostUrl('http://localhost:3000'),
        isTrue,
      );
      expect(
        RuntimeConfigService.isLocalhostUrl('http://[::1]:3000'),
        isTrue,
      );
    });

    test('allows production hosts', () {
      expect(
        RuntimeConfigService.isLocalhostUrl(
          'https://posapi-production-a6e7.up.railway.app',
        ),
        isFalse,
      );
    });
  });
}
