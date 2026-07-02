import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firebase_service.dart';
import '../models/credit_model.dart';

/// CreditRepository - Husimamia madeni ya wateja na malipo (sehemu/kamili),
/// sasa kwa Firestore. Malipo (payments) yamehifadhiwa kama "subcollection"
/// chini ya kila credit_sales/{id} - hii inaruhusu historia ya malipo kubaki
/// daima hata baada ya deni kulipwa kikamilifu.
class CreditRepository {
  CollectionReference<Map<String, dynamic>> get _creditSales =>
      FirebaseService.firestore.collection('credit_sales');

  Future<List<CreditSaleModel>> getActiveCredits() async {
    final snap = await _creditSales
        .where('status', isEqualTo: 'Inadaiwa')
        .orderBy('created_at', descending: true)
        .get();
    return snap.docs.map((d) => CreditSaleModel.fromMap(d.data(), id: d.id)).toList();
  }

  Future<List<PaymentModel>> getPaymentHistory(String creditSaleId) async {
    final snap = await _creditSales
        .doc(creditSaleId)
        .collection('payments')
        .orderBy('payment_date', descending: true)
        .get();
    return snap.docs.map((d) => PaymentModel.fromMap(d.data(), id: d.id)).toList();
  }

  /// Hurekodi malipo (sehemu au kamili). Ikiwa deni limelipwa kikamilifu,
  /// hali inabadilika kuwa 'Imelipwa' na mteja huondolewa kwenye orodha ya
  /// madeni hai, lakini historia ya malipo inabaki daima.
  Future<void> recordPayment(String creditSaleId, double amount, {String? notes}) async {
    final now = DateTime.now().toIso8601String();
    final creditRef = _creditSales.doc(creditSaleId);
    final paymentRef = creditRef.collection('payments').doc();

    await FirebaseService.firestore.runTransaction((txn) async {
      final snap = await txn.get(creditRef);
      if (!snap.exists) throw Exception('Deni halipo');

      final owed = (snap.data()!['amount_owed'] as num).toDouble();
      final paidSoFar = (snap.data()!['amount_paid'] as num?)?.toDouble() ?? 0;
      final newPaid = paidSoFar + amount;
      final newStatus = newPaid >= owed ? 'Imelipwa' : 'Inadaiwa';

      txn.set(paymentRef, {
        'credit_sale_id': creditSaleId,
        'amount': amount,
        'payment_date': now,
        'notes': notes,
      });

      txn.update(creditRef, {'amount_paid': newPaid, 'status': newStatus});
    });
  }

  Future<double> getTotalOutstandingCredit() async {
    final credits = await getActiveCredits();
    return credits.fold<double>(0, (sum, c) => sum + c.balance);
  }

  Future<Map<String, dynamic>?> getHighestCreditCustomer() async {
    final credits = await getActiveCredits();
    if (credits.isEmpty) return null;

    final byCustomer = <String, double>{};
    final nameByCustomer = <String, String?>{};
    final phoneByCustomer = <String, String?>{};
    for (final c in credits) {
      byCustomer[c.customerId] = (byCustomer[c.customerId] ?? 0) + c.balance;
      nameByCustomer[c.customerId] = c.customerName;
      phoneByCustomer[c.customerId] = c.customerPhone;
    }

    final topEntry = byCustomer.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return {
      'name': nameByCustomer[topEntry.key],
      'phone': phoneByCustomer[topEntry.key],
      'balance': topEntry.value,
    };
  }
}
