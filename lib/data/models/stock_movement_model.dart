/// Aina za mabadiliko ya hifadhi (stock movement)
class StockMoveType {
  static const sale = 'Mauzo';
  static const purchase = 'Ongezeko (Ununuzi)';
  static const adjustment = 'Marekebisho';
  static const damage = 'Iliyoharibika';
  static const opening = 'Hifadhi ya Kuanzia';

  /// Aina zinazoweza kuchaguliwa na Msimamizi kwenye skrini ya marekebisho
  static const manual = [purchase, adjustment, damage];
}

/// StockMovementModel - Kumbukumbu moja ya mabadiliko ya hifadhi.
/// Kila mauzo na kila marekebisho huandika kumbukumbu hapa ndani ya transaction
/// ile ile inayobadilisha hifadhi, kwa hiyo historia haiwezi kupotea.
class StockMovementModel {
  final String? id;
  final String productId;
  final String? productName;
  final String type;
  final double change; // hasi = imetoka, chanya = imeingia
  final double before;
  final double after;
  final String? reason;
  final String? saleId;
  final String? receiptNumber;
  final String? userId;
  final String? userName;
  final String createdAt;

  StockMovementModel({
    this.id,
    required this.productId,
    this.productName,
    required this.type,
    required this.change,
    required this.before,
    required this.after,
    this.reason,
    this.saleId,
    this.receiptNumber,
    this.userId,
    this.userName,
    required this.createdAt,
  });

  factory StockMovementModel.fromMap(Map<String, dynamic> map, {String? id}) => StockMovementModel(
        id: id,
        productId: map['product_id'] as String,
        productName: map['product_name'] as String?,
        type: map['type'] as String? ?? StockMoveType.adjustment,
        change: (map['change'] as num).toDouble(),
        before: (map['before'] as num?)?.toDouble() ?? 0,
        after: (map['after'] as num?)?.toDouble() ?? 0,
        reason: map['reason'] as String?,
        saleId: map['sale_id'] as String?,
        receiptNumber: map['receipt_number'] as String?,
        userId: map['user_id'] as String?,
        userName: map['user_name'] as String?,
        createdAt: map['created_at'] as String,
      );

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
        'type': type,
        'change': change,
        'before': before,
        'after': after,
        'reason': reason,
        'sale_id': saleId,
        'receipt_number': receiptNumber,
        'user_id': userId,
        'user_name': userName,
        'created_at': createdAt,
      };
}
