import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/services/supported_sync_entity_types.dart';

void main() {
  group('isSupportedSyncEntityType', () {
    test('accepts pos_api supported types including printed_orders', () {
      expect(supportedSyncEntityTypes, contains('printed_orders'));
      for (final type in supportedSyncEntityTypes) {
        expect(isSupportedSyncEntityType(type), isTrue);
        expect(isSupportedSyncEntityType(type.toUpperCase()), isTrue);
        expect(isSupportedSyncEntityType(type.replaceAll('_', '-')), isTrue);
      }
    });

    test('rejects unsupported types', () {
      const blocked = [
        'current_orders',
        'current_order_lines',
        'kitchen_prints',
        'kitchen_print_lines',
        'waiters',
        'waiter_salaries',
        'advances',
        'waiter_worked_days',
      ];
      for (final type in blocked) {
        expect(isSupportedSyncEntityType(type), isFalse);
      }
    });
  });
}
