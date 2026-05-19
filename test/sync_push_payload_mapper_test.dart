import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/services/sync_push_payload_mapper.dart';

void main() {
  group('SyncPushPayloadMapper', () {
    test('sale_lines maps productPrice and saleUuid', () {
      final out = SyncPushPayloadMapper.mapPayload('sale_lines', {
        'saleUuid': '550e8400-e29b-41d4-a716-446655440010',
        'productPrice': 5.5,
        'quantity': 2,
        'lineTotal': 11.0,
        'productName': 'Kafe',
        'saleId': 99,
      });
      expect(out['price'], 5.5);
      expect(out['saleUuid'], '550e8400-e29b-41d4-a716-446655440010');
      expect(out['quantity'], 2);
      expect(out['lineTotal'], 11.0);
      expect(out['name'], 'Kafe');
      expect(out.containsKey('saleId'), isFalse);
      expect(out.containsKey('productPrice'), isFalse);
    });

    test('sales maps timestamp to soldAt and default status', () {
      final out = SyncPushPayloadMapper.mapPayload('sales', {
        'total': 42.0,
        'timestamp': '2026-05-19T12:00:00.000Z',
      });
      expect(out['total'], 42.0);
      expect(out['soldAt'], '2026-05-19T12:00:00.000Z');
      expect(out['status'], 'completed');
    });

    test('buildEvent uses exact DTO keys only', () {
      final mapped = SyncPushPayloadMapper.mapPayload('sales', {'total': 10.0});
      final event = SyncPushPayloadMapper.buildEvent(
        row: {
          'uuid': 'event-uuid',
          'entityType': 'sales',
          'entityUuid': 'sale-uuid',
          'operation': 'create',
          'payloadJson': '{"total":10}',
          'businessId': 'biz',
          'deviceId': 'dev',
        },
        payload: mapped,
      );
      expect(event.keys.toList(), [
        'uuid',
        'entityType',
        'entityUuid',
        'operation',
        'payload',
      ]);
      expect(event['payload'], isA<Map<String, dynamic>>());
      expect(event.containsKey('payloadJson'), isFalse);
      expect(event.containsKey('businessId'), isFalse);
    });
  });
}
