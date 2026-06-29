import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/sale_model.dart';
import '../models/customer_model.dart';
import '../models/credit_model.dart';
import 'product_repository.dart';

/// SalesRepository - Husimamia mauzo, hupunguza hifadhi, na huunda mkopo ikiwa ni lazima.
/// Operesheni nzima hufanyika ndani ya "transaction" moja ili kuepuka data isiyo sahihi.
class SalesRepository {
  final dbHelper = DatabaseHelper.instance;
  final productRepo = ProductRepository();

  /// Huunda namba ya risiti: AMAF-YYYYMMDD-0001
  Future<String> generateReceiptNumber() async {
    final db = await dbHelper.database;
    final today = DateTime.now();
    final dateStr =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sales WHERE receipt_number LIKE 'AMAF-$dateStr-%'",
    );
    final count = (result.first['count'] as int) + 1;
    return 'AMAF-$dateStr-${count.toString().padLeft(4, '0')}';
  }

  /// Huunda mauzo mapya (Cash au Credit) kwa transaction salama.
  /// Ikiwa malipo ni Mkopo, [customer] inahitajika.
  Future<int> createSale({
    required List<SaleItemModel> items,
    required String paymentMethod, // 'Fedha Taslimu' | 'Mkopo'
    int? existingCustomerId,
    CustomerModel? newCustomer,
    int? userId,
  }) async {
    final db = await dbHelper.database;
    final receiptNumber = await generateReceiptNumber();
    final now = DateTime.now().toIso8601String();
    final total = items.fold<double>(0, (sum, item) => sum + item.subtotal);

    return await db.transaction((txn) async {
      int? customerId = existingCustomerId;

      if (paymentMethod == 'Mkopo' && customerId == null && newCustomer != null) {
        customerId = await txn.insert('customers', newCustomer.toMap());
      }

      final saleId = await txn.insert('sales', {
        'receipt_number': receiptNumber,
        'customer_id': customerId,
        'total_amount': total,
        'payment_method': paymentMethod,
        'sale_date': now,
        'user_id': userId,
      });

      for (final item in items) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.productId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'subtotal': item.subtotal,
        });

        // Punguza hifadhi - zuia hifadhi hasi
        final productRows = await txn.query('products', where: 'id = ?', whereArgs: [item.productId]);
        if (productRows.isEmpty) throw Exception('Bidhaa haipo');
        final currentQty = (productRows.first['quantity'] as num).toDouble();
        if (currentQty < item.quantity) {
          throw Exception('Hifadhi haitoshi kwa bidhaa: ${productRows.first['name']}');
        }
        await txn.update(
          'products',
          {'quantity': currentQty - item.quantity, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [item.productId],
        );
      }

      if (paymentMethod == 'Mkopo' && customerId != null) {
        await txn.insert('credit_sales', {
          'sale_id': saleId,
          'customer_id': customerId,
          'amount_owed': total,
          'amount_paid': 0,
          'status': 'Inadaiwa',
          'created_at': now,
        });
      }

      await txn.insert('activity_logs', {
        'user_id': userId,
        'action': 'Mauzo Mapya',
        'details': 'Risiti $receiptNumber - Jumla: $total',
        'created_at': now,
      });

      return saleId;
    });
  }

  Future<SaleModel?> getSaleWithItems(int saleId) async {
    final db = await dbHelper.database;
    final saleRows = await db.rawQuery('''
      SELECT s.*, c.name as customer_name FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE s.id = ?
    ''', [saleId]);
    if (saleRows.isEmpty) return null;

    final itemRows = await db.rawQuery('''
      SELECT si.*, p.name as product_name FROM sale_items si
      JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
    ''', [saleId]);

    final sale = SaleModel.fromMap(saleRows.first);
    return SaleModel(
      id: sale.id,
      receiptNumber: sale.receiptNumber,
      customerId: sale.customerId,
      customerName: sale.customerName,
      totalAmount: sale.totalAmount,
      paymentMethod: sale.paymentMethod,
      saleDate: sale.saleDate,
      userId: sale.userId,
      items: itemRows.map((r) => SaleItemModel.fromMap(r)).toList(),
    );
  }

  Future<List<SaleModel>> getSalesBetween(DateTime start, DateTime end) async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT s.*, c.name as customer_name FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE s.sale_date BETWEEN ? AND ?
      ORDER BY s.sale_date DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return rows.map((r) => SaleModel.fromMap(r)).toList();
  }

  Future<double> getTotalSales(DateTime start, DateTime end) async {
    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(total_amount) as total FROM sales WHERE sale_date BETWEEN ? AND ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }
}
