class CategoryModel {
  final String? id;
  final String name;
  final String createdAt;

  CategoryModel({this.id, required this.name, required this.createdAt});

  factory CategoryModel.fromMap(Map<String, dynamic> map, {String? id}) => CategoryModel(
        id: id ?? map['id'] as String?,
        name: map['name'] as String,
        createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'created_at': createdAt,
      };
}
