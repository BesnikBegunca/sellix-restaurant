import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pos_system/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A table that was opened, paid and freed must print again on the next visit.
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

  const tableId = 3;
  const waiter = 'Kamarieri';
  List<Map<String, dynamic>> lines(double price, int qty) => [
        {
          'productId': 'p1',
          'productName': 'Espresso',
          'productPrice': price,
          'productEmoji': '☕',
          'imagePath': null,
          'qty': qty,
          'lineTotal': price * qty,
        },
      ];

  Future<void> printo(double price, int qty, int orderNumber) async {
    final db = DatabaseService.instance;
    await db.updateTable(
      tableId,
      occupied: true,
      currentTotal: price * qty,
      assignedWaiterName: waiter,
      currentOrderNumber: orderNumber,
    );
    final printId = await db.insertKitchenPrint(
      tableId: tableId,
      waiterName: waiter,
      orderNumber: orderNumber,
      lines: lines(price, qty),
    );
    // ignore: avoid_print
    print('  printo #$orderNumber -> printId=$printId');
    expect(printId, greaterThan(0), reason: 'Printo must record a kitchen print');
  }

  Future<void> paguaj(double total, int orderNumber) async {
    final db = DatabaseService.instance;
    final uid = await db.resolvePaymentSaleUuid(tableId: tableId, waiterName: waiter);
    final res = await db.insertSaleWithLines(
      saleUuid: uid,
      waiterName: waiter,
      tableId: tableId,
      total: total,
      lines: [
        {
          'productId': 'p1',
          'productName': 'Espresso',
          'productPrice': 1.0,
          'quantity': total.round(),
          'lineTotal': total,
          'categoryName': 'Kafe',
        },
      ],
      orderNumber: orderNumber,
      tableName: 'Tavolina $tableId',
    );
    // ignore: avoid_print
    print('  paguaj -> uid=$uid saleId=${res.saleId} wasExisting=${res.wasExisting}');
    // clearTable
    await db.clearPendingPaymentSaleUuid(tableId, waiter);
    await db.updateTable(
      tableId,
      occupied: false,
      currentTotal: null,
      assignedWaiterName: null,
      currentOrderNumber: orderNumber,
    );
    await db.clearCurrentOrder(tableId, waiter, clearPrintHistory: false);
  }

  test('second visit on the same table still prints and syncs', () async {
    final db = DatabaseService.instance;

    // ── visit 1 ────────────────────────────────────────────────────────────
    await printo(1.0, 2, 1);
    var pending = await db.fetchUnsyncedPortalSales();
    // ignore: avoid_print
    print('visit 1 pending: ${pending.map((e) => '${e['saleUid']}:${e['status']}:${e['total']}').toList()}');
    expect(pending.length, 1);
    await db.markPortalSalesSynced([pending.first['saleUid'] as String]);
    await db.settlePortalSyncedOutbox();

    await paguaj(2.0, 1);
    pending = await db.fetchUnsyncedPortalSales();
    // ignore: avoid_print
    print('after paguaj pending: ${pending.map((e) => '${e['saleUid']}:${e['status']}:${e['total']}').toList()}');
    await db.markPortalSalesSynced(pending.map((e) => e['saleUid'] as String).toList());
    await db.settlePortalSyncedOutbox();

    // ── visit 2 on the same table ──────────────────────────────────────────
    await printo(1.5, 2, 2);
    pending = await db.fetchUnsyncedPortalSales();
    // ignore: avoid_print
    print('visit 2 pending: ${pending.map((e) => '${e['saleUid']}:${e['status']}:${e['total']}').toList()}');
    final open = pending.where((e) => e['status'] == 'open').toList();
    expect(open.length, 1, reason: 'the new visit must queue its own open invoice');
    expect(open.first['total'], 3.0, reason: 'it must carry the new visit total, not the old one');

    // ── and it must be payable again ───────────────────────────────────────
    await db.markPortalSalesSynced([open.first['saleUid'] as String]);
    await db.settlePortalSyncedOutbox();
    await paguaj(3.0, 2);
    pending = await db.fetchUnsyncedPortalSales();
    // ignore: avoid_print
    print('visit 2 after paguaj: ${pending.map((e) => '${e['saleUid']}:${e['status']}:${e['total']}').toList()}');
    final paid = pending.where((e) => e['status'] == 'paid').toList();
    expect(paid.length, 1, reason: 'second payment must queue a paid invoice');
    expect(paid.first['total'], 3.0);
  });
}
