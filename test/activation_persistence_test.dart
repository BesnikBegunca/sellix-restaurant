import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/services/activation_service.dart';

void main() {
  group('ActivationService persistence checks', () {
    test('nonEmpty rejects null and blank', () {
      expect(ActivationService.nonEmptyMeta(null), isFalse);
      expect(ActivationService.nonEmptyMeta(''), isFalse);
      expect(ActivationService.nonEmptyMeta('  '), isFalse);
      expect(ActivationService.nonEmptyMeta('biz-1'), isTrue);
    });
  });
}
