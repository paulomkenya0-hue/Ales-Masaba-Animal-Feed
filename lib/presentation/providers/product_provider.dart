import 'package:flutter/material.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/models/product_model.dart';
import '../../data/models/category_model.dart';

/// ProductProvider - Hali ya orodha ya bidhaa kwa UI nzima
class ProductProvider extends ChangeNotifier {
  final _repo = ProductRepository();

  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ProductModel> get products => _products;
  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<ProductModel> get lowStockProducts => _products.where((p) => p.isLowStock).toList();

  Future<void> loadProducts({String? searchQuery}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _products = await _repo.getAllProducts(searchQuery: searchQuery);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCategories() async {
    _categories = await _repo.getCategories();
    notifyListeners();
  }

  /// Rudisha id ya category mpya iliyoundwa (null ikiwa imeshindikana) - kwa
  /// ajili ya kuichagua moja kwa moja kwenye fomu baada ya kuiongeza.
  Future<String?> addCategory(String name) async {
    try {
      final id = await _repo.addCategory(name);
      await loadCategories();
      return id;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateCategory(String id, String name) async {
    try {
      await _repo.updateCategory(id, name);
      await loadCategories();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      await _repo.deleteCategory(id);
      await loadCategories();
      await loadProducts();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> countProductsInCategory(String categoryId) => _repo.countProductsInCategory(categoryId);

  /// Bidhaa (variants) zilizopangwa kwa Category - kwa ajili ya mwonekano
  /// wa "Category -> Variants" (mf. Pumba -> Pumba Mchele, Pumba Karanga)
  Map<String?, List<ProductModel>> get productsByCategory {
    final map = <String?, List<ProductModel>>{};
    for (final p in _products) {
      map.putIfAbsent(p.categoryId, () => []).add(p);
    }
    return map;
  }

  Future<bool> addProduct(ProductModel product) async {
    try {
      await _repo.addProduct(product);
      await loadProducts();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateProduct(ProductModel product) async {
    try {
      await _repo.updateProduct(product);
      await loadProducts();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await _repo.deleteProduct(id);
      await loadProducts();
      return true;
    } catch (_) {
      return false;
    }
  }
}
