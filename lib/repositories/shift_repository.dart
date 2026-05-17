import '../services/database_service.dart';

/// Shift archive records (permanent [shifts] table) and legacy singleton [shift].
class ShiftRepository {
  ShiftRepository._();
  static final ShiftRepository instance = ShiftRepository._();

  final DatabaseService _db = DatabaseService.instance;

  Future<Map<String, dynamic>?> fetchOpenShift() => _db.fetchOpenShift();

  Future<List<Map<String, dynamic>>> fetchAllShifts() => _db.fetchAllShifts();

  Future<List<Map<String, dynamic>>> fetchClosedShifts() =>
      _db.fetchClosedShifts();

  Future<int> insertShiftRecord({
    required DateTime openedAt,
    String? openedBy,
    double openingCash = 0,
  }) =>
      _db.insertShiftRecord(
        openedAt: openedAt,
        openedBy: openedBy,
        openingCash: openingCash,
      );

  Future<void> closeShiftRecord({
    required int shiftId,
    required DateTime closedAt,
    String? closedBy,
    double? closingCash,
    required double totalSales,
    required double totalExpenses,
    required double netProfit,
    String? snapshotJson,
  }) =>
      _db.closeShiftRecord(
        shiftId: shiftId,
        closedAt: closedAt,
        closedBy: closedBy,
        closingCash: closingCash,
        totalSales: totalSales,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        snapshotJson: snapshotJson,
      );

  /// Legacy singleton row (`shift` id = 1).
  Future<void> updateShift({
    String? openedAt,
    String? closedAt,
    required String status,
  }) =>
      _db.updateShift(
        openedAt: openedAt,
        closedAt: closedAt,
        status: status,
      );
}
