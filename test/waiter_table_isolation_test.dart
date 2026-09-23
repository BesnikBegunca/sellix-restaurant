import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_system/manager/manager_data.dart';
import 'package:pos_system/services/database_service.dart';

/// Every waiter has tables 1..N, but table 1 of waiter A and table 1 of waiter B
/// are different orders. A waiter must never read the other one's total.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('current order meta for a table is scoped to the waiter', () async {
    final dir = await Directory.systemTemp.createTemp('pos_waiter_scope');
    await databaseFactory.setDatabasesPath(dir.path);
    final db = DatabaseService.instance;

    await db.upsertCurrentOrderMeta(
      tableId: 1,
      waiterName: 'Arben',
      orderNumber: 11,
      currentTotal: 42.50,
    );
    await db.upsertCurrentOrderMeta(
      tableId: 1,
      waiterName: 'Besnik',
      orderNumber: 12,
      currentTotal: 7.00,
    );

    final arben = await db.fetchCurrentOrderMeta(1, 'Arben');
    final besnik = await db.fetchCurrentOrderMeta(1, 'Besnik');
    final drita = await db.fetchCurrentOrderMeta(1, 'Drita');

    expect(arben!['currentTotal'], 42.50);
    expect(besnik!['currentTotal'], 7.00);
    expect(drita, isNull, reason: 'a waiter with no order sees an empty table');

    final arbenTables = await db.fetchCurrentOrderMetasForWaiter('Arben');
    expect(arbenTables.length, 1);
    expect(arbenTables.single['currentTotal'], 42.50);

    // What PosOrderScreen now reads instead of the shared `tables` row.
    final m = ManagerData.instance;
    final arbenView = await m.waiterTableInfo(1, 'Arben');
    final besnikView = await m.waiterTableInfo(1, 'Besnik');
    final dritaView = await m.waiterTableInfo(1, 'Drita');

    expect(arbenView!.currentTotal, 42.50);
    expect(arbenView.occupied, isTrue);
    expect(besnikView!.currentTotal, 7.00);
    expect(besnikView.currentOrderNumber, 12);
    expect(dritaView, isNull);
  });
}
