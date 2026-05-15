import '../../../manager/manager_data.dart';

class SaleWithLines {
  const SaleWithLines({
    required this.sale,
    required this.lines,
    this.adjustments = const [],
  });
  final SaleRow sale;
  final List<SaleLineRow> lines;
  final List<SaleAdjustmentRow> adjustments;

  double get totalAdjusted =>
      adjustments.fold<double>(0, (s, a) => s + a.amount);
  double get netTotal => sale.total - totalAdjusted;
}

class SalesAnalytics {
  const SalesAnalytics({
    required this.totalSales,
    required this.grossRevenue,
    required this.totalRefunded,
    required this.avgOrderValue,
    required this.totalItemsSold,
    required this.topProducts,
    required this.topCategories,
    required this.topWaiterName,
    required this.topWaiterRevenue,
  });

  final int totalSales;
  final double grossRevenue;
  final double totalRefunded;
  final double avgOrderValue;
  final int totalItemsSold;
  final List<({String name, double revenue, int qty})> topProducts;
  final List<({String name, double revenue})> topCategories;
  final String topWaiterName;
  final double topWaiterRevenue;

  double get netRevenue => grossRevenue - totalRefunded;

  static SalesAnalytics compute(List<SaleWithLines> sales) {
    int totalItems = 0;
    final productRevenue = <String, double>{};
    final productQty = <String, int>{};
    final categoryRevenue = <String, double>{};
    final waiterRevenue = <String, double>{};

    for (final s in sales) {
      waiterRevenue[s.sale.waiterName] =
          (waiterRevenue[s.sale.waiterName] ?? 0) + s.sale.total;
      for (final l in s.lines) {
        totalItems += l.quantity;
        productRevenue[l.productName] =
            (productRevenue[l.productName] ?? 0) + l.lineTotal;
        productQty[l.productName] =
            (productQty[l.productName] ?? 0) + l.quantity;
        final cat = l.categoryName;
        if (cat != null && cat.isNotEmpty) {
          categoryRevenue[cat] = (categoryRevenue[cat] ?? 0) + l.lineTotal;
        }
      }
    }

    final grossRevenue = sales.fold<double>(0, (s, e) => s + e.sale.total);
    final totalRefunded = sales.fold<double>(0, (s, e) => s + e.totalAdjusted);
    final avgOrder = sales.isEmpty ? 0.0 : grossRevenue / sales.length;

    final topProducts = productRevenue.entries
        .map((e) => (
              name: e.key,
              revenue: e.value,
              qty: productQty[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final topCategories = categoryRevenue.entries
        .map((e) => (name: e.key, revenue: e.value))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    String topWaiterName = '—';
    double topWaiterRevenue = 0;
    for (final e in waiterRevenue.entries) {
      if (e.value > topWaiterRevenue) {
        topWaiterRevenue = e.value;
        topWaiterName = e.key;
      }
    }

    return SalesAnalytics(
      totalSales: sales.length,
      grossRevenue: grossRevenue,
      totalRefunded: totalRefunded,
      avgOrderValue: avgOrder,
      totalItemsSold: totalItems,
      topProducts: topProducts.take(5).toList(),
      topCategories: topCategories.take(5).toList(),
      topWaiterName: topWaiterName,
      topWaiterRevenue: topWaiterRevenue,
    );
  }
}
