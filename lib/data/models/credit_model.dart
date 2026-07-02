class CreditSaleModel {
  final String? id;
  final String saleId;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final double amountOwed;
  final double amountPaid;
  final String status; // Inadaiwa | Imelipwa
  final String createdAt;
  final String? createdBy; // Firebase uid wa aliyefanya mauzo haya

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
    this.createdBy,
  });

  double get balance => amountOwed - amountPaid;

  factory CreditSaleModel.fromMap(Map<String, dynamic> map, {String? id}) => CreditSaleModel(
        id: id ?? map['id'] as String?,
        saleId: map['sale_id'] as String,
        customerId: map['customer_id'] as String,
        customerName: map['customer_name'] as String?,
        customerPhone: map['customer_phone'] as String?,
        amountOwed: (map['amount_owed'] as num).toDouble(),
        amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
        status: map['status'] as String? ?? 'Inadaiwa',
        createdAt: map['created_at'] as String,
        createdBy: map['created_by'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'sale_id': saleId,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'amount_owed': amountOwed,
        'amount_paid': amountPaid,
        'status': status,
        'created_at': createdAt,
        'created_by': createdBy,
      };
}

class PaymentModel {
  final String? id;
  final String creditSaleId;
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

  factory PaymentModel.fromMap(Map<String, dynamic> map, {String? id}) => PaymentModel(
        id: id ?? map['id'] as String?,
        creditSaleId: map['credit_sale_id'] as String,
        amount: (map['amount'] as num).toDouble(),
        paymentDate: map['payment_date'] as String,
        notes: map['notes'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'credit_sale_id': creditSaleId,
        'amount': amount,
        'payment_date': paymentDate,
        'notes': notes,
      };
}
