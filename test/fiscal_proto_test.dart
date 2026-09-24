import 'package:flutter_test/flutter_test.dart';

import 'package:pos_system/services/fiscal/fiscal_models.dart';

/// Golden test against the reference payloads published by ATK in
/// github.com/fiskalizimi/pos-csharp. The signature is computed over these
/// exact bytes, so a single wrong field number or a proto3 default that we
/// write when we should skip it would make every coupon fail verification.
void main() {
  const referenceCitizen =
      'CIHI0p4CENIJGAEgATABOJy/w64GQJwOSgYKAUMQwgNKCAoBRBDAAhgaSgkKAUUQmggYvQFQ1wE=';

  const referencePos =
      'CIHI0p4CENIJGAEiCVByaXNodGluZSoJS3VzaHRyaW1pMAE4wMQHQhAxMjM0NTY3ODkwMTIzNDU2'
      'SAFQnL/DrgZaJAoKdWplIHJ1Z292ZRCWARoEY29wZSUAAEBAKMIDMgFDOgJUVFohCgdzZW5kdmlx'
      'EKwCGgRjb3BlJQAAAEAo2AQyAUU6AlRUWh0KBGJ1a2UQUBoEY29wZSUAAIBAKMACMgFEOgJUVFoq'
      'ChBtYWNoaWF0byBlIG1hZGhlEJYBGgRjb3BlJQAAQEAowgMyAUU6AlRUYgUIARD0A2IFCAIQ6Adi'
      'BQgDEMACaJwOcgYKAUMQwgNyCAoBRBDAAhgacgkKAUUQmggYvQF41wGAAcUM';

  const taxGroups = [
    FiscalTaxGroup(taxRate: 'C', totalForTax: 450, totalTax: 0),
    FiscalTaxGroup(taxRate: 'D', totalForTax: 320, totalTax: 26),
    FiscalTaxGroup(taxRate: 'E', totalForTax: 1050, totalTax: 189),
  ];

  test('CitizenCoupon serializes to ATK reference bytes', () {
    const coupon = CitizenCoupon(
      businessId: 601138177,
      couponId: 1234,
      branchId: 1,
      posId: 1,
      verificationNo: '',
      type: FiscalCouponType.sale,
      time: 1708187548,
      total: 1820,
      taxGroups: taxGroups,
      totalTax: 215,
      totalNoTax: 0,
    );

    expect(coupon.toBase64(), referenceCitizen);
  });

  test('PosCoupon serializes to ATK reference bytes', () {
    const coupon = PosCoupon(
      businessId: 601138177,
      couponId: 1234,
      branchId: 1,
      location: 'Prishtine',
      operatorId: 'Kushtrimi',
      posId: 1,
      applicationId: 123456,
      verificationNo: '1234567890123456',
      type: FiscalCouponType.sale,
      time: 1708187548,
      items: [
        FiscalCouponItem(
          name: 'uje rugove',
          price: 150,
          unit: 'cope',
          quantity: 3,
          total: 450,
          taxRate: 'C',
        ),
        FiscalCouponItem(
          name: 'sendviq',
          price: 300,
          unit: 'cope',
          quantity: 2,
          total: 600,
          taxRate: 'E',
        ),
        FiscalCouponItem(
          name: 'buke',
          price: 80,
          unit: 'cope',
          quantity: 4,
          total: 320,
          taxRate: 'D',
        ),
        FiscalCouponItem(
          name: 'machiato e madhe',
          price: 150,
          unit: 'cope',
          quantity: 3,
          total: 450,
          taxRate: 'E',
        ),
      ],
      payments: [
        FiscalPayment(type: FiscalPaymentType.cash, amount: 500),
        FiscalPayment(type: FiscalPaymentType.creditCard, amount: 1000),
        FiscalPayment(type: FiscalPaymentType.voucher, amount: 320),
      ],
      total: 1820,
      taxGroups: taxGroups,
      totalTax: 215,
      totalNoTax: 1605,
    );

    expect(coupon.toBase64(), referencePos);
  });

  test('proto3 defaults are omitted, not written as zero', () {
    // A tax group whose tax is 0 must serialize without field 3 — the "C"
    // group in the reference payload is 6 bytes, not 8.
    const zeroTax = CitizenCoupon(
      businessId: 1,
      couponId: 1,
      branchId: 0,
      posId: 0,
      verificationNo: '',
      type: FiscalCouponType.unknown,
      time: 0,
      total: 0,
      taxGroups: [],
      totalTax: 0,
      totalNoTax: 0,
    );
    // Only businessId and couponId survive: 2 bytes of key + 2 of value.
    expect(zeroTax.toProto().length, 4);
  });
}
