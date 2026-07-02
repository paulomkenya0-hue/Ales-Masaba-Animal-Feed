import 'package:flutter/material.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/credit_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/models/product_model.dart';

/// DashboardProvider - Hujumlisha takwimu zote za dashibodi kwa muonekano mmoja
class DashboardProvider extends ChangeNotifier {
  final _salesRepo = SalesRepository();
  final _expenseRepo = ExpenseRepository();
  final _creditRepo = CreditRepository();
  final _productRepo = ProductRepository();
  final _backupRepo = BackupRepository();

  bool isLoading = true;
  double todaySales = 0;
  double todayExpenses = 0;
  double todayProfit = 0;
  double weeklySales = 0;
  double monthlySales = 0;
  double totalOutstandingCredit = 0;
  List<ProductModel> lowStockProducts = [];
  Map<String, dynamic>? highestCreditCustomer;
  bool backupOverdue = false;

  Future<void> loadDashboard() async {
    isLoading = true;
    notifyListeners();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    todaySales = await _salesRepo.getTotalSales(startOfDay, endOfDay);
    todayExpenses = await _expenseRepo.getTotalExpenses(startOfDay, endOfDay);
    todayProfit = todaySales - todayExpenses;
    weeklySales = await _salesRepo.getTotalSales(startOfWeek, endOfDay);
    monthlySales = await _salesRepo.getTotalSales(startOfMonth, endOfDay);
    totalOutstandingCredit = await _creditRepo.getTotalOutstandingCredit();
    lowStockProducts = await _productRepo.getLowStockProducts();
    highestCreditCustomer = await _creditRepo.getHighestCreditCustomer();
    backupOverdue = await _backupRepo.isBackupOverdue();

    isLoading = false;
    notifyListeners();
  }
}
