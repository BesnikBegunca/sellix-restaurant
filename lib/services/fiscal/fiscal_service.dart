import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/pos_models.dart';
import '../database_service.dart';
import 'fiscal_models.dart';
import 'fiscal_settings.dart';
import 'fiscal_signer.dart';

/// Outcome of issuing one fiscal coupon.
@immutable
class FiscalCouponResult {
  const FiscalCouponResult({
    required this.couponId,
    required this.verificationNo,
    required this.qrCode,
    required this.total,
    required this.totalTax,
    required this.totalNoTax,
    required this.taxGroups,
    required this.issuedAt,
    required this.accepted,
    this.transactionNo,
    this.error,
  });

  final int couponId;
  final String verificationNo;

  /// `base64(CitizenCoupon proto)|base64(signature)` — printed as a QR code.
  final String qrCode;

  /// All amounts in cents.
  final int total;
  final int totalTax;
  final int totalNoTax;
  final List<FiscalTaxGroup> taxGroups;
  final DateTime issuedAt;

  /// True when ATK accepted the coupon. False means it is stored locally and
  /// queued for retry — the coupon is still valid and still prints.
  final bool accepted;
  final String? transactionNo;
  final String? error;

  double get totalEuro => total / 100;
  double get totalTaxEuro => totalTax / 100;
  double get totalNoTaxEuro => totalNoTax / 100;
}

class FiscalNotConfiguredException implements Exception {
  FiscalNotConfiguredException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Builds, signs, stores and submits ATK fiscal coupons.
///
/// Submission failures never block the coupon: it is persisted with
/// `status = 'pending'` and printed, then [retryPending] pushes it later. A
/// coupon that exists locally but not at ATK is recoverable; a customer
/// holding no coupon is not.
class FiscalService {
  FiscalService._();
  static final FiscalService instance = FiscalService._();

  static const String _kSequenceKey = 'fiscal_coupon_sequence';

  /// Serializes coupon numbering so two quick taps cannot claim the same id.
  Future<void> _lock = Future<void>.value();

  Dio _dio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Content-Type': 'application/json'},
          // ATK answers 400 with a JSON body we want to surface verbatim.
          validateStatus: (s) => s != null && s < 500,
        ),
      );

  // ─────────────────────────── tax arithmetic ──────────────────────────────

  /// Splits a gross or net total into (totalForTax, tax) in cents.
  ///
  /// With [pricesIncludeVat] the VAT is *extracted* from the amount the
  /// customer pays — the normal Kosovo retail case, where menu prices already
  /// contain VAT. Otherwise it is added on top.
  @visibleForTesting
  static ({int totalForTax, int tax, int total}) splitVat({
    required int amountCents,
    required FiscalTaxRate rate,
    required bool pricesIncludeVat,
  }) {
    if (rate.percent == 0) {
      return (totalForTax: amountCents, tax: 0, total: amountCents);
    }
    if (pricesIncludeVat) {
      // gross → tax contained in it
      final tax = ((amountCents * rate.percent) / (100 + rate.percent)).round();
      return (totalForTax: amountCents, tax: tax, total: amountCents);
    }
    final tax = ((amountCents * rate.percent) / 100).round();
    return (
      totalForTax: amountCents + tax,
      tax: tax,
      total: amountCents + tax,
    );
  }

  // ─────────────────────────── coupon building ─────────────────────────────

  /// Cents from a euro amount, rounded half-away-from-zero like the receipt.
  static int _cents(double euro) => (euro * 100).round();

  /// Unit price in ATK's €0.0001 scale.
  static int _priceUnits(double euro) => (euro * 10000).round();

  /// 16-digit value, unique per coupon, used by the citizen app to look the
  /// coupon up. ATK caps it at 16 characters.
  static String _verificationNo(int couponId) {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final salt = math.Random.secure().nextInt(1000);
    final raw = '$millis${salt.toString().padLeft(3, '0')}';
    final tail = raw.substring(math.max(0, raw.length - 10));
    return '${couponId.toString().padLeft(6, '0')}$tail'.substring(0, 16);
  }

  /// Next coupon id. Must be unique across the whole business, so it is a
  /// single monotonic counter rather than anything per-table or per-shift.
  Future<int> _nextCouponId() async {
    final db = DatabaseService.instance;
    final raw = await db.getAppMeta(_kSequenceKey);
    final next = (int.tryParse(raw ?? '') ?? 0) + 1;
    await db.setAppMeta(_kSequenceKey, next.toString());
    return next;
  }

  /// Builds the signed coupon pair for [lines] without sending anything.
  @visibleForTesting
  ({PosCoupon pos, CitizenCoupon citizen}) buildCoupons({
    required FiscalSettings settings,
    required List<CurrentOrderLine> lines,
    required int couponId,
    required String verificationNo,
    required String operatorId,
    required DateTime issuedAt,
    FiscalPaymentType paymentType = FiscalPaymentType.cash,
  }) {
    final rate = settings.taxRate;
    final items = <FiscalCouponItem>[];
    var grossCents = 0;

    for (final l in lines) {
      final lineGross = _cents(l.product.price * l.qty);
      grossCents += lineGross;
      items.add(
        FiscalCouponItem(
          name: l.product.name,
          price: _priceUnits(l.product.price),
          unit: settings.unit,
          quantity: l.qty.toDouble(),
          total: lineGross,
          taxRate: rate.code,
          type: settings.itemType,
        ),
      );
    }

    final split = splitVat(
      amountCents: grossCents,
      rate: rate,
      pricesIncludeVat: settings.pricesIncludeVat,
    );
    final total = split.total;
    final totalTax = split.tax;
    final totalNoTax = total - totalTax;

    final taxGroups = <FiscalTaxGroup>[
      FiscalTaxGroup(
        taxRate: rate.code,
        totalForTax: split.totalForTax,
        totalTax: totalTax,
      ),
    ];

    final time = issuedAt.toUtc().millisecondsSinceEpoch ~/ 1000;

    final pos = PosCoupon(
      businessId: settings.businessId,
      couponId: couponId,
      branchId: settings.branchId,
      location: settings.location,
      operatorId: operatorId,
      posId: settings.posId,
      applicationId: settings.applicationId,
      verificationNo: verificationNo,
      type: FiscalCouponType.sale,
      time: time,
      items: items,
      payments: [FiscalPayment(type: paymentType, amount: total)],
      total: total,
      taxGroups: taxGroups,
      totalTax: totalTax,
      totalNoTax: totalNoTax,
    );

    // Shared fields must match the POS coupon exactly or ATK marks the
    // coupon FAILED VERIFICATION.
    final citizen = CitizenCoupon(
      businessId: settings.businessId,
      couponId: couponId,
      branchId: settings.branchId,
      posId: settings.posId,
      verificationNo: verificationNo,
      type: FiscalCouponType.sale,
      time: time,
      total: total,
      taxGroups: taxGroups,
      totalTax: totalTax,
      totalNoTax: totalNoTax,
    );

    return (pos: pos, citizen: citizen);
  }

  // ───────────────────────────── issuing ───────────────────────────────────

  /// Issues a fiscal coupon for [lines].
  ///
  /// The coupon is numbered, signed and stored **before** the network call, so
  /// a failed or slow submission still yields a printable coupon.
  Future<FiscalCouponResult> issueCoupon({
    required List<CurrentOrderLine> lines,
    required String operatorId,
    int? tableId,
    FiscalPaymentType paymentType = FiscalPaymentType.cash,
  }) {
    // Chain onto the previous call so coupon ids cannot collide.
    final completer = Completer<FiscalCouponResult>();
    _lock = _lock.then((_) async {
      try {
        completer.complete(
          await _issueCoupon(
            lines: lines,
            operatorId: operatorId,
            tableId: tableId,
            paymentType: paymentType,
          ),
        );
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<FiscalCouponResult> _issueCoupon({
    required List<CurrentOrderLine> lines,
    required String operatorId,
    int? tableId,
    FiscalPaymentType paymentType = FiscalPaymentType.cash,
  }) async {
    if (lines.isEmpty) {
      throw FiscalNotConfiguredException('Nuk ka artikuj për kupon fiskal.');
    }

    final store = FiscalSettingsStore.instance;
    if (!store.isLoaded) await store.load();
    final settings = store.settings;
    final problem = settings.configurationProblem;
    if (problem != null) throw FiscalNotConfiguredException(problem);

    final issuedAt = DateTime.now();
    final couponId = await _nextCouponId();
    final verificationNo = _verificationNo(couponId);

    final coupons = buildCoupons(
      settings: settings,
      lines: lines,
      couponId: couponId,
      verificationNo: verificationNo,
      operatorId: operatorId,
      issuedAt: issuedAt,
      paymentType: paymentType,
    );

    final signer = FiscalSigner(settings.privateKeyPem);
    final posBase64 = coupons.pos.toBase64();
    final posSignature = signer.signBase64Payload(posBase64);

    final citizenBase64 = coupons.citizen.toBase64();
    final citizenSignature = signer.signBase64Payload(citizenBase64);
    final qrCode = '$citizenBase64|$citizenSignature';

    final rowId = await DatabaseService.instance.insertFiscalCoupon({
      'couponId': couponId,
      'verificationNo': verificationNo,
      'businessId': settings.businessId,
      'branchId': settings.branchId,
      'posId': settings.posId,
      'tableId': tableId,
      'waiterName': operatorId,
      'couponType': FiscalCouponType.sale.wire,
      'issuedAt': issuedAt.toIso8601String(),
      'total': coupons.pos.total,
      'totalTax': coupons.pos.totalTax,
      'totalNoTax': coupons.pos.totalNoTax,
      'detailsBase64': posBase64,
      'signature': posSignature,
      'qrCode': qrCode,
      'status': 'pending',
    });

    String? transactionNo;
    String? error;
    var accepted = false;
    try {
      transactionNo = await _send(
        settings: settings,
        details: posBase64,
        signature: posSignature,
      );
      accepted = true;
      await DatabaseService.instance.markFiscalCouponSent(
        rowId,
        transactionNo: transactionNo,
      );
    } catch (e) {
      error = _describeError(e);
      await DatabaseService.instance.markFiscalCouponFailed(rowId, error);
      debugPrint('FiscalService: submission failed, queued for retry — $error');
    }

    return FiscalCouponResult(
      couponId: couponId,
      verificationNo: verificationNo,
      qrCode: qrCode,
      total: coupons.pos.total,
      totalTax: coupons.pos.totalTax,
      totalNoTax: coupons.pos.totalNoTax,
      taxGroups: coupons.pos.taxGroups,
      issuedAt: issuedAt,
      accepted: accepted,
      transactionNo: transactionNo,
      error: error,
    );
  }

  /// POSTs `{details, signature}` and returns ATK's transaction id.
  Future<String> _send({
    required FiscalSettings settings,
    required String details,
    required String signature,
  }) async {
    final response = await _dio().post<dynamic>(
      settings.environment.posCouponUrl,
      data: {'details': details, 'signature': signature},
    );
    final status = response.statusCode ?? 0;
    final body = response.data;
    if (status >= 200 && status < 300) {
      if (body is Map) {
        final tx = body['transaction_id'] ?? body['transactionId'];
        if (tx != null) return tx.toString();
      }
      return '';
    }
    final message = body is Map
        ? (body['error'] ?? body['message'] ?? body).toString()
        : body.toString();
    throw FiscalSubmissionException(status, message);
  }

  static String _describeError(Object e) {
    if (e is FiscalSubmissionException) return e.toString();
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'Nuk u arrit serveri i ATK-së (pa internet ose i padisponueshëm).';
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }

  /// Re-submits coupons ATK has not accepted yet. Safe to call repeatedly.
  Future<int> retryPending({int limit = 25}) async {
    final store = FiscalSettingsStore.instance;
    if (!store.isLoaded) await store.load();
    final settings = store.settings;
    if (!settings.isConfigured) return 0;

    final rows =
        await DatabaseService.instance.fetchPendingFiscalCoupons(limit: limit);
    var sent = 0;
    for (final row in rows) {
      final id = (row['id'] as num).toInt();
      try {
        final tx = await _send(
          settings: settings,
          details: row['detailsBase64'] as String,
          signature: row['signature'] as String,
        );
        await DatabaseService.instance
            .markFiscalCouponSent(id, transactionNo: tx);
        sent++;
      } catch (e) {
        await DatabaseService.instance
            .markFiscalCouponFailed(id, _describeError(e));
        // A hard rejection will not fix itself; stop hammering the service.
        if (e is FiscalSubmissionException && e.statusCode == 400) continue;
        break;
      }
    }
    return sent;
  }

  Future<int> pendingCount() =>
      DatabaseService.instance.countPendingFiscalCoupons();
}

class FiscalSubmissionException implements Exception {
  FiscalSubmissionException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ATK $statusCode: $message';
}
