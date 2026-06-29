class CategoryModel {
  final int? id;
  final String name;
  final String createdAt;

  CategoryModel({this.id, required this.name, required this.createdAt});

  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        createdAt: map['created_at'] as String,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': createdAt,
      };
}
