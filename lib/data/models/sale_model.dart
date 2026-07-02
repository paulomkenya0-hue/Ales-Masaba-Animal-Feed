class SaleItemModel {
  final String? id;
  final String? saleId;
  final String productId;
  final String? productName; // kwa ajili ya kuonyesha tu
  final double quantity;
  final double unitPrice;
  final double subtotal;

  SaleItemModel({
    this.id,
    this.saleId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory SaleItemModel.fromMap(Map<String, dynamic> map) => SaleItemModel(
        saleId: map['sale_id'] as String?,
        productId: map['product_id'] as String,
        productName: map['product_name'] as String?,
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        subtotal: (map['subtotal'] as num).toDouble(),
      );

  /// Muundo wa kuhifadhiwa ndani ya 'items' array kwenye sale doc ya Firestore
  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
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
  final String paymentMethod; // Fedha Taslimu | Mkopo
  final String saleDate;
  final String? userId; // Firebase Auth uid wa aliyeuza
  final List<SaleItemModel> items;

  SaleModel({
    this.id,
    required this.receiptNumber,
    this.customerId,
    this.customerName,
    required this.totalAmount,
    required this.paymentMethod,
    required this.saleDate,
    this.userId,
    this.items = const [],
  });

  factory SaleModel.fromMap(Map<String, dynamic> map, {String? id}) => SaleModel(
        id: id ?? map['id'] as String?,
        receiptNumber: map['receipt_number'] as String,
        customerId: map['customer_id'] as String?,
        customerName: map['customer_name'] as String?,
        totalAmount: (map['total_amount'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String,
        saleDate: map['sale_date'] as String,
        userId: map['user_id'] as String?,
        items: (map['items'] as List<dynamic>? ?? [])
            .map((i) => SaleItemModel.fromMap(Map<String, dynamic>.from(i as Map)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'receipt_number': receiptNumber,
        'customer_id': customerId,
        'customer_name': customerName,
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'sale_date': saleDate,
        'user_id': userId,
        'items': items.map((i) => i.toMap()).toList(),
      };
}
