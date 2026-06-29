import '../database/database_helper.dart';
import '../models/expense_model.dart';

/// ExpenseRepository - Husimamia matumizi ya biashara
class ExpenseRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<int> addExpense(ExpenseModel expense) async {
    final db = await dbHelper.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<ExpenseModel>> getExpensesBetween(DateTime start, DateTime end) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'expenses',
      where: 'expense_date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'expense_date DESC',
    );
    return rows.map((r) => ExpenseModel.fromMap(r)).toList();
  }

  Future<double> getTotalExpenses(DateTime start, DateTime end) async {
    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE expense_date BETWEEN ? AND ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> deleteExpense(int id) async {
    final db = await dbHelper.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}
