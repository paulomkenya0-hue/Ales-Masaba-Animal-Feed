import 'package:flutter/material.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/customer_model.dart';

/// SalesProvider - Husimamia mchakato wa kuunda mauzo mapya (cart + checkout)
class SalesProvider extends ChangeNotifier {
  final _repo = SalesRepository();

  final List<SaleItemModel> _cartItems = [];
  bool _isProcessing = false;
  String? _errorMessage;
  SaleModel? _lastSale;

  List<SaleItemModel> get cartItems => _cartItems;
  double get cartTotal => _cartItems.fold(0, (sum, i) => sum + i.subtotal);
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  SaleModel? get lastSale => _lastSale;

  void addToCart(SaleItemModel item) {
    _cartItems.add(item);
    notifyListeners();
  }

  void removeFromCart(int index) {
    _cartItems.removeAt(index);
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  Future<bool> checkout({
    required String paymentMethod,
    int? existingCustomerId,
    CustomerModel? newCustomer,
    int? userId,
  }) async {
    if (_cartItems.isEmpty) {
      _errorMessage = 'Chagua angalau bidhaa moja kabla ya kuendelea';
      notifyListeners();
      return false;
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final saleId = await _repo.createSale(
        items: _cartItems,
        paymentMethod: paymentMethod,
        existingCustomerId: existingCustomerId,
        newCustomer: newCustomer,
        userId: userId,
      );
      _lastSale = await _repo.getSaleWithItems(saleId);
      clearCart();
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }
}
