import 'package:flutter/material.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/credit_model.dart';

class CustomerProvider extends ChangeNotifier {
  final _repo = CustomerRepository();

  List<CustomerModel> _customers = [];
  List<CustomerModel> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  List<CustomerModel> get customers => _customers;
  List<CustomerModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();
    _customers = await _repo.getAllCustomers();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> search(String query) async {
    _isSearching = true;
    notifyListeners();
    _searchResults = await _repo.searchCustomers(query);
    _isSearching = false;
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  Future<String> addCustomer(CustomerModel customer) => _repo.addCustomer(customer);

  Future<double> getBalance(String customerId) => _repo.getCustomerBalance(customerId);

  Future<List<CreditSaleModel>> getCreditHistory(String customerId) =>
      _repo.getCustomerCreditHistory(customerId);
}
