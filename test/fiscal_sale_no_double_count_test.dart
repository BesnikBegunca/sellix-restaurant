import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_system/services/database_service.dart';

/// KUPON FISKAL records the sale, so it must also settle the table.
///
/// These tests pin down *why*: the payment uuid stops being reused the moment
/// a sale exists for it, so an open table would let PAGUAJ record the same
/// items a second time. The button clears the table to close that hole.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService db;

  setUpAll(() async {
    // One database for the group: DatabaseService is a singleton and keeps the
    // path it first opened.
    final dir = await Directory.systemTemp.createTemp('pos_fiscal_settle');
    await databaseFactory.setDatabasesPath(dir.path);
    db = DatabaseService.instance;
  });

  List<Map<String, dynamic>> saleLines() => [
        {
          'productId': 'makiato',
          'productName': 'Makiato',
          'productEmoji': '☕',
          'productPrice': 1.50,
          'quantity': 2,
          'lineTotal': 3.00,
        },
      ];

  List<Map<String, dynamic>> orderLines() => [
        {
          'productId': 'makiato',
          'productName': 'Makiato',
          'productPrice': 1.50,
          'productEmoji': '☕',
          'imagePath': null,
          'qty': 2,
        },
      ];

  test('the payment uuid is not reused once a sale exists for it', () async {
    const tableId = 4;
    const waiter = 'uuid-case';

    final first = await db.resolvePaymentSaleUuid(
      tableId: tableId,
      waiterName: waiter,
    );
    // Stable while nothing has been sold — this is the idempotency guard that
    // protects a double tap on PAGUAJ.
    expect(
      await db.resolvePaymentSaleUuid(tableId: tableId, waiterName: waiter),
      first,
    );

    await db.insertSaleWithLines(
      saleUuid: first,
      waiterName: waiter,
      tableId: tableId,
      total: 3.00,
      lines: saleLines(),
    );

    final second = await db.resolvePaymentSaleUuid(
      tableId: tableId,
      waiterName: waiter,
    );
    expect(
      second,
      isNot(first),
      reason: 'a fresh uuid here is exactly what would double-count the sale '
          'if the fiscal coupon left the table open',
    );
  });

  test('clearing the pending uuid and the order settles the table', () async {
    const tableId = 9;
    const waiter = 'settle-case';

    await db.upsertCurrentOrderMeta(
      tableId: tableId,
      waiterName: waiter,
      orderNumber: 1,
      currentTotal: 3.00,
    );
    await db.replaceCurrentOrderLines(tableId, waiter, orderLines());
    expect(await db.fetchCurrentOrderLines(tableId, waiter), isNotEmpty);

    final uuid = await db.resolvePaymentSaleUuid(
      tableId: tableId,
      waiterName: waiter,
    );
    await db.insertSaleWithLines(
      saleUuid: uuid,
      waiterName: waiter,
      tableId: tableId,
      total: 3.00,
      lines: saleLines(),
    );

    // What clearTable() does to the payment state.
    await db.clearPendingPaymentSaleUuid(tableId, waiter);
    await db.clearCurrentOrder(tableId, waiter, clearPrintHistory: false);

    expect(
      await db.getPendingPaymentSaleUuid(tableId, waiter),
      anyOf(isNull, isEmpty),
    );
    expect(await db.fetchCurrentOrderLines(tableId, waiter), isEmpty);
    expect(await db.fetchCurrentOrderMeta(tableId, waiter), isNull);

    // Exactly one sale for that uuid — the coupon and the books agree.
    expect(await db.fetchSaleIdByUuid(uuid), isNotNull);
  });
}
