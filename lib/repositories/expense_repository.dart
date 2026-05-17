import '../services/database_service.dart';

/// Shift and general expenses.
class ExpenseRepository {
  ExpenseRepository._();
  static final ExpenseRepository instance = ExpenseRepository._();

  final DatabaseService _db = DatabaseService.instance;

  Future<List<Map<String, dynamic>>> fetchExpenses() => _db.fetchExpenses();

  Future<int> insertExpense({
    required String type,
    required String description,
    required double amount,
    required DateTime date,
    int? shiftId,
  }) =>
      _db.insertExpense(
        type: type,
        description: description,
        amount: amount,
        date: date,
        shiftId: shiftId,
      );

  Future<void> deleteExpenseById(int id) => _db.deleteExpenseById(id);
}
