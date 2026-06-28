/// Summary of open table sessions / unpaid orders blocking tenant reset.
class OpenTablesSummary {
  const OpenTablesSummary({
    required this.count,
    required this.totalAmount,
  });

  /// Number of open table orders (`current_orders` rows).
  final int count;

  /// Combined total amount in EUR.
  final double totalAmount;
}
