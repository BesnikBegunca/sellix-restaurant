import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_system/main.dart';
import 'package:pos_system/services/activation_state_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('Login screen renders when activated', (
    WidgetTester tester,
  ) async {
    ActivationStateController.instance.setActivated(true);
    await tester.pumpWidget(const PosSystemApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Shkruaj PIN'), findsOneWidget);
  });
}
