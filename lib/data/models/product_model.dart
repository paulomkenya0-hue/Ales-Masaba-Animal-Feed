class ProductModel {
  final int? id;
  final String name;
  final int? categoryId;
  final String? categoryName; // imejazwa kupitia JOIN, si kwenye jedwali
  final double buyingPrice;
  final double retailPrice;
  final double wholesalePrice;
  final double quantity;
  final String unit;
  final double lowStockLimit;
  final String? barcode;
  final String? imagePath;
  final String createdAt;
  final String? updatedAt;
  final bool isActive;

  ProductModel({
    this.id,
    required this.name,
    this.categoryId,
    this.categoryName,
    this.buyingPrice = 0,
    this.retailPrice = 0,
    this.wholesalePrice = 0,
    this.quantity = 0,
    this.unit = 'Kg',
    this.lowStockLimit = 10,
    this.barcode,
    this.imagePath,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  bool get isLowStock => quantity <= lowStockLimit;
  bool get isOutOfStock => quantity <= 0;

  factory ProductModel.fromMap(Map<String, dynamic> map) => ProductModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        categoryId: map['category_id'] as int?,
        categoryName: map['category_name'] as String?,
        buyingPrice: (map['buying_price'] as num?)?.toDouble() ?? 0,
        retailPrice: (map['retail_price'] as num?)?.toDouble() ?? 0,
        wholesalePrice: (map['wholesale_price'] as num?)?.toDouble() ?? 0,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        unit: map['unit'] as String? ?? 'Kg',
        lowStockLimit: (map['low_stock_limit'] as num?)?.toDouble() ?? 10,
        barcode: map['barcode'] as String?,
        imagePath: map['image_path'] as String?,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String?,
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'category_id': categoryId,
        'buying_price': buyingPrice,
        'retail_price': retailPrice,
        'wholesale_price': wholesalePrice,
        'quantity': quantity,
        'unit': unit,
        'low_stock_limit': lowStockLimit,
        'barcode': barcode,
        'image_path': imagePath,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'is_active': isActive ? 1 : 0,
      };

  ProductModel copyWith({
    String? name,
    int? categoryId,
    double? buyingPrice,
    double? retailPrice,
    double? wholesalePrice,
    double? quantity,
    String? unit,
    double? lowStockLimit,
    String? barcode,
    String? imagePath,
    String? updatedAt,
  }) {
    return ProductModel(
      id: id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      retailPrice: retailPrice ?? this.retailPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      lowStockLimit: lowStockLimit ?? this.lowStockLimit,
      barcode: barcode ?? this.barcode,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive,
    );
  }
}
