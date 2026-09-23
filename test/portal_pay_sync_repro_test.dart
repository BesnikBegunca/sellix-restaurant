import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pos_system/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Printo → Paguaj must leave the portal outbox holding a PAID invoice,
/// and the floor snapshot must report the table as free.
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

  test('Printo then Paguaj queues a paid invoice', () async {
    const tableId = 3;
    const waiter = 'Kamarieri';
    final db = DatabaseService.instance;
    final printLines = [
      {
        'productId': 'p1',
        'productName': 'Espresso',
        'productPrice': 1.0,
        'productEmoji': '☕',
        'imagePath': null,
        'qty': 2,
        'lineTotal': 2.0,
      },
    ];

    // ── PRINTO ─────────────────────────────────────────────────────────────
    await db.updateTable(
      tableId,
      occupied: true,
      currentTotal: 2.0,
      assignedWaiterName: waiter,
      currentOrderNumber: 11,
    );
    await db.insertKitchenPrint(
      tableId: tableId,
      waiterName: waiter,
      orderNumber: 11,
      lines: printLines,
    );

    var pending = await db.fetchUnsyncedPortalSales();
    // ignore: avoid_print
    print('AFTER PRINTO -> ${pending.map((e) => '${e['saleUid']}:${e['status']}:${e['total']}').toList()}');
    expect(pending.length, 1, reason: 'print should queue one open invoice');
    expect(pending.first['status'], 'open');
    final openUid = pending.first['saleUid'] as String;
    await db.markPortalSalesSynced([openUid]);
    await db.settlePortalSyncedOutbox();
    // ignore: avoid_print
    print('AFTER PRINT SYNCED -> ${(await db.fetchUnsyncedPortalSales()).length} pending');

    // ── PAGUAJ ─────────────────────────────────────────────────────────────
    final payUid = await db.resolvePaymentSaleUuid(
      tableId: tableId,
      waiterName: waiter,
    );
    // ignore: avoid_print
    print('PAY uid=$payUid (print uid was $openUid)');
    final result = await db.insertSaleWithLines(
      saleUuid: payUid,
      waiterName: waiter,
      tableId: tableId,
      total: 2.0,
      lines: [
        {
          'productId': 'p1',
          'productName': 'Espresso',
          'productPrice': 1.0,
          'quantity': 2,
          'lineTotal': 2.0,
          'categoryName': 'Kafe',
        },
      ],
      orderNumber: 11,
      tableName: 'Tavolina $tableId',
    );
    // ignore: avoid_print
    print('sale saved id=${result.saleId} wasExisting=${result.wasExisting}');

    pending = await db.fetchUnsyncedPortalSales();
    // ignore: avoid_print
    print('AFTER PAGUAJ -> ${pending.map((e) => '${e['saleUid']}:${e['status']}:${e['total']}').toList()}');
    final paid = pending.where((e) => e['status'] == 'paid').toList();
    expect(paid.length, 1, reason: 'payment must queue exactly one paid invoice');
    expect(paid.first['saleUid'], payUid);

    // ── table freed (clearTable) ───────────────────────────────────────────
    await db.updateTable(
      tableId,
      occupied: false,
      currentTotal: null,
      assignedWaiterName: null,
      currentOrderNumber: 11,
    );
    await db.clearCurrentOrder(tableId, waiter, clearPrintHistory: false);
    final snapshot = await db.fetchPortalTableSnapshot();
    final t3 = snapshot.firstWhere((t) => t['tableName'] == 'Tavolina 3');
    // ignore: avoid_print
    print('TABLE SNAPSHOT -> $t3');
    expect(t3['occupied'], false, reason: 'table must be reported free');

    final after = await db.fetchUnsyncedPortalSales();
    // ignore: avoid_print
    print('AFTER CLEAR -> ${after.map((e) => '${e['saleUid']}:${e['status']}').toList()}');
  });
}
