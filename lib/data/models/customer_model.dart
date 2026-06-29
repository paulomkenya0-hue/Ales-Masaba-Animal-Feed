class CustomerModel {
  final int? id;
  final String name;
  final String? phone;
  final String? village;
  final String customerType; // Mkulima, Mteja wa Rejareja, Kampuni
  final String createdAt;

  CustomerModel({
    this.id,
    required this.name,
    this.phone,
    this.village,
    this.customerType = 'Mkulima',
    required this.createdAt,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> map) => CustomerModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        village: map['village'] as String?,
        customerType: map['customer_type'] as String? ?? 'Mkulima',
        createdAt: map['created_at'] as String,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'village': village,
        'customer_type': customerType,
        'created_at': createdAt,
      };
}
