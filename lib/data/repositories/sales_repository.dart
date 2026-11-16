import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firebase_service.dart';
import '../models/sale_model.dart';
import '../models/customer_model.dart';
import '../models/stock_movement_model.dart';

/// SalesRepository - Husimamia mauzo, hupunguza hifadhi, hurekodi malipo na
/// huunda deni ikiwa ni lazima. Operesheni nzima (mauzo + hifadhi + historia ya
/// hifadhi + deni + malipo + namba ya risiti) hufanyika ndani ya Firestore
/// Transaction MOJA - ama vyote vinaandikwa, ama hakuna kinachoandikwa.
///
/// Kuzuia kurudiwa (retry / kubonyeza mara mbili): kila mauzo yana
/// `clientRequestId` ambayo ndiyo jina la sale doc. Transaction ikirudiwa
/// (mtandao ukikatika na app ikajaribu tena), inakuta doc ipo na inarudisha
/// risiti ile ile BILA kupunguza hifadhi tena.
class SalesRepository {
  CollectionReference<Map<String, dynamic>> get _sales =>
      FirebaseService.firestore.collection('sales');
  CollectionReference<Map<String, dynamic>> get _products =>
      FirebaseService.firestore.collection('products');
  CollectionReference<Map<String, dynamic>> get _customers =>
      FirebaseService.firestore.collection('customers');
  CollectionReference<Map<String, dynamic>> get _creditSales =>
      FirebaseService.firestore.collection('credit_sales');
  CollectionReference<Map<String, dynamic>> get _activityLogs =>
      FirebaseService.firestore.collection('activity_logs');
  CollectionReference<Map<String, dynamic>> get _stockMovements =>
      FirebaseService.firestore.collection('stock_movements');
  CollectionReference<Map<String, dynamic>> get _counters =>
      FirebaseService.firestore.collection('counters');

  static String _dateKey(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// Mbegu ya namba ya risiti kwa siku ambayo kaunta bado haijaundwa
  /// (inalinda dhidi ya kugongana na risiti zilizotolewa na toleo la zamani
  /// siku ya uhamisho). Cashier hana ruhusa ya kuhesabu mauzo ya wote, kwa
  /// hiyo ikishindikana tunaanza na 0 - hatari ni siku ya uhamisho pekee.
  Future<int> _legacyTodayCount(DateTime today) async {
    try {
      final start = DateTime(today.year, today.month, today.day).toIso8601String();
      final end = DateTime(today.year, today.month, today.day + 1).toIso8601String();
      final snap = await _sales
          .where('sale_date', isGreaterThanOrEqualTo: start)
          .where('sale_date', isLessThan: end)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Huunda mauzo mapya kwa transaction salama. Inarudisha id ya sale.
  ///
  /// - [amountPaid]: kiasi alichotoa mteja sasa. Kikizidi jumla (Taslimu), tofauti
  ///   inakuwa chenji; Pesa ya Simu haiwezi kuzidi jumla.
  /// - Ikiwa kuna salio (balance > 0), mteja (aliyepo au mpya) ni lazima.
  /// - [allowOverstock]: Msimamizi pekee. Hifadhi haishuki chini ya 0 - upungufu
  ///   unarekodiwa kwenye historia ya hifadhi.
  Future<String> createSale({
    required List<SaleItemModel> items,
    required String clientRequestId,
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
    // ---------- Uthibitisho wa awali (kabla ya kugusa database) ----------
    if (items.isEmpty) throw Exception('Chagua angalau bidhaa moja');
    for (final it in items) {
      if (it.quantity <= 0) throw Exception('Kiasi cha ${it.productName ?? 'bidhaa'} si sahihi');
      if (it.unitPrice < 0) throw Exception('Bei ya ${it.productName ?? 'bidhaa'} si sahihi');
    }
    if (amountPaid < 0) throw Exception('Kiasi kilicholipwa si sahihi');

    final total = items.fold<double>(0, (s, i) => s + i.quantity * i.unitPrice);
    if (total <= 0) throw Exception('Jumla ya mauzo lazima iwe zaidi ya sifuri');

    final isMobile = paymentMethod == PayMethod.mobileMoney;
    if (amountPaid > total && isMobile) {
      throw Exception('Malipo ya Pesa ya Simu hayawezi kuzidi jumla ya mauzo');
    }
    final paid = amountPaid > total ? total : amountPaid;
    final change = amountPaid > total ? amountPaid - total : 0.0;
    final balance = total - paid;

    if (isMobile && paid > 0 && (paymentReference == null || paymentReference.trim().isEmpty)) {
      throw Exception('Weka namba ya muamala wa Pesa ya Simu');
    }
    final hasCustomer = existingCustomerId != null || newCustomer != null;
    if (balance > 0.0001 && !hasCustomer) {
      throw Exception('Mauzo yenye deni yanahitaji mteja');
    }

    // Njia ya malipo inayohifadhiwa: 'Mkopo' ikiwa hakuna kilicholipwa
    final storedMethod = paid <= 0 ? PayMethod.credit : paymentMethod;

    // Jumlisha kiasi kwa kila bidhaa (bidhaa ileile ikiwa mara mbili kwenye orodha)
    final qtyByProduct = <String, double>{};
    for (final it in items) {
      qtyByProduct[it.productId] = (qtyByProduct[it.productId] ?? 0) + it.quantity;
    }

    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final dateKey = _dateKey(now);
    final counterRef = _counters.doc('receipts_$dateKey');
    final seed = await _legacyTodayCount(now);

    final saleRef = _sales.doc(clientRequestId);
    final customerRef = (existingCustomerId == null && newCustomer != null) ? _customers.doc() : null;
    final creditRef = balance > 0.0001 ? _creditSales.doc(clientRequestId) : null;
    final activityRef = _activityLogs.doc();

    await FirebaseService.firestore.runTransaction((txn) async {
      // ---- 1) SOMA zote kwanza (sheria ya Firestore: reads kabla ya writes) ----
      final existingSale = await txn.get(saleRef);
      if (existingSale.exists) return; // tayari imerekodiwa - usirudie (idempotent)

      final counterSnap = await txn.get(counterRef);

      final productSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final pid in qtyByProduct.keys) {
        final snap = await txn.get(_products.doc(pid));
        if (!snap.exists) throw Exception('Bidhaa haipo tena kwenye mfumo');
        if (snap.data()!['is_active'] == false) {
          throw Exception('Bidhaa ${snap.data()!['name']} imeondolewa');
        }
        productSnaps[pid] = snap;
      }

      // ---- 2) THIBITISHA hifadhi ----
      final newQty = <String, double>{};
      final shortfall = <String, double>{};
      for (final e in qtyByProduct.entries) {
        final data = productSnaps[e.key]!.data()!;
        final current = (data['quantity'] as num?)?.toDouble() ?? 0;
        if (current < e.value) {
          if (!allowOverstock) {
            throw Exception(
                'Hifadhi haitoshi: ${data['name']} (imebaki ${_fmt(current)}, unahitaji ${_fmt(e.value)})');
          }
          shortfall[e.key] = e.value - current;
          newQty[e.key] = 0; // kamwe si hasi
        } else {
          newQty[e.key] = current - e.value;
        }
      }

      // ---- 3) NAMBA YA RISITI (kaunta ya kila siku, ndani ya transaction) ----
      final lastCount = counterSnap.exists ? ((counterSnap.data()!['count'] as num?)?.toInt() ?? 0) : seed;
      final nextCount = lastCount + 1;
      final receiptNumber = 'AMAF-$dateKey-${nextCount.toString().padLeft(4, '0')}';

      // ---- 4) ANDIKA ----
      txn.set(counterRef, {'count': nextCount, 'date': dateKey});

      String? customerId = existingCustomerId;
      String? customerName = existingCustomerName;
      String? customerPhone = existingCustomerPhone;
      if (customerRef != null) {
        txn.set(customerRef, newCustomer!.toMap());
        customerId = customerRef.id;
        customerName = newCustomer.name;
        customerPhone = newCustomer.phone;
      }

      final sale = SaleModel(
        receiptNumber: receiptNumber,
        customerId: customerId,
        customerName: customerName,
        totalAmount: total,
        paymentMethod: storedMethod,
        saleDate: nowIso,
        userId: userId,
        cashierName: cashierName,
        branchName: branchName,
        items: items
            .map((i) => SaleItemModel(
                  productId: i.productId,
                  productName: i.productName,
                  unit: i.unit,
                  quantity: i.quantity,
                  unitPrice: i.unitPrice,
                  subtotal: i.quantity * i.unitPrice,
                ))
            .toList(),
        amountPaid: paid,
        paymentReference: paymentReference?.trim().isEmpty ?? true ? null : paymentReference!.trim(),
        changeGiven: change,
        clientRequestId: clientRequestId,
      );
      txn.set(saleRef, sale.toMap());

      for (final e in newQty.entries) {
        final data = productSnaps[e.key]!.data()!;
        final before = (data['quantity'] as num?)?.toDouble() ?? 0;
        txn.update(_products.doc(e.key), {'quantity': e.value, 'updated_at': nowIso});
        txn.set(
          _stockMovements.doc('${clientRequestId}_${e.key}'),
          StockMovementModel(
            productId: e.key,
            productName: data['name'] as String?,
            type: StockMoveType.sale,
            change: e.value - before,
            before: before,
            after: e.value,
            reason: shortfall.containsKey(e.key)
                ? 'Imeuzwa zaidi ya hifadhi kwa ${_fmt(shortfall[e.key]!)} (idhini ya Msimamizi)'
                : null,
            saleId: saleRef.id,
            receiptNumber: receiptNumber,
            userId: userId,
            userName: cashierName,
            createdAt: nowIso,
          ).toMap(),
        );
      }

      if (creditRef != null && customerId != null) {
        txn.set(creditRef, {
          'sale_id': saleRef.id,
          'customer_id': customerId,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'receipt_number': receiptNumber,
          'amount_owed': total,
          'amount_paid': paid,
          'status': 'Inadaiwa',
          'created_at': nowIso,
          'created_by': userId,
          'branch_name': branchName,
        });
        if (paid > 0) {
          txn.set(creditRef.collection('payments').doc('initial'), {
            'credit_sale_id': creditRef.id,
            'amount': paid,
            'payment_date': nowIso,
            'notes': 'Malipo ya awali wakati wa mauzo',
            'method': storedMethod,
            'reference': sale.paymentReference,
            'cashier_id': userId,
            'cashier_name': cashierName,
          });
        }
      }

      txn.set(activityRef, {
        'user_id': userId,
        'action': 'Mauzo Mapya',
        'details': 'Risiti $receiptNumber - Jumla: ${_fmt(total)} - Imelipwa: ${_fmt(paid)}',
        'created_at': nowIso,
      });
    });

    return saleRef.id;
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<SaleModel?> getSaleWithItems(String saleId) async {
    final doc = await _sales.doc(saleId).get();
    if (!doc.exists) return null;
    return SaleModel.fromMap(doc.data()!, id: doc.id);
  }

  /// Mauzo ndani ya kipindi. Cashier LAZIMA apitishe [userId] (uid yake) -
  /// Firestore Rules hazichuji matokeo, zinakataa swali lote lisilo na kichujio hicho.
  Future<List<SaleModel>> getSalesBetween(DateTime start, DateTime end, {String? userId}) async {
    Query<Map<String, dynamic>> q = _sales;
    if (userId != null) q = q.where('user_id', isEqualTo: userId);
    final snap = await q
        .where('sale_date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('sale_date', isLessThanOrEqualTo: end.toIso8601String())
        .orderBy('sale_date', descending: true)
        .get();
    return snap.docs.map((d) => SaleModel.fromMap(d.data(), id: d.id)).toList();
  }

  Future<double> getTotalSales(DateTime start, DateTime end, {String? userId}) async {
    final sales = await getSalesBetween(start, end, userId: userId);
    return sales.fold<double>(0, (sum, s) => sum + s.totalAmount);
  }

  /// Ripoti ya "Bidhaa Zinazouzwa Zaidi" ndani ya kipindi.
  Future<List<Map<String, dynamic>>> getTopSellingProducts(
    DateTime start,
    DateTime end, {
    int limit = 10,
    String? userId,
  }) async {
    final sales = await getSalesBetween(start, end, userId: userId);
    final Map<String, double> qtyByProduct = {};
    final Map<String, double> revenueByProduct = {};
    final Map<String, String> nameByProduct = {};

    for (final sale in sales) {
      for (final item in sale.items) {
        qtyByProduct[item.productId] = (qtyByProduct[item.productId] ?? 0) + item.quantity;
        revenueByProduct[item.productId] = (revenueByProduct[item.productId] ?? 0) + item.subtotal;
        nameByProduct[item.productId] = item.productName ?? item.productId;
      }
    }

    final rows = qtyByProduct.entries
        .map((e) => {
              'productId': e.key,
              'productName': nameByProduct[e.key],
              'quantity': e.value,
              'revenue': revenueByProduct[e.key] ?? 0,
            })
        .toList();

    rows.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    return rows.take(limit).toList();
  }

  Future<int> getSalesCount(DateTime start, DateTime end, {String? userId}) async {
    final sales = await getSalesBetween(start, end, userId: userId);
    return sales.length;
  }

  /// Utendaji wa kila muuzaji (Msimamizi pekee): idadi ya mauzo na jumla.
  Future<List<Map<String, dynamic>>> getCashierPerformance(DateTime start, DateTime end) async {
    final sales = await getSalesBetween(start, end);
    return _groupSales(sales, (s) => s.cashierName ?? s.userId ?? 'Haijulikani');
  }

  /// Mauzo kwa kila tawi/duka (Msimamizi pekee).
  Future<List<Map<String, dynamic>>> getBranchSales(DateTime start, DateTime end) async {
    final sales = await getSalesBetween(start, end);
    return _groupSales(sales, (s) => s.branchName ?? 'Duka Kuu');
  }

  List<Map<String, dynamic>> _groupSales(List<SaleModel> sales, String Function(SaleModel) keyOf) {
    final total = <String, double>{};
    final paid = <String, double>{};
    final count = <String, int>{};
    for (final s in sales) {
      final k = keyOf(s);
      total[k] = (total[k] ?? 0) + s.totalAmount;
      paid[k] = (paid[k] ?? 0) + s.amountPaid;
      count[k] = (count[k] ?? 0) + 1;
    }
    final rows = total.keys
        .map((k) => {'name': k, 'total': total[k]!, 'paid': paid[k]!, 'count': count[k]!})
        .toList();
    rows.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return rows;
  }
}
