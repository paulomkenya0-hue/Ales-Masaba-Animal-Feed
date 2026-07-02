import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firebase_service.dart';
import '../models/customer_model.dart';
import '../models/credit_model.dart';

/// CustomerRepository - Wateja wote wa biashara. Kusudi kuu: kuzuia mteja
/// mmoja kuwa na "profile" zaidi ya moja (Awamu 6 - "Wateja wa Mkopo -
/// single profile, bila kurudia"). Kabla ya kuunda mteja mpya, app
/// INALAZIMIKA kutafuta kwanza kwa jina/namba ya simu.
class CustomerRepository {
  CollectionReference<Map<String, dynamic>> get _customers =>
      FirebaseService.firestore.collection('customers');
  CollectionReference<Map<String, dynamic>> get _creditSales =>
      FirebaseService.firestore.collection('credit_sales');

  Future<List<CustomerModel>> getAllCustomers() async {
    final snap = await _customers.orderBy('name').get();
    return snap.docs.map((d) => CustomerModel.fromMap(d.data(), id: d.id)).toList();
  }

  /// Tafuta wateja waliopo kwa jina AU namba ya simu (haitofautishi herufi
  /// kubwa/ndogo). Hii INATAKIWA kuitwa kabla ya kuunda mteja mpya wakati
  /// wa mauzo ya mkopo, ili kuepuka "wateja pacha" kwenye mfumo.
  Future<List<CustomerModel>> searchCustomers(String query) async {
    if (query.trim().isEmpty) return getAllCustomers();
    final q = query.trim().toLowerCase();
    final all = await getAllCustomers();
    return all
        .where((c) =>
            c.name.toLowerCase().contains(q) || (c.phone ?? '').replaceAll(' ', '').contains(q.replaceAll(' ', '')))
        .toList();
  }

  Future<CustomerModel?> getCustomer(String id) async {
    final doc = await _customers.doc(id).get();
    if (!doc.exists) return null;
    return CustomerModel.fromMap(doc.data()!, id: doc.id);
  }

  Future<String> addCustomer(CustomerModel customer) async {
    final doc = await _customers.add(customer.toMap());
    return doc.id;
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    if (customer.id == null) throw Exception('Mteja hana kitambulisho');
    await _customers.doc(customer.id).update(customer.toMap());
  }

  /// Salio la jumla la mkopo la mteja mmoja (madeni yote yaliyopo hai)
  Future<double> getCustomerBalance(String customerId) async {
    final snap = await _creditSales
        .where('customer_id', isEqualTo: customerId)
        .where('status', isEqualTo: 'Inadaiwa')
        .get();
    double total = 0;
    for (final d in snap.docs) {
      final owed = (d.data()['amount_owed'] as num).toDouble();
      final paid = (d.data()['amount_paid'] as num?)?.toDouble() ?? 0;
      total += (owed - paid);
    }
    return total;
  }

  /// Historia kamili ya madeni ya mteja mmoja (statement)
  Future<List<CreditSaleModel>> getCustomerCreditHistory(String customerId) async {
    final snap = await _creditSales
        .where('customer_id', isEqualTo: customerId)
        .orderBy('created_at', descending: true)
        .get();
    return snap.docs.map((d) => CreditSaleModel.fromMap(d.data(), id: d.id)).toList();
  }
}
