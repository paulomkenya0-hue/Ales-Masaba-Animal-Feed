import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firebase_service.dart';
import '../models/credit_model.dart';
import '../models/sale_model.dart';

/// CreditRepository - Husimamia madeni ya wateja na malipo (sehemu/kamili).
/// Malipo yamehifadhiwa kama "subcollection" chini ya kila credit_sales/{id}
/// ili historia ibaki daima, hata deni likilipwa kikamilifu.
///
/// Usalama wa malipo (ndani ya transaction moja):
///  - malipo hayawezi kuzidi deni lililobaki (hakuna overpayment)
///  - [requestId] huzuia malipo kurekodiwa mara mbili (bonyeza mara mbili / retry)
///  - sale doc inasasishwa pamoja, ili risiti na ripoti zionyeshe salio sahihi
class CreditRepository {
  CollectionReference<Map<String, dynamic>> get _creditSales =>
      FirebaseService.firestore.collection('credit_sales');
  CollectionReference<Map<String, dynamic>> get _sales =>
      FirebaseService.firestore.collection('sales');

  /// Madeni yanayodaiwa. Cashier LAZIMA apitishe [createdBy] (uid yake) kwa sababu
  /// Firestore Rules zinamruhusu kuona madeni aliyoyaanzisha yeye tu.
  /// (Hakuna orderBy kwenye seva - tunapanga hapa ili tusihitaji composite index.)
  Future<List<CreditSaleModel>> getActiveCredits({String? createdBy}) async {
    Query<Map<String, dynamic>> q = _creditSales.where('status', isEqualTo: 'Inadaiwa');
    if (createdBy != null) q = q.where('created_by', isEqualTo: createdBy);
    final snap = await q.get();
    final list = snap.docs.map((d) => CreditSaleModel.fromMap(d.data(), id: d.id)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<PaymentModel>> getPaymentHistory(String creditSaleId) async {
    final snap = await _creditSales
        .doc(creditSaleId)
        .collection('payments')
        .orderBy('payment_date', descending: true)
        .get();
    return snap.docs.map((d) => PaymentModel.fromMap(d.data(), id: d.id)).toList();
  }

  /// Hurekodi malipo (sehemu au kamili). Deni likilipwa lote, hali inakuwa
  /// 'Imelipwa'. Hutupa Exception kama kiasi kinazidi deni.
  ///
  /// [requestId]: kitambulisho cha ombi (tengeneza kimoja kwa kila kufungua
  /// dirisha la malipo). Ombi lile lile likirudiwa halirekodiwi mara ya pili.
  Future<void> recordPayment(
    String creditSaleId,
    double amount, {
    String? notes,
    String method = PayMethod.cash,
    String? reference,
    String? cashierId,
    String? cashierName,
    String? requestId,
  }) async {
    if (amount <= 0) throw Exception('Kiasi cha malipo lazima kiwe zaidi ya sifuri');
    if (!PayMethod.receivable.contains(method)) throw Exception('Njia ya malipo si sahihi');
    if (method == PayMethod.mobileMoney && (reference == null || reference.trim().isEmpty)) {
      throw Exception('Weka namba ya muamala wa Pesa ya Simu');
    }

    final now = DateTime.now().toIso8601String();
    final creditRef = _creditSales.doc(creditSaleId);
    final paymentRef = requestId != null
        ? creditRef.collection('payments').doc(requestId)
        : creditRef.collection('payments').doc();

    await FirebaseService.firestore.runTransaction((txn) async {
      // ---- SOMA kwanza ----
      final creditSnap = await txn.get(creditRef);
      if (!creditSnap.exists) throw Exception('Deni halipo');

      if (requestId != null) {
        final dup = await txn.get(paymentRef);
        if (dup.exists) return; // malipo haya yalisharekodiwa
      }

      final data = creditSnap.data()!;
      final saleId = data['sale_id'] as String?;
      DocumentSnapshot<Map<String, dynamic>>? saleSnap;
      if (saleId != null) saleSnap = await txn.get(_sales.doc(saleId));

      final owed = (data['amount_owed'] as num).toDouble();
      final paidSoFar = (data['amount_paid'] as num?)?.toDouble() ?? 0;
      final balance = owed - paidSoFar;

      if (balance <= 0.0001) throw Exception('Deni hili tayari limelipwa lote');
      if (amount > balance + 0.0001) {
        throw Exception('Kiasi kinazidi deni lililobaki (TZS ${balance.toStringAsFixed(0)})');
      }

      final newPaid = paidSoFar + amount;
      final fullyPaid = newPaid >= owed - 0.0001;

      // ---- ANDIKA ----
      txn.set(paymentRef, {
        'credit_sale_id': creditSaleId,
        'amount': amount,
        'payment_date': now,
        'notes': notes,
        'method': method,
        'reference': reference?.trim().isEmpty ?? true ? null : reference!.trim(),
        'cashier_id': cashierId,
        'cashier_name': cashierName,
      });

      txn.update(creditRef, {
        'amount_paid': newPaid,
        'status': fullyPaid ? 'Imelipwa' : 'Inadaiwa',
      });

      if (saleSnap != null && saleSnap.exists) {
        txn.update(_sales.doc(saleId), {
          'amount_paid': newPaid,
          'balance': (owed - newPaid).clamp(0, double.infinity),
          'payment_status': fullyPaid ? 'Imelipwa' : 'Sehemu',
        });
      }
    });
  }

  Future<double> getTotalOutstandingCredit({String? createdBy}) async {
    final credits = await getActiveCredits(createdBy: createdBy);
    return credits.fold<double>(0, (sum, c) => sum + c.balance);
  }

  /// Wateja wote wenye deni, mkubwa kwanza (jumla ya madeni yao yote).
  Future<List<Map<String, dynamic>>> getDebtorsRanked({String? createdBy}) async {
    final credits = await getActiveCredits(createdBy: createdBy);
    final byCustomer = <String, double>{};
    final nameByCustomer = <String, String?>{};
    final phoneByCustomer = <String, String?>{};
    for (final c in credits) {
      byCustomer[c.customerId] = (byCustomer[c.customerId] ?? 0) + c.balance;
      nameByCustomer[c.customerId] = c.customerName;
      phoneByCustomer[c.customerId] = c.customerPhone;
    }
    final rows = byCustomer.entries
        .map((e) => {
              'customerId': e.key,
              'name': nameByCustomer[e.key],
              'phone': phoneByCustomer[e.key],
              'balance': e.value,
            })
        .toList();
    rows.sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));
    return rows;
  }

  Future<Map<String, dynamic>?> getHighestCreditCustomer() async {
    final rows = await getDebtorsRanked();
    return rows.isEmpty ? null : rows.first;
  }
}
