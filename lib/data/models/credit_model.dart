class CreditSaleModel {
  final int? id;
  final int saleId;
  final int customerId;
  final String? customerName;
  final String? customerPhone;
  final double amountOwed;
  final double amountPaid;
  final String status; // Inadaiwa | Imelipwa
  final String createdAt;

  CreditSaleModel({
    this.id,
    required this.saleId,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    required this.amountOwed,
    this.amountPaid = 0,
    this.status = 'Inadaiwa',
    required this.createdAt,
  });

  double get balance => amountOwed - amountPaid;

  factory CreditSaleModel.fromMap(Map<String, dynamic> map) => CreditSaleModel(
        id: map['id'] as int?,
        saleId: map['sale_id'] as int,
        customerId: map['customer_id'] as int,
        customerName: map['customer_name'] as String?,
        customerPhone: map['customer_phone'] as String?,
        amountOwed: (map['amount_owed'] as num).toDouble(),
        amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
        status: map['status'] as String? ?? 'Inadaiwa',
        createdAt: map['created_at'] as String,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sale_id': saleId,
        'customer_id': customerId,
        'amount_owed': amountOwed,
        'amount_paid': amountPaid,
        'status': status,
        'created_at': createdAt,
      };
}

class PaymentModel {
  final int? id;
  final int creditSaleId;
  final double amount;
  final String paymentDate;
  final String? notes;

  PaymentModel({
    this.id,
    required this.creditSaleId,
    required this.amount,
    required this.paymentDate,
    this.notes,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) => PaymentModel(
        id: map['id'] as int?,
        creditSaleId: map['credit_sale_id'] as int,
        amount: (map['amount'] as num).toDouble(),
        paymentDate: map['payment_date'] as String,
        notes: map['notes'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'credit_sale_id': creditSaleId,
        'amount': amount,
        'payment_date': paymentDate,
        'notes': notes,
      };
}
