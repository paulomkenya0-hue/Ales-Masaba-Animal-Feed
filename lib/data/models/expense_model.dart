class ExpenseModel {
  final String? id;
  final String category; // Usafiri, Umeme, Kodi ya Nyumba, Mishahara, Matengenezo, Mengine
  final double amount;
  final String? description;
  final String expenseDate;
  final String? userId; // Firebase Auth uid

  ExpenseModel({
    this.id,
    required this.category,
    required this.amount,
    this.description,
    required this.expenseDate,
    this.userId,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, {String? id}) => ExpenseModel(
        id: id ?? map['id'] as String?,
        category: map['category'] as String,
        amount: (map['amount'] as num).toDouble(),
        description: map['description'] as String?,
        expenseDate: map['expense_date'] as String,
        userId: map['user_id'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'category': category,
        'amount': amount,
        'description': description,
        'expense_date': expenseDate,
        'user_id': userId,
      };
}
