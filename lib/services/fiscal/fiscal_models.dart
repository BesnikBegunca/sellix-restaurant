/// Dart mirror of ATK's `models.proto` (github.com/fiskalizimi).
///
/// Field numbers are load-bearing: they were verified byte-for-byte against
/// the reference payloads published in the fiskalizimi readme.
///
/// ## Money units
/// ATK uses two different integer scales, and mixing them up silently produces
/// a coupon that fails verification:
///  * [FiscalCouponItem.price] — unit price in **€0.0001** (€1.00 = 10000)
///  * every other amount — in **cents, €0.01** (€1.00 = 100)
library;

import 'dart:convert';
import 'dart:typed_data';

import 'proto_writer.dart';

enum FiscalCouponType {
  unknown(0),
  sale(1),
  cancel(2),
  returnItems(3);

  const FiscalCouponType(this.wire);
  final int wire;
}

enum FiscalPaymentType {
  unknown(0),
  cash(1),
  creditCard(2),
  voucher(3),
  cheque(4),
  cryptoCurrency(5),
  other(6);

  const FiscalPaymentType(this.wire);
  final int wire;

  static FiscalPaymentType fromWire(int wire) {
    for (final t in FiscalPaymentType.values) {
      if (t.wire == wire) return t;
    }
    return FiscalPaymentType.unknown;
  }
}

/// VAT rate codes accepted by ATK. The letter — not the percentage — goes on
/// the wire.
enum FiscalTaxRate {
  /// Exempt from VAT.
  a('A', 0),
  c('C', 0),
  d('D', 8),
  e('E', 18);

  const FiscalTaxRate(this.code, this.percent);
  final String code;
  final int percent;

  static FiscalTaxRate fromCode(String? code) {
    for (final r in FiscalTaxRate.values) {
      if (r.code == code) return r;
    }
    return FiscalTaxRate.e;
  }

  String get label => percent == 0 && this == FiscalTaxRate.a
      ? 'A — i liruar nga TVSH (0%)'
      : '$code — $percent%';
}

class FiscalCouponItem {
  const FiscalCouponItem({
    required this.name,
    required this.price,
    required this.unit,
    required this.quantity,
    required this.total,
    required this.taxRate,
    this.type = 'TT',
  });

  final String name;

  /// Unit price in €0.0001 units.
  final int price;
  final String unit;
  final double quantity;

  /// Line total in cents.
  final int total;
  final String taxRate;
  final String type;

  void writeTo(ProtoWriter w) {
    w.string(1, name);
    w.int64(2, price);
    w.string(3, unit);
    w.float(4, quantity);
    w.int64(5, total);
    w.string(6, taxRate);
    w.string(7, type);
  }
}

class FiscalPayment {
  const FiscalPayment({required this.type, required this.amount});

  final FiscalPaymentType type;

  /// Amount in cents.
  final int amount;

  void writeTo(ProtoWriter w) {
    w.int64(1, type.wire);
    w.int64(2, amount);
  }
}

class FiscalTaxGroup {
  const FiscalTaxGroup({
    required this.taxRate,
    required this.totalForTax,
    required this.totalTax,
  });

  final String taxRate;

  /// Gross total of all items under this rate, in cents.
  final int totalForTax;

  /// Tax owed for this rate, in cents.
  final int totalTax;

  void writeTo(ProtoWriter w) {
    w.string(1, taxRate);
    w.int64(2, totalForTax);
    w.int64(3, totalTax);
  }
}

/// The full coupon that is sent to ATK and printed for the customer.
class PosCoupon {
  const PosCoupon({
    required this.businessId,
    required this.couponId,
    required this.branchId,
    required this.location,
    required this.operatorId,
    required this.posId,
    required this.applicationId,
    required this.verificationNo,
    required this.type,
    required this.time,
    required this.items,
    required this.payments,
    required this.total,
    required this.taxGroups,
    required this.totalTax,
    required this.totalNoTax,
    this.referenceNo = 0,
    this.transactionNo = 0,
    this.totalDiscount = 0,
  });

  final int businessId;
  final int couponId;
  final int branchId;
  final String location;
  final String operatorId;
  final int posId;
  final int applicationId;
  final String verificationNo;
  final FiscalCouponType type;

  /// Unix timestamp in seconds.
  final int time;
  final List<FiscalCouponItem> items;
  final List<FiscalPayment> payments;
  final int total;
  final List<FiscalTaxGroup> taxGroups;
  final int totalTax;
  final int totalNoTax;
  final int referenceNo;
  final int transactionNo;
  final int totalDiscount;

  Uint8List toProto() {
    final w = ProtoWriter();
    w.int64(1, businessId);
    w.int64(2, couponId);
    w.int64(3, branchId);
    w.string(4, location);
    w.string(5, operatorId);
    w.int64(6, posId);
    w.int64(7, applicationId);
    w.string(8, verificationNo);
    w.int64(9, type.wire);
    w.int64(10, time);
    for (final i in items) {
      w.message(11, i.writeTo);
    }
    for (final p in payments) {
      w.message(12, p.writeTo);
    }
    w.int64(13, total);
    for (final g in taxGroups) {
      w.message(14, g.writeTo);
    }
    w.int64(15, totalTax);
    w.int64(16, totalNoTax);
    w.int64(17, referenceNo);
    w.int64(18, transactionNo);
    w.int64(19, totalDiscount);
    return w.toBytes();
  }

  String toBase64() => base64.encode(toProto());
}

/// The reduced coupon that goes into the printed QR code for the citizen app.
///
/// Its shared fields must match [PosCoupon] exactly or ATK marks the coupon
/// `FAILED VERIFICATION`.
class CitizenCoupon {
  const CitizenCoupon({
    required this.businessId,
    required this.couponId,
    required this.branchId,
    required this.posId,
    required this.verificationNo,
    required this.type,
    required this.time,
    required this.total,
    required this.taxGroups,
    required this.totalTax,
    required this.totalNoTax,
  });

  final int businessId;
  final int couponId;
  final int branchId;
  final int posId;
  final String verificationNo;
  final FiscalCouponType type;
  final int time;
  final int total;
  final List<FiscalTaxGroup> taxGroups;
  final int totalTax;
  final int totalNoTax;

  Uint8List toProto() {
    final w = ProtoWriter();
    w.int64(1, businessId);
    w.int64(2, couponId);
    w.int64(3, branchId);
    w.int64(4, posId);
    w.string(5, verificationNo);
    w.int64(6, type.wire);
    w.int64(7, time);
    w.int64(8, total);
    for (final g in taxGroups) {
      w.message(9, g.writeTo);
    }
    w.int64(10, totalTax);
    w.int64(11, totalNoTax);
    return w.toBytes();
  }

  String toBase64() => base64.encode(toProto());
}
