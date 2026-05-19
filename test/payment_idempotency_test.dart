import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/services/database_service.dart';

void main() {
  group('Payment idempotency helpers', () {
    test('paymentPendingMetaKey is stable per table and waiter', () {
      expect(
        DatabaseService.paymentPendingMetaKey(5, ' Ana '),
        DatabaseService.paymentPendingMetaKey(5, 'Ana'),
      );
      expect(
        DatabaseService.paymentPendingMetaKey(1, 'w1'),
        isNot(DatabaseService.paymentPendingMetaKey(2, 'w1')),
      );
    });
  });
}
