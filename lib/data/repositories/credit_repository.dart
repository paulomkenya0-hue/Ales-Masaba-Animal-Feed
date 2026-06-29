import '../database/database_helper.dart';
import '../models/credit_model.dart';

/// CreditRepository - Husimamia madeni ya wateja na malipo (sehemu/kamili)
class CreditRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<List<CreditSaleModel>> getActiveCredits() async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT cs.*, c.name as customer_name, c.phone as customer_phone
      FROM credit_sales cs
      JOIN customers c ON cs.customer_id = c.id
      WHERE cs.status = 'Inadaiwa'
      ORDER BY cs.created_at DESC
    ''');
    return rows.map((r) => CreditSaleModel.fromMap(r)).toList();
  }

  Future<List<PaymentModel>> getPaymentHistory(int creditSaleId) async {
    final db = await dbHelper.database;
    final rows = await db.query('payments', where: 'credit_sale_id = ?', whereArgs: [creditSaleId], orderBy: 'payment_date DESC');
    return rows.map((r) => PaymentModel.fromMap(r)).toList();
  }

  /// Hurekodi malipo (sehemu au kamili). Ikiwa deni limelipwa kikamilifu,
  /// hali inabadilika kuwa 'Imelipwa' na mteja huondolewa kwenye orodha ya madeni hai,
  /// lakini historia ya malipo inabaki daima.
  Future<void> recordPayment(int creditSaleId, double amount, {String? notes}) async {
    final db = await dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert('payments', {
        'credit_sale_id': creditSaleId,
        'amount': amount,
        'payment_date': now,
        'notes': notes,
      });

      final rows = await txn.query('credit_sales', where: 'id = ?', whereArgs: [creditSaleId]);
      if (rows.isEmpty) throw Exception('Deni halipo');
      final owed = (rows.first['amount_owed'] as num).toDouble();
      final paidSoFar = (rows.first['amount_paid'] as num).toDouble();
      final newPaid = paidSoFar + amount;
      final newStatus = newPaid >= owed ? 'Imelipwa' : 'Inadaiwa';

      await txn.update(
        'credit_sales',
        {'amount_paid': newPaid, 'status': newStatus},
        where: 'id = ?',
        whereArgs: [creditSaleId],
      );
    });
  }

  Future<double> getTotalOutstandingCredit() async {
    final db = await dbHelper.database;
    final result = await db.rawQuery(
      "SELECT SUM(amount_owed - amount_paid) as total FROM credit_sales WHERE status = 'Inadaiwa'",
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<Map<String, dynamic>?> getHighestCreditCustomer() async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT c.name, c.phone, SUM(cs.amount_owed - cs.amount_paid) as balance
      FROM credit_sales cs
      JOIN customers c ON cs.customer_id = c.id
      WHERE cs.status = 'Inadaiwa'
      GROUP BY cs.customer_id
      ORDER BY balance DESC
      LIMIT 1
    ''');
    return rows.isEmpty ? null : rows.first;
  }
}
