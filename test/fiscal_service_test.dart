import 'package:flutter_test/flutter_test.dart';

import 'package:pos_system/models/mock_data.dart';
import 'package:pos_system/models/pos_models.dart';
import 'package:pos_system/services/fiscal/fiscal_models.dart';
import 'package:pos_system/services/fiscal/fiscal_service.dart';
import 'package:pos_system/services/fiscal/fiscal_settings.dart';

ProductItem _p(String name, double price) => ProductItem(
      id: name,
      name: name,
      price: price,
      emoji: '☕',
    );

void main() {
  group('VAT split', () {
    test('extracts VAT from a gross total when prices include VAT', () {
      // €11.80 gross at 18% → €1.80 VAT, €10.00 net.
      final r = FiscalService.splitVat(
        amountCents: 1180,
        rate: FiscalTaxRate.e,
        pricesIncludeVat: true,
      );
      expect(r.total, 1180);
      expect(r.tax, 180);
      expect(r.totalForTax, 1180);
      expect(r.total - r.tax, 1000);
    });

    test('adds VAT on top when prices exclude it', () {
      final r = FiscalService.splitVat(
        amountCents: 1000,
        rate: FiscalTaxRate.e,
        pricesIncludeVat: false,
      );
      expect(r.tax, 180);
      expect(r.total, 1180);
      expect(r.totalForTax, 1180);
    });

    test('a 0% rate produces no tax either way', () {
      for (final inclusive in [true, false]) {
        final r = FiscalService.splitVat(
          amountCents: 500,
          rate: FiscalTaxRate.c,
          pricesIncludeVat: inclusive,
        );
        expect(r.tax, 0);
        expect(r.total, 500);
      }
    });

    test('8% rate, VAT inclusive', () {
      // €10.80 gross at 8% → €0.80 VAT.
      final r = FiscalService.splitVat(
        amountCents: 1080,
        rate: FiscalTaxRate.d,
        pricesIncludeVat: true,
      );
      expect(r.tax, 80);
      expect(r.total - r.tax, 1000);
    });
  });

  group('coupon building', () {
    const settings = FiscalSettings(
      enabled: true,
      businessId: 12345678910,
      branchId: 1,
      posId: 1,
      applicationId: 807105964528,
      location: 'Kacanik',
      taxRate: FiscalTaxRate.e,
      pricesIncludeVat: true,
      privateKeyPem: 'x',
    );

    final lines = [
      CurrentOrderLine(product: _p('Makiato', 1.50), qty: 2),
      CurrentOrderLine(product: _p('Uje', 0.50), qty: 1),
    ];

    test('totals, units and tax groups line up', () {
      final c = FiscalService.instance.buildCoupons(
        settings: settings,
        lines: lines,
        couponId: 7,
        verificationNo: '0000070000000001',
        operatorId: 'besnik',
        issuedAt: DateTime.utc(2026, 9, 24, 10, 0, 0),
      );

      // 2 × 1.50 + 1 × 0.50 = €3.50 = 350 cents.
      expect(c.pos.total, 350);
      expect(c.pos.items.length, 2);

      // Unit price uses ATK's €0.0001 scale, line total uses cents.
      expect(c.pos.items[0].price, 15000);
      expect(c.pos.items[0].total, 300);
      expect(c.pos.items[0].quantity, 2.0);
      expect(c.pos.items[1].price, 5000);
      expect(c.pos.items[1].total, 50);

      // 18% contained in €3.50 → €0.53.
      expect(c.pos.totalTax, 53);
      expect(c.pos.totalNoTax, 297);
      expect(c.pos.totalTax + c.pos.totalNoTax, c.pos.total);

      expect(c.pos.taxGroups.single.taxRate, 'E');
      expect(c.pos.taxGroups.single.totalForTax, 350);
      expect(c.pos.taxGroups.single.totalTax, 53);

      // The payment covers the whole coupon.
      expect(c.pos.payments.single.amount, 350);
      expect(c.pos.payments.single.type, FiscalPaymentType.cash);
    });

    test('citizen coupon mirrors the POS coupon on every shared field', () {
      final c = FiscalService.instance.buildCoupons(
        settings: settings,
        lines: lines,
        couponId: 7,
        verificationNo: '0000070000000001',
        operatorId: 'besnik',
        issuedAt: DateTime.utc(2026, 9, 24, 10, 0, 0),
      );

      // ATK marks the coupon FAILED VERIFICATION if any of these differ.
      expect(c.citizen.businessId, c.pos.businessId);
      expect(c.citizen.couponId, c.pos.couponId);
      expect(c.citizen.branchId, c.pos.branchId);
      expect(c.citizen.posId, c.pos.posId);
      expect(c.citizen.verificationNo, c.pos.verificationNo);
      expect(c.citizen.type, c.pos.type);
      expect(c.citizen.time, c.pos.time);
      expect(c.citizen.total, c.pos.total);
      expect(c.citizen.totalTax, c.pos.totalTax);
      expect(c.citizen.totalNoTax, c.pos.totalNoTax);
      expect(c.citizen.taxGroups.single.totalForTax,
          c.pos.taxGroups.single.totalForTax);
    });

    test('time is a unix timestamp in seconds', () {
      final issuedAt = DateTime.utc(2026, 9, 24, 10, 0, 0);
      final c = FiscalService.instance.buildCoupons(
        settings: settings,
        lines: lines,
        couponId: 1,
        verificationNo: 'v',
        operatorId: 'o',
        issuedAt: issuedAt,
      );
      expect(c.pos.time, issuedAt.millisecondsSinceEpoch ~/ 1000);
    });
  });
}
