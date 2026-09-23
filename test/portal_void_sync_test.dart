import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pos_system/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Refund / delete in the manager dashboard must reach SelliX web as a void,
/// so the amount comes off the bar there too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService.instance.closeDatabase();
    await deleteDatabase(p.join(await getDatabasesPath(), 'pos_system.db'));
    await DatabaseService.instance.database;
    await DatabaseService.instance.ensureDefaultTables();
  });

  tearDown(() async {
    await DatabaseService.instance.closeDatabase();
  });

  const tableId = 2;
  const waiter = 'Kamarieri';
  final printLines = [
    {
      'productId': 'p1',
      'productName': 'Espresso',
      'productPrice': 1.0,
      'productEmoji': '☕',
      'imagePath': null,
      'qty': 4,
      'lineTotal': 4.0,
    },
  ];

  test('deleting a print queues a void for the portal', () async {
    final db = DatabaseService.instance;
    await db.updateTable(
      tableId,
      occupied: true,
      currentTotal: 4.0,
      assignedWaiterName: waiter,
      currentOrderNumber: 7,
    );
    final printId = await db.insertKitchenPrint(
      tableId: tableId,
      waiterName: waiter,
      orderNumber: 7,
      lines: printLines,
    );

    final pending = await db.fetchUnsyncedPortalSales();
    expect(pending.length, 1);
    final uid = pending.first['saleUid'] as String;
    await db.markPortalSalesSynced([uid]);
    await db.settlePortalSyncedOutbox();

    // Manager → Refund → Fshi
    await db.deleteKitchenPrint(printId);

    final voids = await db.fetchUnsyncedPortalVoids();
    // ignore: avoid_print
    print('voids: ${voids.map((v) => '${v['uuid']}:${v['total']}:${v['tableName']}').toList()}');
    expect(voids.length, 1, reason: 'the deleted print must be queued as a void');
    expect(voids.first['uuid'], uid, reason: 'same uid the portal knows');
    expect(voids.first['total'], 4.0);
    expect(voids.first['tableName'], 'Tavolina 2');

    await db.markPortalVoidsSynced([uid]);
    expect((await db.fetchUnsyncedPortalVoids()).isEmpty, true);
  });

  test('deleting a paid sale queues a void for the portal', () async {
    final db = DatabaseService.instance;
    final uid = await db.resolvePaymentSaleUuid(tableId: tableId, waiterName: waiter);
    final sale = await db.insertSaleWithLines(
      saleUuid: uid,
      waiterName: waiter,
      tableId: tableId,
      total: 6.0,
      lines: [
        {
          'productId': 'p1',
          'productName': 'Espresso',
          'productPrice': 1.0,
          'quantity': 6,
          'lineTotal': 6.0,
          'categoryName': 'Kafe',
        },
      ],
      orderNumber: 8,
      tableName: 'Tavolina $tableId',
    );
    final pending = await db.fetchUnsyncedPortalSales();
    await db.markPortalSalesSynced(pending.map((e) => e['saleUid'] as String).toList());
    await db.settlePortalSyncedOutbox();

    await db.deleteSaleById(sale.saleId);

    final voids = await db.fetchUnsyncedPortalVoids();
    // ignore: avoid_print
    print('voids: ${voids.map((v) => '${v['uuid']}:${v['total']}').toList()}');
    expect(voids.length, 1);
    expect(voids.first['uuid'], uid);
    expect(voids.first['total'], 6.0);
  });
}
