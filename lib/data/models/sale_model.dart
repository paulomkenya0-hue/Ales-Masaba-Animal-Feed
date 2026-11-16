/// Njia za malipo zinazotumika kwenye mauzo.
/// 'Fedha Taslimu' na 'Mkopo' zilikuwepo tangu mwanzo (data ya zamani inabaki sahihi).
class PayMethod {
  static const cash = 'Fedha Taslimu';
  static const mobileMoney = 'Pesa ya Simu';
  static const credit = 'Mkopo';

  /// Njia zinazoweza kutumika kupokea pesa (Mkopo si njia ya kupokea pesa)
  static const receivable = [cash, mobileMoney];
}

class SaleItemModel {
  final String? id;
  final String? saleId;
  final String productId;
  final String? productName; // kwa ajili ya kuonyesha tu
  final String? unit; // Kg, Mfuko, Lita...
  final double quantity;
  final double unitPrice;
  final double subtotal;

  SaleItemModel({
    this.id,
    this.saleId,
    required this.productId,
    this.productName,
    this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  SaleItemModel copyWith({double? quantity, double? unitPrice}) {
    final q = quantity ?? this.quantity;
    final p = unitPrice ?? this.unitPrice;
    return SaleItemModel(
      id: id,
      saleId: saleId,
      productId: productId,
      productName: productName,
      unit: unit,
      quantity: q,
      unitPrice: p,
      subtotal: q * p,
    );
  }

  factory SaleItemModel.fromMap(Map<String, dynamic> map) => SaleItemModel(
        saleId: map['sale_id'] as String?,
        productId: map['product_id'] as String,
        productName: map['product_name'] as String?,
        unit: map['unit'] as String?,
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        subtotal: (map['subtotal'] as num).toDouble(),
      );

  /// Muundo wa kuhifadhiwa ndani ya 'items' array kwenye sale doc ya Firestore
  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
        'unit': unit,
        'quantity': quantity,
        'unit_price': unitPrice,
        'subtotal': subtotal,
      };
}

class SaleModel {
  final String? id;
  final String receiptNumber;
  final String? customerId;
  final String? customerName; // kwa ajili ya kuonyesha tu (imehifadhiwa moja kwa moja kwenye doc)
  final double totalAmount;

  /// Njia iliyotumika kulipa kiasi cha awali: Fedha Taslimu | Pesa ya Simu.
  /// 'Mkopo' ikiwa hakuna kiasi kilicholipwa wakati wa mauzo.
  final String paymentMethod;
  final String saleDate;
  final String? userId; // Firebase Auth uid wa aliyeuza
  final String? cashierName;
  final String? branchName;
  final List<SaleItemModel> items;

  /// Kiasi kilicholipwa WAKATI WA MAUZO (malipo ya baadaye ya deni yanaonekana
  /// kwenye credit_sales/{id}/payments, na yanasasisha [amountPaid] hapa pia).
  final double amountPaid;
  final String? paymentReference; // namba ya muamala wa Pesa ya Simu
  final double changeGiven; // chenji (ikiwa mteja alitoa zaidi ya jumla - Taslimu)

  /// Ufunguo wa kuzuia mauzo kurudiwa (retry / bonyeza mara mbili)
  final String? clientRequestId;

  SaleModel({
    this.id,
    required this.receiptNumber,
    this.customerId,
    this.customerName,
    required this.totalAmount,
    required this.paymentMethod,
    required this.saleDate,
    this.userId,
    this.cashierName,
    this.branchName,
    this.items = const [],
    double? amountPaid,
    this.paymentReference,
    this.changeGiven = 0,
    this.clientRequestId,
  }) : amountPaid = amountPaid ?? (paymentMethod == PayMethod.credit ? 0 : totalAmount);

  double get balance => (totalAmount - amountPaid).clamp(0, double.infinity).toDouble();
  bool get isFullyPaid => balance <= 0.0001;
  bool get hasDebt => !isFullyPaid;

  /// Hali ya malipo kwa kuonyesha: Imelipwa | Sehemu | Deni
  String get paymentStatus => isFullyPaid ? 'Imelipwa' : (amountPaid > 0 ? 'Sehemu' : 'Deni');

  factory SaleModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final method = map['payment_method'] as String? ?? PayMethod.cash;
    final total = (map['total_amount'] as num).toDouble();
    return SaleModel(
      id: id ?? map['id'] as String?,
      receiptNumber: map['receipt_number'] as String,
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      totalAmount: total,
      paymentMethod: method,
      saleDate: map['sale_date'] as String,
      userId: map['user_id'] as String?,
      cashierName: map['cashier_name'] as String?,
      branchName: map['branch_name'] as String?,
      items: (map['items'] as List<dynamic>? ?? [])
          .map((i) => SaleItemModel.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList(),
      // Mauzo ya zamani hayana 'amount_paid': Taslimu = imelipwa yote, Mkopo = hakuna.
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? (method == PayMethod.credit ? 0 : total),
      paymentReference: map['payment_reference'] as String?,
      changeGiven: (map['change_given'] as num?)?.toDouble() ?? 0,
      clientRequestId: map['client_request_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'receipt_number': receiptNumber,
        'customer_id': customerId,
        'customer_name': customerName,
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'sale_date': saleDate,
        'user_id': userId,
        'cashier_name': cashierName,
        'branch_name': branchName,
        'items': items.map((i) => i.toMap()).toList(),
        'amount_paid': amountPaid,
        'balance': balance,
        'payment_status': paymentStatus,
        'payment_reference': paymentReference,
        'change_given': changeGiven,
        'client_request_id': clientRequestId,
      };
}
