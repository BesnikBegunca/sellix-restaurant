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

    test('sales converts local ISO without Z to UTC soldAt', () {
      final local = DateTime(2026, 5, 20, 14, 35);
      final out = SyncPushPayloadMapper.mapPayload('sales', {
        'total': 10.0,
        'timestamp': local.toIso8601String(),
      });
      expect(out['soldAt'], local.toUtc().toIso8601String());
      expect(out['soldAt'] as String, endsWith('Z'));
    });

    test('sales keeps valid UTC soldAt unchanged', () {
      const utc = '2026-05-20T12:35:00.000Z';
      final out = SyncPushPayloadMapper.mapPayload('sales', {
        'soldAt': utc,
        'total': 5.0,
      });
      expect(out['soldAt'], utc);
    });

    test('sales preserves order metadata in push payload', () {
      final out = SyncPushPayloadMapper.mapPayload('sales', {
        'total': 25.5,
        'timestamp': '2026-05-19T12:00:00.000Z',
        'tableId': 3,
        'tableName': 'Tavolina 3',
        'waiterName': 'Arta',
        'orderNumber': 152,
      });
      expect(out['tableId'], 3);
      expect(out['tableName'], 'Tavolina 3');
      expect(out['waiterName'], 'Arta');
      expect(out['orderNumber'], 152);
      expect(out['soldAt'], '2026-05-19T12:00:00.000Z');
      expect(out['status'], 'completed');
    });

    test('sales normalizes snake_case order metadata aliases', () {
      final out = SyncPushPayloadMapper.mapPayload('sales', {
        'total': 10.0,
        'timestamp': '2026-05-19T12:00:00.000Z',
        'table_id': 5,
        'table_name': 'Tavolina 5',
        'waiter_name': 'Blend',
        'order_number': 99,
      });
      expect(out['tableId'], 5);
      expect(out['tableName'], 'Tavolina 5');
      expect(out['waiterName'], 'Blend');
      expect(out['orderNumber'], 99);
      expect(out.containsKey('table_id'), isFalse);
      expect(out.containsKey('waiter_name'), isFalse);
    });

    test('sale_lines strips order metadata from push payload', () {
      final out = SyncPushPayloadMapper.mapPayload('sale_lines', {
        'saleUuid': '550e8400-e29b-41d4-a716-446655440010',
        'productPrice': 5.5,
        'quantity': 1,
        'lineTotal': 5.5,
        'tableId': 1,
        'tableName': 'Tavolina 1',
        'waiterName': 'John Smith',
      });
      expect(out.containsKey('tableId'), isFalse);
      expect(out.containsKey('tableName'), isFalse);
      expect(out.containsKey('waiterName'), isFalse);
    });

    test('printed_orders maps expected open-order fields', () {
      final out = SyncPushPayloadMapper.mapPayload('printed_orders', {
        'uuid': '550e8400-e29b-41d4-a716-446655440099',
        'orderNumber': 6,
        'tableId': 1,
        'tableName': 'Tavolina 1',
        'waiterName': 'Urim',
        'total': 3.0,
        'itemsCount': 1,
        'printedAt': '2026-05-25T10:00:00.000Z',
        'businessId': 'local-business',
        'id': 42,
      });
      expect(out['uuid'], '550e8400-e29b-41d4-a716-446655440099');
      expect(out['orderNumber'], 6);
      expect(out['tableId'], 1);
      expect(out['tableName'], 'Tavolina 1');
      expect(out['waiterName'], 'Urim');
      expect(out['total'], 3.0);
      expect(out['itemsCount'], 1);
      expect(out['status'], 'printed');
      expect(out['printedAt'], '2026-05-25T10:00:00.000Z');
      expect(out.containsKey('businessId'), isFalse);
      expect(out.containsKey('id'), isFalse);
    });

    test('printed_orders converts local printedAt to UTC', () {
      final local = DateTime(2026, 5, 25, 14, 0);
      final out = SyncPushPayloadMapper.mapPayload('printed_orders', {
        'uuid': '550e8400-e29b-41d4-a716-446655440099',
        'orderNumber': 1,
        'tableId': 1,
        'total': 1.0,
        'itemsCount': 1,
        'printedAt': local.toIso8601String(),
      });
      expect(out['printedAt'], local.toUtc().toIso8601String());
      expect(out['printedAt'] as String, endsWith('Z'));
    });

    test('printed_orders paid lifecycle update is minimal', () {
      final out = SyncPushPayloadMapper.mapPayload('printed_orders', {
        'uuid': '550e8400-e29b-41d4-a716-446655440099',
        'status': 'paid',
        'saleUuid': '660e8400-e29b-41d4-a716-446655440010',
      });
      expect(out.keys.toList(), ['uuid', 'status', 'saleUuid']);
      expect(out['uuid'], '550e8400-e29b-41d4-a716-446655440099');
      expect(out['status'], 'paid');
      expect(out['saleUuid'], '660e8400-e29b-41d4-a716-446655440010');
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
