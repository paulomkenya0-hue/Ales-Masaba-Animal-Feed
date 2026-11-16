import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firebase_service.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/stock_movement_model.dart';

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
    if (product.quantity < 0) throw Exception('Hifadhi haiwezi kuwa chini ya sifuri');
    final ref = _products.doc();
    final batch = FirebaseService.firestore.batch();
    batch.set(ref, product.toMap());
    if (product.quantity > 0) {
      final now = DateTime.now().toIso8601String();
      batch.set(
        _stockMovements.doc(),
        StockMovementModel(
          productId: ref.id,
          productName: product.name,
          type: StockMoveType.opening,
          change: product.quantity,
          before: 0,
          after: product.quantity,
          reason: 'Bidhaa mpya',
          createdAt: now,
        ).toMap(),
      );
    }
    await batch.commit();
    return ref.id;
  }

  /// Husasisha bidhaa. Ikiwa kiasi (quantity) kimebadilishwa kwenye fomu, mabadiliko
  /// yanarekodiwa kwenye historia ya hifadhi kama 'Marekebisho' (ndani ya transaction).
  Future<void> updateProduct(ProductModel product) async {
    if (product.id == null) throw Exception('Bidhaa haina kitambulisho');
    if (product.quantity < 0) throw Exception('Hifadhi haiwezi kuwa chini ya sifuri');
    final ref = _products.doc(product.id);
    await FirebaseService.firestore.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final before = (snap.data()?['quantity'] as num?)?.toDouble() ?? 0;
      txn.update(ref, product.toMap());
      if ((product.quantity - before).abs() > 0.0001) {
        txn.set(
          _stockMovements.doc(),
          StockMovementModel(
            productId: product.id!,
            productName: product.name,
            type: StockMoveType.adjustment,
            change: product.quantity - before,
            before: before,
            after: product.quantity,
            reason: 'Imebadilishwa kwenye fomu ya bidhaa',
            createdAt: DateTime.now().toIso8601String(),
          ).toMap(),
        );
      }
    });
  }

  /// Kufuta ni "soft delete" - bidhaa haionekani tena lakini historia ya mauzo inabaki sahihi
  Future<void> deleteProduct(String id) async {
    await _products.doc(id).update({'is_active': false});
  }

  CollectionReference<Map<String, dynamic>> get _stockMovements =>
      FirebaseService.firestore.collection('stock_movements');

  /// Hubadilisha hifadhi kwa kiasi [change] (chanya = ongezeko, hasi = punguzo) na
  /// kuandika kumbukumbu ya mabadiliko KWENYE transaction ile ile. Hairuhusu
  /// hifadhi kuwa hasi. [requestId] huzuia kurudiwa kwa ombi lile lile.
  Future<void> adjustStock({
    required String productId,
    required double change,
    required String type,
    String? reason,
    String? userId,
    String? userName,
    String? requestId,
  }) async {
    if (change == 0) throw Exception('Weka kiasi tofauti na sifuri');
    final docRef = _products.doc(productId);
    final moveRef = requestId != null ? _stockMovements.doc(requestId) : _stockMovements.doc();

    await FirebaseService.firestore.runTransaction((txn) async {
      if (requestId != null) {
        final dup = await txn.get(moveRef);
        if (dup.exists) return;
      }
      final snap = await txn.get(docRef);
      if (!snap.exists) throw Exception('Bidhaa haipo');
      final data = snap.data()!;
      final before = (data['quantity'] as num?)?.toDouble() ?? 0;
      final after = before + change;
      if (after < 0) {
        throw Exception('Hifadhi haiwezi kuwa chini ya sifuri (ipo ${before.toStringAsFixed(0)})');
      }
      final now = DateTime.now().toIso8601String();
      txn.update(docRef, {'quantity': after, 'updated_at': now});
      txn.set(
        moveRef,
        StockMovementModel(
          productId: productId,
          productName: data['name'] as String?,
          type: type,
          change: change,
          before: before,
          after: after,
          reason: reason,
          userId: userId,
          userName: userName,
          createdAt: now,
        ).toMap(),
      );
    });
  }

  /// Historia ya mabadiliko ya hifadhi (mapya kwanza). Bidhaa moja au zote.
  /// Hakuna orderBy kwenye seva ikiwa [productId] imewekwa (inaepuka composite index).
  Future<List<StockMovementModel>> getStockMovements({String? productId, int limit = 200}) async {
    Query<Map<String, dynamic>> q = _stockMovements;
    if (productId != null) {
      final snap = await q.where('product_id', isEqualTo: productId).get();
      final list = snap.docs.map((d) => StockMovementModel.fromMap(d.data(), id: d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    }
    final snap = await q.orderBy('created_at', descending: true).limit(limit).get();
    return snap.docs.map((d) => StockMovementModel.fromMap(d.data(), id: d.id)).toList();
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
