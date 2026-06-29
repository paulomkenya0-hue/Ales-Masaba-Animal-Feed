class ExpenseModel {
  final int? id;
  final String category; // Usafiri, Umeme, Kodi ya Nyumba, Mishahara, Matengenezo, Mengine
  final double amount;
  final String? description;
  final String expenseDate;
  final int? userId;

  ExpenseModel({
    this.id,
    required this.category,
    required this.amount,
    this.description,
    required this.expenseDate,
    this.userId,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map) => ExpenseModel(
        id: map['id'] as int?,
        category: map['category'] as String,
        amount: (map['amount'] as num).toDouble(),
        description: map['description'] as String?,
        expenseDate: map['expense_date'] as String,
        userId: map['user_id'] as int?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'category': category,
        'amount': amount,
        'description': description,
        'expense_date': expenseDate,
        'user_id': userId,
      };
}
