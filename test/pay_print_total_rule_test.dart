import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/features/pos_order/pay_print_total_rule.dart';

void main() {
  group('shouldAddPaymentToPrintTotal', () {
    test('new order + PAGUAJ without PRINTO adds to total', () {
      expect(
        shouldAddPaymentToPrintTotal(
          tableOccupied: false,
          hasPrintedOrderLines: false,
          hasUnprintedCartLines: true,
        ),
        isTrue,
      );
    });

    test('open printed table + PAGUAJ does not add again', () {
      expect(
        shouldAddPaymentToPrintTotal(
          tableOccupied: true,
          hasPrintedOrderLines: true,
          hasUnprintedCartLines: false,
        ),
        isFalse,
      );
    });

    test('occupied table does not add even if cart has lines', () {
      expect(
        shouldAddPaymentToPrintTotal(
          tableOccupied: true,
          hasPrintedOrderLines: true,
          hasUnprintedCartLines: true,
        ),
        isFalse,
      );
    });

    test('empty new table does not add', () {
      expect(
        shouldAddPaymentToPrintTotal(
          tableOccupied: false,
          hasPrintedOrderLines: false,
          hasUnprintedCartLines: false,
        ),
        isFalse,
      );
    });
  });
}
