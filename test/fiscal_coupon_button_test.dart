import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_system/features/pos_order/widgets/cart_line.dart';
import 'package:pos_system/features/pos_order/widgets/fiscal_coupon_button.dart';
import 'package:pos_system/features/pos_order/widgets/order_panel.dart';
import 'package:pos_system/models/mock_data.dart';

/// The waiter printed 5€ on table 1 earlier, walks away, and comes back when
/// the customers get up. There is nothing new to add, but the coupon must
/// still be issuable — unlike PRINTO, which needs new items.
void main() {
  Widget host({
    required List<CartLine> lines,
    required bool canIssueFiscalCoupon,
    required VoidCallback onIssue,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 900,
          child: OrderPanel(
            tableNumber: 1,
            orderNumber: 1,
            lines: lines,
            total: 5.00,
            onDelta: (_, _) {},
            onSend: () {},
            onPay: () {},
            onIssueFiscalCoupon: onIssue,
            canIssueFiscalCoupon: canIssueFiscalCoupon,
            showFiscalCouponButton: true,
          ),
        ),
      ),
    );
  }

  testWidgets('issues a coupon for an open bill with no new items',
      (tester) async {
    var issued = 0;
    await tester.pumpWidget(
      host(
        lines: const [],
        canIssueFiscalCoupon: true,
        onIssue: () => issued++,
      ),
    );

    expect(find.byType(FiscalCouponButton), findsOneWidget);
    await tester.tap(find.byType(FiscalCouponButton));
    await tester.pump();
    expect(issued, 1);
  });

  testWidgets('stays inert on an empty table with nothing owed',
      (tester) async {
    var issued = 0;
    await tester.pumpWidget(
      host(
        lines: const [],
        canIssueFiscalCoupon: false,
        onIssue: () => issued++,
      ),
    );

    await tester.tap(find.byType(FiscalCouponButton));
    await tester.pump();
    expect(issued, 0);
  });

  testWidgets('issues a coupon for new items too', (tester) async {
    var issued = 0;
    await tester.pumpWidget(
      host(
        lines: [
          CartLine(
            product: const ProductItem(
              id: 'makiato',
              name: 'Makiato',
              price: 1.50,
              emoji: '☕',
            ),
          ),
        ],
        canIssueFiscalCoupon: true,
        onIssue: () => issued++,
      ),
    );

    await tester.tap(find.byType(FiscalCouponButton));
    await tester.pump();
    expect(issued, 1);
  });

  testWidgets('the button is absent when fiscalisation is off',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 900,
            child: OrderPanel(
              tableNumber: 1,
              orderNumber: 1,
              lines: const [],
              total: 5.00,
              onDelta: (_, _) {},
              onSend: () {},
              onPay: () {},
              onIssueFiscalCoupon: () {},
              canIssueFiscalCoupon: true,
              // showFiscalCouponButton defaults to false
            ),
          ),
        ),
      ),
    );

    expect(find.byType(FiscalCouponButton), findsNothing);
  });
}
