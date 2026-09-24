import '../receipt_text.dart';

/// Plain-text fiscal coupon, used when ESC/POS mode is off or as the fallback
/// after an ESC/POS job fails.
///
/// A text printer cannot render the QR symbol, so the verification number is
/// printed in its place — the citizen app can still look the coupon up by it.
String buildFiscalCouponReceiptText({
  required String companyName,
  required String waiterName,
  required int tableNumber,
  required List<ReceiptLine> lines,
  required int couponId,
  required String verificationNo,
  required double total,
  required double totalTax,
  required double totalNoTax,
  required String taxRateCode,
  required int taxRatePercent,
  required DateTime issuedAt,
  required String footerText,
  String? businessId,
  String? posId,
  String? transactionNo,
  bool pendingSubmission = false,
}) {
  const width = 32;

  String center(String s) {
    final t = s.replaceAll('\n', ' ');
    if (t.length >= width) return t.substring(0, width);
    final pad = (width - t.length) ~/ 2;
    return '${' ' * pad}$t';
  }

  String rowLR(String left, String right) {
    if (right.length >= width) return right.substring(0, width);
    final leftMax = width - right.length;
    final leftStr = left.length >= leftMax
        ? left.substring(0, leftMax)
        : left.padRight(leftMax);
    return '$leftStr$right';
  }

  String rule() => '-' * width;
  String money(double v) => v.toStringAsFixed(2);
  String two(int v) => v.toString().padLeft(2, '0');

  const productCol = 12;
  const qtyCol = 4;
  const valueCol = width - productCol - qtyCol;

  final out = StringBuffer()
    ..writeln(center('KUPON FISKAL'))
    ..writeln();

  if (companyName.trim().isNotEmpty) out.writeln(center(companyName.trim()));
  if (businessId != null && businessId.isNotEmpty) {
    out.writeln(center('NUI: $businessId'));
  }
  out
    ..writeln(rule())
    ..writeln(rowLR('Perdoruesi: $waiterName', 'Tav. $tableNumber'))
    ..writeln(rule())
    ..writeln(
      '${'Produkti'.padRight(productCol)}'
      '${'Sas.'.padLeft(qtyCol)}'
      '${'Vlera'.padLeft(valueCol)}',
    )
    ..writeln(rule());

  for (final l in lines) {
    final name = l.product.name.length > productCol
        ? l.product.name.substring(0, productCol)
        : l.product.name.padRight(productCol);
    out.writeln(
      '$name'
      '${l.qty.toString().padLeft(qtyCol)}'
      '${money(l.product.price * l.qty).padLeft(valueCol)}',
    );
  }

  out
    ..writeln(rule())
    ..writeln(rowLR('Vlera pa TVSH:', money(totalNoTax)))
    ..writeln(rowLR('TVSH ($taxRateCode $taxRatePercent%):', money(totalTax)))
    ..writeln(rowLR('TOTALI:', money(total)))
    ..writeln(rule())
    ..writeln('Nr. i kuponit: $couponId')
    ..writeln('Nr. i verifikimit: $verificationNo');

  if (posId != null && posId.isNotEmpty) out.writeln('Arka: $posId');
  if (transactionNo != null && transactionNo.isNotEmpty) {
    out.writeln('Nr. i transaksionit: $transactionNo');
  }

  out.writeln(
    'Data: ${two(issuedAt.day)}.${two(issuedAt.month)}.${issuedAt.year} '
    '${two(issuedAt.hour)}:${two(issuedAt.minute)}:${two(issuedAt.second)}',
  );

  if (pendingSubmission) {
    out
      ..writeln()
      ..writeln(center('DERGOHET ME VONE NE ATK'));
  }

  out
    ..writeln()
    ..writeln(center(footerText.isNotEmpty ? footerText : 'Ju Faleminderit!'));

  return out.toString();
}
