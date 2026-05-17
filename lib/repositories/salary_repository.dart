import '../services/database_service.dart';

/// Waiter salaries, advances, and worked days.
class SalaryRepository {
  SalaryRepository._();
  static final SalaryRepository instance = SalaryRepository._();

  final DatabaseService _db = DatabaseService.instance;

  Future<Map<String, double>> fetchAllSalaries() => _db.fetchAllSalaries();

  Future<void> upsertWaiterSalary(String waiterName, double dailyRate) =>
      _db.upsertWaiterSalary(waiterName, dailyRate);

  Future<List<Map<String, dynamic>>> fetchAdvances() => _db.fetchAdvances();

  Future<int> insertAdvance({
    required String waiterName,
    required double amount,
    required String note,
    required DateTime date,
  }) =>
      _db.insertAdvance(
        waiterName: waiterName,
        amount: amount,
        note: note,
        date: date,
      );

  Future<void> deleteAdvanceById(int id) => _db.deleteAdvanceById(id);

  Future<List<Map<String, dynamic>>> fetchWorkedDays() => _db.fetchWorkedDays();

  Future<void> setWorkedDay(String waiterName, String date, bool worked) =>
      _db.setWorkedDay(waiterName, date, worked);
}
