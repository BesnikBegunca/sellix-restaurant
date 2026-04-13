import 'package:flutter_test/flutter_test.dart';

import 'package:pos_system/main.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PosSystemApp());
    expect(find.text('POS System'), findsOneWidget);
    expect(find.text('Enter PIN'), findsOneWidget);
  });
}
