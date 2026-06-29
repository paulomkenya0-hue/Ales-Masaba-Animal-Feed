class SaleItemModel {
  final int? id;
  final int? saleId;
  final int productId;
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
        id: map['id'] as int?,
        saleId: map['sale_id'] as int?,
        productId: map['product_id'] as int,
        productName: map['product_name'] as String?,
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        subtotal: (map['subtotal'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (saleId != null) 'sale_id': saleId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'subtotal': subtotal,
      };
}

class SaleModel {
  final int? id;
  final String receiptNumber;
  final int? customerId;
  final String? customerName; // kwa ajili ya kuonyesha tu
  final double totalAmount;
  final String paymentMethod; // Fedha Taslimu | Mkopo
  final String saleDate;
  final int? userId;
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

  factory SaleModel.fromMap(Map<String, dynamic> map) => SaleModel(
        id: map['id'] as int?,
        receiptNumber: map['receipt_number'] as String,
        customerId: map['customer_id'] as int?,
        customerName: map['customer_name'] as String?,
        totalAmount: (map['total_amount'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String,
        saleDate: map['sale_date'] as String,
        userId: map['user_id'] as int?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'receipt_number': receiptNumber,
        'customer_id': customerId,
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'sale_date': saleDate,
        'user_id': userId,
      };
}
