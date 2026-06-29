import '../database/database_helper.dart';
import '../models/product_model.dart';

/// ProductRepository - CRUD ya Bidhaa + udhibiti wa hifadhi (stock)
class ProductRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<List<ProductModel>> getAllProducts({String? searchQuery}) async {
    final db = await dbHelper.database;
    final hasSearch = searchQuery != null && searchQuery.isNotEmpty;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.is_active = 1
      ${hasSearch ? "AND (p.name LIKE ? OR p.barcode LIKE ?)" : ""}
      ORDER BY p.name ASC
    ''', hasSearch ? ['%$searchQuery%', '%$searchQuery%'] : null);
    return rows.map((r) => ProductModel.fromMap(r)).toList();
  }

  Future<List<ProductModel>> getLowStockProducts() async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT * FROM products WHERE is_active = 1 AND quantity <= low_stock_limit ORDER BY quantity ASC
    ''');
    return rows.map((r) => ProductModel.fromMap(r)).toList();
  }

  Future<int> addProduct(ProductModel product) async {
    final db = await dbHelper.database;
    return await db.insert('products', product.toMap());
  }

  Future<int> updateProduct(ProductModel product) async {
    final db = await dbHelper.database;
    return await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  /// Kufuta ni "soft delete" - bidhaa haionekani tena lakini historia ya mauzo inabaki sahihi
  Future<int> deleteProduct(int id) async {
    final db = await dbHelper.database;
    return await db.update('products', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  /// Hupunguza hifadhi baada ya mauzo. Hutupa Exception kama hifadhi haitoshi (hairuhusu stock hasi)
  Future<void> reduceStock(int productId, double quantitySold) async {
    final db = await dbHelper.database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [productId]);
    if (rows.isEmpty) throw Exception('Bidhaa haipo');
    final current = (rows.first['quantity'] as num).toDouble();
    if (current < quantitySold) {
      throw Exception('Hifadhi haitoshi kwa bidhaa hii');
    }
    await db.update(
      'products',
      {'quantity': current - quantitySold, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await dbHelper.database;
    return await db.query('categories', orderBy: 'name ASC');
  }

  Future<int> addCategory(String name) async {
    final db = await dbHelper.database;
    return await db.insert('categories', {'name': name, 'created_at': DateTime.now().toIso8601String()});
  }
}
