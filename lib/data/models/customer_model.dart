class CustomerModel {
  final String? id;
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

  factory CustomerModel.fromMap(Map<String, dynamic> map, {String? id}) => CustomerModel(
        id: id ?? map['id'] as String?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        village: map['village'] as String?,
        customerType: map['customer_type'] as String? ?? 'Mkulima',
        createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'village': village,
        'customer_type': customerType,
        'created_at': createdAt,
      };
}
