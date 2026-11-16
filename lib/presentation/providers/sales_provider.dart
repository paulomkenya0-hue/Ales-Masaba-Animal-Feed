import 'package:flutter/material.dart';
import '../../core/utils/id_util.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/customer_model.dart';

/// SalesProvider - Husimamia kikapu (cart) cha mauzo na kukamilisha mauzo (checkout).
///
/// Kuzuia mauzo mara mbili: kila "jaribio la kuuza" lina `clientRequestId`.
/// Kitambulisho hicho kinabaki kile kile kama mtumiaji anajaribu tena bila
/// kubadilisha kikapu (mfano mtandao ulikatika katikati) - hivyo Firestore
/// inatambua ombi lilelile na haipunguzi hifadhi mara ya pili. Kikapu
/// kikibadilika au mauzo yakifanikiwa, kitambulisho kipya kinatengenezwa.
class SalesProvider extends ChangeNotifier {
  final _repo = SalesRepository();

  final List<SaleItemModel> _cartItems = [];
  bool _isProcessing = false;
  String? _errorMessage;
  SaleModel? _lastSale;
  String? _requestId;

  List<SaleItemModel> get cartItems => List.unmodifiable(_cartItems);
  double get cartTotal => _cartItems.fold(0, (sum, i) => sum + i.subtotal);
  int get cartCount => _cartItems.length;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  SaleModel? get lastSale => _lastSale;

  /// Kiasi kilichopo kwenye kikapu kwa bidhaa fulani (mistari yote ya bidhaa hiyo)
  double quantityInCart(String productId) =>
      _cartItems.where((i) => i.productId == productId).fold(0.0, (s, i) => s + i.quantity);

  void _cartChanged() {
    _requestId = null; // kikapu kimebadilika = mauzo mapya
    _errorMessage = null;
    notifyListeners();
  }

  /// Ongeza bidhaa. Ikiwa bidhaa ileile yenye bei ileile ipo, kiasi kinajumlishwa.
  void addToCart(SaleItemModel item) {
    final idx = _cartItems.indexWhere((i) => i.productId == item.productId && i.unitPrice == item.unitPrice);
    if (idx >= 0) {
      _cartItems[idx] = _cartItems[idx].copyWith(quantity: _cartItems[idx].quantity + item.quantity);
    } else {
      _cartItems.add(item);
    }
    _cartChanged();
  }

  /// Hariri kiasi na/au bei ya mstari uliopo kwenye kikapu
  void updateItem(int index, {double? quantity, double? unitPrice}) {
    if (index < 0 || index >= _cartItems.length) return;
    _cartItems[index] = _cartItems[index].copyWith(quantity: quantity, unitPrice: unitPrice);
    _cartChanged();
  }

  void removeFromCart(int index) {
    if (index < 0 || index >= _cartItems.length) return;
    _cartItems.removeAt(index);
    _cartChanged();
  }

  void clearCart() {
    _cartItems.clear();
    _cartChanged();
  }

  Future<bool> checkout({
    required double amountPaid,
    String paymentMethod = PayMethod.cash,
    String? paymentReference,
    String? existingCustomerId,
    String? existingCustomerName,
    String? existingCustomerPhone,
    CustomerModel? newCustomer,
    String? userId,
    String? cashierName,
    String? branchName,
    bool allowOverstock = false,
  }) async {
    if (_isProcessing) return false; // ulinzi dhidi ya kubonyeza mara mbili
    if (_cartItems.isEmpty) {
      _errorMessage = 'Chagua angalau bidhaa moja kabla ya kuendelea';
      notifyListeners();
      return false;
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    _requestId ??= IdUtil.newRequestId();

    try {
      final saleId = await _repo.createSale(
        items: List.of(_cartItems),
        clientRequestId: _requestId!,
        amountPaid: amountPaid,
        paymentMethod: paymentMethod,
        paymentReference: paymentReference,
        existingCustomerId: existingCustomerId,
        existingCustomerName: existingCustomerName,
        existingCustomerPhone: existingCustomerPhone,
        newCustomer: newCustomer,
        userId: userId,
        cashierName: cashierName,
        branchName: branchName,
        allowOverstock: allowOverstock,
      );
      _lastSale = await _repo.getSaleWithItems(saleId);
      _cartItems.clear();
      _requestId = null;
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      // _requestId inabaki ileile ili jaribio la pili lisirudie mauzo
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }
}
