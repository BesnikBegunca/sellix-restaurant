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
}) {
  // Conservative width so all 3 columns stay visible on most POS80 drivers.
  const width = 32;

  String center(String s) {
    s = s.replaceAll('\n', ' ');
    if (s.length >= width) return s.substring(0, width);
    final left = ((width - s.length) / 2).floor();
    final right = width - s.length - left;
    return '${' ' * left}$s${' ' * right}';
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

  const productCol = 16;
  const qtyCol = 6;
  const priceCol = width - productCol - qtyCol;

  final out = <String>[];
  out.add(rule());
  out.add('"$companyName"');
  out.add(rule());
  out.add('Kamarjeri : $waiterName');
  out.add('');
  out.add(
    padRight('Produkti', productCol) +
        padLeft('Sasia', qtyCol) +
        padLeft('Cmimi', priceCol),
  );
  out.add('');

  for (final line in lines) {
    final p = line.product;
    out.add(
      padRight(p.name, productCol) +
          padLeft(line.qty.toString(), qtyCol) +
          padLeft(fmtMoney(p.price), priceCol),
    );
  }

  out.add('');
  out.add(rule());
  out.add('Total: ${fmtMoney(total)}');
  out.add('Table $tableNumber | Order #$orderNumber');

  return out.join('\n');
}

String buildShiftReceiptText({
  required String companyName,
  required Map<String, double> waiterTotals,
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

  const waiterCol = 20;
  const totalCol = width - waiterCol;

  final names = waiterTotals.keys.toList()..sort();
  final grandTotal = names.fold<double>(0, (s, n) => s + (waiterTotals[n] ?? 0));

  final out = <String>[];
  out.add(rule());
  out.add('"$companyName"');
  out.add('GJENDJA');
  out.add(rule());
  out.add(padRight('Kamarjeri', waiterCol) + padLeft('Totali', totalCol));
  out.add('');

  for (final name in names) {
    out.add(
      padRight(name, waiterCol) +
          padLeft(fmtMoney(waiterTotals[name] ?? 0), totalCol),
    );
  }

  out.add(rule());
  out.add(padRight('Totali', waiterCol) + padLeft(fmtMoney(grandTotal), totalCol));
  return out.join('\n');
}
