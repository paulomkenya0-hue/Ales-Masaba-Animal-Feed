import 'package:flutter/material.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/models/product_model.dart';

/// ProductProvider - Hali ya orodha ya bidhaa kwa UI nzima
class ProductProvider extends ChangeNotifier {
  final _repo = ProductRepository();

  List<ProductModel> _products = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;

  List<ProductModel> get products => _products;
  List<Map<String, dynamic>> get categories => _categories;
  bool get isLoading => _isLoading;

  List<ProductModel> get lowStockProducts => _products.where((p) => p.isLowStock).toList();

  Future<void> loadProducts({String? searchQuery}) async {
    _isLoading = true;
    notifyListeners();
    _products = await _repo.getAllProducts(searchQuery: searchQuery);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCategories() async {
    _categories = await _repo.getCategories();
    notifyListeners();
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

  Future<bool> deleteProduct(int id) async {
    try {
      await _repo.deleteProduct(id);
      await loadProducts();
      return true;
    } catch (_) {
      return false;
    }
  }
}
