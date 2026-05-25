import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/services/printed_order_sync_payload.dart';
import 'package:pos_system/services/supported_sync_entity_types.dart';
import 'package:pos_system/services/sync_push_payload_mapper.dart';

void main() {
  const kitchenPrintUuid = '550e8400-e29b-41d4-a716-446655440099';
  const saleUuid = '660e8400-e29b-41d4-a716-446655440010';

  group('PrintedOrderSyncPayload', () {
    test('create payload matches PRINTO contract', () {
      final payload = PrintedOrderSyncPayload.create(
        uuid: kitchenPrintUuid,
        orderNumber: 6,
        tableId: 1,
        waiterName: 'Urim',
        total: 3.0,
        itemsCount: 1,
        printedAt: '2026-05-25T12:34:56.789Z',
      );
      expect(payload['status'], 'printed');
      expect(payload['uuid'], kitchenPrintUuid);
      expect(payload['orderNumber'], 6);
      expect(payload['tableName'], 'Tavolina 1');
      expect(payload.containsKey('saleUuid'), isFalse);
    });

    test('paidUpdate uses same uuid and does not create new entity fields', () {
      final payload = PrintedOrderSyncPayload.paidUpdate(
        uuid: kitchenPrintUuid,
        saleUuid: saleUuid,
      );
      expect(payload.keys.toList(), ['uuid', 'status', 'saleUuid']);
      expect(payload['uuid'], kitchenPrintUuid);
      expect(payload['status'], 'paid');
      expect(payload['saleUuid'], saleUuid);
    });

    test('itemsCountFromLines sums qty', () {
      expect(
        PrintedOrderSyncPayload.itemsCountFromLines([
          {'qty': 2},
          {'qty': 3},
        ]),
        5,
      );
    });
  });

  group('printed_orders lifecycle via SyncPushPayloadMapper', () {
    test('create maps full printed row', () {
      final raw = PrintedOrderSyncPayload.create(
        uuid: kitchenPrintUuid,
        orderNumber: 6,
        tableId: 1,
        waiterName: 'Urim',
        total: 3.0,
        itemsCount: 1,
        printedAt: '2026-05-25T12:34:56.789Z',
      );
      final out = SyncPushPayloadMapper.mapPayload('printed_orders', raw);
      expect(out['status'], 'printed');
      expect(out['uuid'], kitchenPrintUuid);
      expect(out['orderNumber'], 6);
    });

    test('paid update maps minimal lifecycle payload only', () {
      final raw = PrintedOrderSyncPayload.paidUpdate(
        uuid: kitchenPrintUuid,
        saleUuid: saleUuid,
      );
      final out = SyncPushPayloadMapper.mapPayload('printed_orders', raw);
      expect(out.keys.toList(), ['uuid', 'status', 'saleUuid']);
      expect(out['uuid'], kitchenPrintUuid);
      expect(out['status'], 'paid');
      expect(out['saleUuid'], saleUuid);
    });

    test('payment update preserves same uuid as create', () {
      final createUuid = PrintedOrderSyncPayload.create(
        uuid: kitchenPrintUuid,
        orderNumber: 6,
        tableId: 1,
        waiterName: 'Urim',
        total: 3.0,
        itemsCount: 1,
        printedAt: '2026-05-25T12:34:56.789Z',
      )['uuid'];
      final paidUuid = PrintedOrderSyncPayload.paidUpdate(
        uuid: kitchenPrintUuid,
        saleUuid: saleUuid,
      )['uuid'];
      expect(createUuid, paidUuid);
      expect(createUuid, kitchenPrintUuid);
    });
  });

  group('printed_orders vs sales (revenue isolation)', () {
    test('printed_orders is supported for sync', () {
      expect(isSupportedSyncEntityType('printed_orders'), isTrue);
    });

    test('sales payload still defaults to completed financial record', () {
      final out = SyncPushPayloadMapper.mapPayload('sales', {
        'total': 3.0,
        'timestamp': '2026-05-25T12:00:00.000Z',
      });
      expect(out['status'], 'completed');
      expect(out['total'], 3.0);
    });

    test('printed_orders paid update does not include sale total fields', () {
      final out = SyncPushPayloadMapper.mapPayload(
        'printed_orders',
        PrintedOrderSyncPayload.paidUpdate(
          uuid: kitchenPrintUuid,
          saleUuid: saleUuid,
        ),
      );
      expect(out.containsKey('total'), isFalse);
      expect(out.containsKey('soldAt'), isFalse);
    });
  });
}
