import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firebase_service.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';

/// ProductRepository - CRUD ya Bidhaa + udhibiti wa hifadhi (stock), sasa
/// kwa kutumia Cloud Firestore (Offline + Online Sync moja kwa moja kwa
/// sababu ya persistenceEnabled iliyowekwa kwenye FirebaseService).
///
/// MUHIMU: Firestore haina "LIKE" wala "JOIN" kama SQL. Kwa idadi ya bidhaa
/// za kawaida za duka (mamia machache), tunapakua orodha ya bidhaa zilizo
/// hai kisha tunachuja (search) na kuunganisha jina la category upande wa
/// programu (client-side) - hii ni haraka na salama vya kutosha kwa matumizi
/// haya, na inafanya kazi Offline pia (kwa cache ya Firestore).
class ProductRepository {
  CollectionReference<Map<String, dynamic>> get _products =>
      FirebaseService.firestore.collection('products');
  CollectionReference<Map<String, dynamic>> get _categories =>
      FirebaseService.firestore.collection('categories');

  Future<List<ProductModel>> getAllProducts({String? searchQuery}) async {
    final categoryMap = await _categoryNameMap();

    final snap = await _products.where('is_active', isEqualTo: true).get();
    var products = snap.docs
        .map((d) => ProductModel.fromMap(d.data(), id: d.id, categoryName: categoryMap[d.data()['category_id']]))
        .toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      products = products
          .where((p) => p.name.toLowerCase().contains(q) || (p.barcode ?? '').toLowerCase().contains(q))
          .toList();
    }

    products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return products;
  }

  Future<List<ProductModel>> getLowStockProducts() async {
    final all = await getAllProducts();
    final low = all.where((p) => p.isLowStock).toList();
    low.sort((a, b) => a.quantity.compareTo(b.quantity));
    return low;
  }

  Future<String> addProduct(ProductModel product) async {
    final doc = await _products.add(product.toMap());
    return doc.id;
  }

  Future<void> updateProduct(ProductModel product) async {
    if (product.id == null) throw Exception('Bidhaa haina kitambulisho');
    await _products.doc(product.id).update(product.toMap());
  }

  /// Kufuta ni "soft delete" - bidhaa haionekani tena lakini historia ya mauzo inabaki sahihi
  Future<void> deleteProduct(String id) async {
    await _products.doc(id).update({'is_active': false});
  }

  /// Hupunguza hifadhi baada ya mauzo, kwa transaction ya Firestore (salama
  /// hata kama vifaa/watumiaji zaidi ya kimoja wanauza kwa wakati mmoja).
  /// Hutupa Exception kama hifadhi haitoshi (hairuhusu stock hasi).
  Future<void> reduceStock(String productId, double quantitySold) async {
    final docRef = _products.doc(productId);
    await FirebaseService.firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) throw Exception('Bidhaa haipo');
      final current = (snap.data()!['quantity'] as num).toDouble();
      if (current < quantitySold) {
        throw Exception('Hifadhi haitoshi kwa bidhaa hii');
      }
      txn.update(docRef, {
        'quantity': current - quantitySold,
        'updated_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<Map<String, String>> _categoryNameMap() async {
    final snap = await _categories.get();
    return {for (final d in snap.docs) d.id: d.data()['name'] as String? ?? ''};
  }

  Future<List<CategoryModel>> getCategories() async {
    final snap = await _categories.orderBy('name').get();
    return snap.docs.map((d) => CategoryModel.fromMap(d.data(), id: d.id)).toList();
  }

  /// Thamani ya jumla ya hifadhi (stock) - kwa bei ya ununuzi (gharama) na
  /// bei ya rejareja (thamani inayotarajiwa ikiuzwa yote)
  Future<Map<String, double>> getTotalStockValue() async {
    final all = await getAllProducts();
    double atCost = 0, atRetail = 0;
    for (final p in all) {
      atCost += p.quantity * p.buyingPrice;
      atRetail += p.quantity * p.retailPrice;
    }
    return {'cost': atCost, 'retail': atRetail};
  }

  Future<String> addCategory(String name) async {
    final doc = await _categories.add({
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    });
    return doc.id;
  }

  Future<void> updateCategory(String id, String name) async {
    await _categories.doc(id).update({'name': name});
  }

  /// Hufuta category. Bidhaa zilizokuwa chini yake HAZIFUTWI - zinabaki tu
  /// bila category (Super Admin anaweza kuzipangia category nyingine baadaye).
  Future<void> deleteCategory(String id) async {
    await _categories.doc(id).delete();
  }

  /// Idadi ya bidhaa (variants) chini ya category husika - kwa ajili ya
  /// kuonyesha kwenye orodha ya categories na kuzuia ufutaji usio salama.
  Future<int> countProductsInCategory(String categoryId) async {
    final snap = await _products
        .where('category_id', isEqualTo: categoryId)
        .where('is_active', isEqualTo: true)
        .count()
        .get();
    return snap.count ?? 0;
  }
}
