import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_system/services/database_service.dart';

/// A fiscal coupon must survive a failed submission: it is printed and handed
/// to the customer regardless, so the row has to exist and be retryable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('fiscal_coupons stores, fails and settles a coupon', () async {
    final dir = await Directory.systemTemp.createTemp('pos_fiscal_store');
    await databaseFactory.setDatabasesPath(dir.path);
    final db = DatabaseService.instance;

    final id = await db.insertFiscalCoupon({
      'couponId': 1,
      'verificationNo': '0000010000000001',
      'businessId': 12345678910,
      'branchId': 1,
      'posId': 1,
      'tableId': 3,
      'waiterName': 'besnik',
      'couponType': 1,
      'issuedAt': DateTime.now().toIso8601String(),
      'total': 350,
      'totalTax': 53,
      'totalNoTax': 297,
      'detailsBase64': 'ZGV0YWlscw==',
      'signature': 'c2ln',
      'qrCode': 'ZGV0YWlscw==|c2ln',
      'status': 'pending',
    });
    expect(id, greaterThan(0));
    expect(await db.countPendingFiscalCoupons(), 1);

    await db.markFiscalCouponFailed(id, 'pa internet');
    final pending = await db.fetchPendingFiscalCoupons();
    expect(pending.single['retryCount'], 1);
    expect(pending.single['lastError'], 'pa internet');
    expect(pending.single['detailsBase64'], 'ZGV0YWlscw==');

    await db.markFiscalCouponSent(id, transactionNo: '987654321');
    expect(await db.countPendingFiscalCoupons(), 0);

    final all = await db.fetchFiscalCoupons();
    expect(all.single['status'], 'sent');
    expect(all.single['transactionNo'], '987654321');
    expect(all.single['lastError'], isNull);
  });

  test('the same coupon number cannot be issued twice for a business',
      () async {
    final dir = await Directory.systemTemp.createTemp('pos_fiscal_unique');
    await databaseFactory.setDatabasesPath(dir.path);
    await DatabaseService.instance.reopenDatabase();
    final db = DatabaseService.instance;

    Map<String, Object?> row(int couponId) => {
          'couponId': couponId,
          'verificationNo': 'v$couponId',
          'businessId': 999,
          'branchId': 1,
          'posId': 1,
          'couponType': 1,
          'issuedAt': DateTime.now().toIso8601String(),
          'total': 100,
          'totalTax': 15,
          'totalNoTax': 85,
          'detailsBase64': 'ZA==',
          'signature': 'cw==',
          'qrCode': 'ZA==|cw==',
          'status': 'pending',
        };

    await db.insertFiscalCoupon(row(42));
    expect(
      () => db.insertFiscalCoupon(row(42)),
      throwsA(anything),
      reason: 'the unique index on (businessId, couponId) must hold',
    );
  });
}
