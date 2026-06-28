import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pos_system/models/open_tables_summary.dart';
import 'package:pos_system/models/tenant_activation_gate_result.dart';
import 'package:pos_system/models/tenant_data_conflict.dart';
import 'package:pos_system/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService.instance.closeDatabase();
    final dbPath = p.join(await getDatabasesPath(), 'pos_system.db');
    await deleteDatabase(dbPath);
    await DatabaseService.instance.database;
    await DatabaseService.instance.ensureDefaultTables();
  });

  tearDown(() async {
    await DatabaseService.instance.closeDatabase();
  });

  Future<void> seedOpenOrder({
    required int tableId,
    required String waiterName,
    required double total,
  }) async {
    final db = DatabaseService.instance;
    await db.updateTable(
      tableId,
      occupied: true,
      currentTotal: total,
      assignedWaiterName: waiterName,
      currentOrderNumber: 1,
    );
    await db.upsertCurrentOrderMeta(
      tableId: tableId,
      waiterName: waiterName,
      orderNumber: 1,
      currentTotal: total,
    );
    await db.replaceCurrentOrderLines(tableId, waiterName, [
      {
        'productId': 'p1',
        'productName': 'Kafe',
        'productPrice': total,
        'productEmoji': '☕',
        'imagePath': null,
        'qty': 1,
      },
    ]);
  }

  group('open tables activation helpers', () {
    test('getOpenTablesSummary counts orders and totals', () async {
      await seedOpenOrder(tableId: 2, waiterName: 'Ana', total: 12.5);
      await seedOpenOrder(tableId: 5, waiterName: 'Beni', total: 7.0);

      final summary = await DatabaseService.instance.getOpenTablesSummary();
      expect(summary.count, 2);
      expect(summary.totalAmount, 19.5);
    });

    test('closeOpenTablesSafely converts open orders to completed_local sales', () async {
      await seedOpenOrder(tableId: 3, waiterName: 'Ana', total: 15.0);

      await DatabaseService.instance.closeOpenTablesSafely();

      expect(await DatabaseService.instance.hasAnyOpenTableBusiness(), isFalse);

      final db = await DatabaseService.instance.database;
      final sales = await db.query('sales');
      expect(sales, hasLength(1));
      expect(sales.first['total'], 15.0);
      expect(sales.first['status'], 'completed_local');
      expect(
        sales.first['closeReason'],
        DatabaseService.activationResetCloseReason,
      );
      expect(sales.first['closedAt'], isNotNull);

      final lines = await db.query('sale_lines');
      expect(lines, hasLength(1));
      expect(lines.first['lineTotal'], 15.0);
    });

    test('archiveClosedOrdersBeforeReset preserves sales before wipe', () async {
      await seedOpenOrder(tableId: 4, waiterName: 'Ana', total: 9.0);
      await DatabaseService.instance.closeOpenTablesSafely();

      await DatabaseService.instance.archiveClosedOrdersBeforeReset();
      await DatabaseService.instance.clearLocalBusinessData(
        skipOpenTableCheck: true,
      );

      final db = await DatabaseService.instance.database;
      final archivedOrders = await db.query('local_archived_orders');
      expect(archivedOrders, isNotEmpty);
      expect(archivedOrders.first['totalAmount'], 9.0);

      final archivedLines = await db.query('local_archived_order_lines');
      expect(archivedLines, isNotEmpty);

      final archivedPayments = await db.query('local_archived_payments');
      expect(archivedPayments, isNotEmpty);

      final liveSales = await db.query('sales');
      expect(liveSales, isEmpty);
    });

    test('clearLocalBusinessData blocks when open tables remain', () async {
      await seedOpenOrder(tableId: 1, waiterName: 'Ana', total: 5.0);

      expect(
        () => DatabaseService.instance.clearLocalBusinessData(),
        throwsStateError,
      );
    });
  });

  group('TenantActivationGateResult openTablesBlocked', () {
    test('blocks activation until resolved', () {
      const conflict = TenantDataConflict(
        newBusinessId: 'b2',
        hasMeaningfulLocalData: true,
        hasForeignScopedData: true,
      );
      final gate = TenantActivationGateResult.openTablesBlocked(
        conflict,
        const OpenTablesSummary(count: 2, totalAmount: 20),
      );
      expect(gate.canProceedToActivation, isFalse);
      expect(gate.action, TenantActivationGateAction.openTablesBlocked);
      expect(gate.openTablesSummary?.count, 2);
    });
  });
}
