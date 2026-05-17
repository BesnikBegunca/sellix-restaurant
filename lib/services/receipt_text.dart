import '../models/mock_data.dart';

class ReceiptLine {
  const ReceiptLine({required this.product, required this.qty});

  final ProductItem product;
  final int qty;
}

String buildKitchenOrderReceiptText({
  required String companyName,
  required String waiterName,
  required int tableNumber,
  required int orderNumber,
  required List<ReceiptLine> lines,
  required double total,
  bool paymentReceipt = false,
}) {
  // Conservative width so all 3 columns stay visible on most POS80 drivers.
  const width = 32;

  String markCenter(String s) =>
      '[[C]]${s.replaceAll('\n', ' ')}[[/C]]';

  String markCenterBold(String s) =>
      '[[CB]]${s.replaceAll('\n', ' ')}[[/CB]]';

  String markCenterBoldLarge(String s) =>
      '[[CBL]]${s.replaceAll('\n', ' ')}[[/CBL]]';

  String markBold(String s) => '[[B]]${s.replaceAll('\n', ' ')}[[/B]]';

  String rowLR(String left, String right) {
    if (right.length >= width) return right.substring(0, width);
    final leftMax = width - right.length;
    final leftStr = left.length >= leftMax
        ? left.substring(0, leftMax)
        : left.padRight(leftMax);
    return leftStr + right;
  }

  String padRight(String s, int n) {
    if (s.length >= n) return s.substring(0, n);
    return s + (' ' * (n - s.length));
  }

  String padLeft(String s, int n) {
    if (s.length >= n) return s.substring(s.length - n);
    return (' ' * (n - s.length)) + s;
  }

  String rule() => '-' * width;
  String fmtMoney(double v) => v.toStringAsFixed(2);
  String two(int v) => v.toString().padLeft(2, '0');

  const productCol = 11;
  const qtyCol = 5; // "Sasia" = 5 shkronja
  const unitCol = 7;
  const valueCol = width - productCol - qtyCol - unitCol;

  final out = <String>[];
  if (paymentReceipt) {
    out.add(markCenterBoldLarge('TOTALI PER PAGESE'));
    out.add('');
    out.add(markCenterBold(companyName));
    out.add(rule());
  } else {
    out.add(rule());
    out.add(markCenterBold(companyName));
    out.add(rule());
  }
  out.add(rowLR('Perdoruesi : $waiterName', 'Tavolina $tableNumber'));
  out.add('');
  final itemsHeader =
      padRight('Produkti', productCol) +
      padLeft('Sasia', qtyCol) +
      padLeft('Cmimi', unitCol) +
      padLeft('Vlera', valueCol);
  out.add(markBold(itemsHeader));
  out.add(rule());

  for (final line in lines) {
    final p = line.product;
    final lineValue = p.price * line.qty;
    out.add(
      padRight(p.name, productCol) +
          padLeft(line.qty.toString(), qtyCol) +
          padLeft(fmtMoney(p.price), unitCol) +
          padLeft(fmtMoney(lineValue), valueCol),
    );
  }

  out.add('');
  out.add(rule());
  out.add(
    padRight('Total:', productCol + qtyCol + unitCol) +
        padLeft(fmtMoney(total), valueCol),
  );
  out.add('Order #$orderNumber');
  final now = DateTime.now();
  out.add(
    'Date: ${two(now.day)}.${two(now.month)}.${now.year} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
  );
  if (paymentReceipt) {
    out.add('');
    out.add(markCenter('Ju Faleminderit.'));
  }

  return out.join('\n');
}

String buildShiftReceiptText({
  required String companyName,
  required Map<String, double> waiterTotals,
  double? summaryPaid,
  double? summaryOpen,
  DateTime? reportTime,
}) {
  const width = 32;

  String padRight(String s, int n) {
    if (s.length >= n) return s.substring(0, n);
    return s + (' ' * (n - s.length));
  }

  String padLeft(String s, int n) {
    if (s.length >= n) return s.substring(s.length - n);
    return (' ' * (n - s.length)) + s;
  }

  String rule() => '-' * width;
  String fmtMoney(double v) => v.toStringAsFixed(2);
  String two(int v) => v.toString().padLeft(2, '0');

  const waiterCol = 20;
  const totalCol = width - waiterCol;

  final names = waiterTotals.keys.toList()..sort();
  final grandTotal = names.fold<double>(0, (s, n) => s + (waiterTotals[n] ?? 0));

  String markCenter(String s) =>
      '[[C]]${s.replaceAll('\n', ' ')}[[/C]]';

  String markCenterBold(String s) =>
      '[[CB]]${s.replaceAll('\n', ' ')}[[/CB]]';

  String markCenterBoldLarge(String s) =>
      '[[CBL]]${s.replaceAll('\n', ' ')}[[/CBL]]';

  String markBold(String s) => '[[B]]${s.replaceAll('\n', ' ')}[[/B]]';

  final out = <String>[];
  out.add(rule());
  out.add(markCenterBoldLarge('GJENDJA'));
  out.add('');
  out.add(markCenterBold(companyName));
  out.add(rule());
  final shiftHeader =
      padRight('Perdoruesi', waiterCol) + padLeft('Totali', totalCol);
  out.add(markBold(shiftHeader));
  out.add(rule());

  for (final name in names) {
    out.add(
      padRight(name, waiterCol) +
          padLeft(fmtMoney(waiterTotals[name] ?? 0), totalCol),
    );
  }

  out.add(rule());
  out.add(
    markBold(
      padRight('Totali', waiterCol) + padLeft(fmtMoney(grandTotal), totalCol),
    ),
  );
  if (summaryPaid != null && summaryOpen != null) {
    out.add('');
    out.add(padRight('Paguar', waiterCol) + padLeft(fmtMoney(summaryPaid), totalCol));
    out.add(padRight('Hapur', waiterCol) + padLeft(fmtMoney(summaryOpen), totalCol));
  }
  if (reportTime != null) {
    final t = reportTime;
    out.add(
      '${two(t.day)}.${two(t.month)}.${t.year} '
      '${two(t.hour)}:${two(t.minute)}',
    );
  }
  return out.join('\n');
}
