import '../../core/services/firebase_service.dart';
import '../models/expense_model.dart';

/// ExpenseRepository - Husimamia matumizi ya biashara, sasa kwa Firestore
class ExpenseRepository {
  final _expenses = FirebaseService.firestore.collection('expenses');

  Future<String> addExpense(ExpenseModel expense) async {
    final doc = await _expenses.add(expense.toMap());
    return doc.id;
  }

  Future<List<ExpenseModel>> getExpensesBetween(DateTime start, DateTime end) async {
    final snap = await _expenses
        .where('expense_date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('expense_date', isLessThanOrEqualTo: end.toIso8601String())
        .orderBy('expense_date', descending: true)
        .get();
    return snap.docs.map((d) => ExpenseModel.fromMap(d.data(), id: d.id)).toList();
  }

  Future<double> getTotalExpenses(DateTime start, DateTime end) async {
    final expenses = await getExpensesBetween(start, end);
    return expenses.fold<double>(0, (sum, e) => sum + e.amount);
  }

  /// Ripoti ya matumizi kwa kila category (Usafiri, Umeme, n.k.) ndani ya kipindi
  Future<Map<String, double>> getExpensesByCategory(DateTime start, DateTime end) async {
    final expenses = await getExpensesBetween(start, end);
    final Map<String, double> byCategory = {};
    for (final e in expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    return byCategory;
  }

  Future<void> deleteExpense(String id) async {
    await _expenses.doc(id).delete();
  }
}
