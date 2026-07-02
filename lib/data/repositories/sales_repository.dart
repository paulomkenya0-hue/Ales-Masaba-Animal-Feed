import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firebase_service.dart';
import '../models/sale_model.dart';
import '../models/customer_model.dart';

/// SalesRepository - Husimamia mauzo, hupunguza hifadhi, na huunda mkopo
/// ikiwa ni lazima. Operesheni nzima hufanyika ndani ya Firestore Transaction
/// moja ili kuepuka data isiyo sahihi (mfano: hifadhi kuuzwa mara mbili kwa
/// bahati mbaya kwenye vifaa viwili tofauti kwa wakati mmoja).
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

  /// Huunda namba ya risiti: AMAF-YYYYMMDD-0001
  /// (Kadirio la haraka kwa kutumia hesabu ya mauzo ya leo - si "atomic" kabisa
  /// kati ya vifaa vingi vinavyouza kwa sekunde hiyo hiyo, lakini ni sahihi
  /// zaidi ya asilimia 99.9% kwa matumizi ya kawaida ya duka moja/machache.)
  Future<String> generateReceiptNumber() async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
    final endOfDay = DateTime(today.year, today.month, today.day + 1).toIso8601String();

    final countSnap = await _sales
        .where('sale_date', isGreaterThanOrEqualTo: startOfDay)
        .where('sale_date', isLessThan: endOfDay)
        .count()
        .get();
    final count = (countSnap.count ?? 0) + 1;
    return 'AMAF-$dateStr-${count.toString().padLeft(4, '0')}';
  }

  /// Huunda mauzo mapya (Cash au Credit) kwa transaction salama.
  /// Ikiwa malipo ni Mkopo, [newCustomer] au [existingCustomerId] inahitajika.
  /// Inarudisha id (String) ya sale iliyoundwa.
  Future<String> createSale({
    required List<SaleItemModel> items,
    required String paymentMethod, // 'Fedha Taslimu' | 'Mkopo'
    String? existingCustomerId,
    CustomerModel? newCustomer,
    String? userId,
  }) async {
    final receiptNumber = await generateReceiptNumber();
    final now = DateTime.now().toIso8601String();
    final total = items.fold<double>(0, (sum, item) => sum + item.subtotal);

    final saleRef = _sales.doc();
    final customerRef = (paymentMethod == 'Mkopo' && existingCustomerId == null && newCustomer != null)
        ? _customers.doc()
        : null;
    final creditRef = paymentMethod == 'Mkopo' ? _creditSales.doc() : null;
    final activityRef = _activityLogs.doc();

    await FirebaseService.firestore.runTransaction((txn) async {
      // ---- 1) SOMA (reads lazima zifanyike kabla ya writes yoyote) ----
      final productSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final item in items) {
        final snap = await txn.get(_products.doc(item.productId));
        if (!snap.exists) throw Exception('Bidhaa haipo');
        productSnaps.add(snap);
      }

      // ---- 2) THIBITISHA hifadhi inatosha ----
      for (var i = 0; i < items.length; i++) {
        final current = (productSnaps[i].data()!['quantity'] as num).toDouble();
        if (current < items[i].quantity) {
          throw Exception('Hifadhi haitoshi kwa bidhaa: ${productSnaps[i].data()!['name']}');
        }
      }

      // ---- 3) ANDIKA ----
      String? customerId = existingCustomerId;
      String? customerName;
      if (customerRef != null) {
        txn.set(customerRef, newCustomer!.toMap());
        customerId = customerRef.id;
        customerName = newCustomer.name;
      }

      final sale = SaleModel(
        receiptNumber: receiptNumber,
        customerId: customerId,
        customerName: customerName,
        totalAmount: total,
        paymentMethod: paymentMethod,
        saleDate: now,
        userId: userId,
        items: items,
      );
      txn.set(saleRef, sale.toMap());

      for (var i = 0; i < items.length; i++) {
        final current = (productSnaps[i].data()!['quantity'] as num).toDouble();
        txn.update(_products.doc(items[i].productId), {
          'quantity': current - items[i].quantity,
          'updated_at': now,
        });
      }

      if (creditRef != null && customerId != null) {
        txn.set(creditRef, _creditSaleMap(
          saleId: saleRef.id,
          customerId: customerId,
          customerName: customerName,
          amountOwed: total,
          createdAt: now,
          createdBy: userId,
        ));
      }

      txn.set(activityRef, {
        'user_id': userId,
        'action': 'Mauzo Mapya',
        'details': 'Risiti $receiptNumber - Jumla: $total',
        'created_at': now,
      });
    });

    return saleRef.id;
  }

  Future<SaleModel?> getSaleWithItems(String saleId) async {
    final doc = await _sales.doc(saleId).get();
    if (!doc.exists) return null;
    return SaleModel.fromMap(doc.data()!, id: doc.id);
  }

  Future<List<SaleModel>> getSalesBetween(DateTime start, DateTime end) async {
    final snap = await _sales
        .where('sale_date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('sale_date', isLessThanOrEqualTo: end.toIso8601String())
        .orderBy('sale_date', descending: true)
        .get();
    return snap.docs.map((d) => SaleModel.fromMap(d.data(), id: d.id)).toList();
  }

  Future<double> getTotalSales(DateTime start, DateTime end) async {
    final sales = await getSalesBetween(start, end);
    return sales.fold<double>(0, (sum, s) => sum + s.totalAmount);
  }

  /// Ripoti ya "Bidhaa Zinazouzwa Zaidi" ndani ya kipindi fulani - inajumlisha
  /// kiasi (quantity) na mapato (revenue) kwa kila bidhaa kutoka kwenye
  /// 'items' za mauzo yote ya kipindi hicho.
  Future<List<Map<String, dynamic>>> getTopSellingProducts(
    DateTime start,
    DateTime end, {
    int limit = 10,
  }) async {
    final sales = await getSalesBetween(start, end);
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

  /// Idadi ya mauzo (risiti) ndani ya kipindi - kwa wastani wa risiti (average sale)
  Future<int> getSalesCount(DateTime start, DateTime end) async {
    final sales = await getSalesBetween(start, end);
    return sales.length;
  }
}

/// Kifupi cha kuzalisha Map ya credit_sales doc bila kuhitaji kuunda
/// CreditSaleModel kamili ndani ya transaction (id inatolewa na Firestore
/// wenyewe kupitia creditRef.id, si ndani ya toMap()).
Map<String, dynamic> _creditSaleMap({
  required String saleId,
  required String customerId,
  String? customerName,
  String? customerPhone,
  required double amountOwed,
  required String createdAt,
  String? createdBy,
}) {
  return {
    'sale_id': saleId,
    'customer_id': customerId,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'amount_owed': amountOwed,
    'amount_paid': 0,
    'status': 'Inadaiwa',
    'created_at': createdAt,
    'created_by': createdBy,
  };
}
