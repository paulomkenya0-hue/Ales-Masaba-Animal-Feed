import 'package:flutter/material.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/credit_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/models/product_model.dart';

/// DashboardProvider - Hujumlisha takwimu za dashibodi kulingana na ROLE.
///
/// Super Admin: takwimu za biashara nzima (mauzo, matumizi, madeni, utendaji
/// wa wauzaji, matawi). Cashier: mauzo na madeni yake mwenyewe tu - Firestore
/// Rules zinakataa swali lolote la jumla, kwa hiyo hatuliulizi kabisa.
/// Kila sehemu inalindwa na try/catch ili hitilafu moja isizuie dashibodi
/// nzima kupakia (hapo awali Cashier alibaki kwenye spinner milele).
class DashboardProvider extends ChangeNotifier {
  final _salesRepo = SalesRepository();
  final _expenseRepo = ExpenseRepository();
  final _creditRepo = CreditRepository();
  final _productRepo = ProductRepository();
  final _backupRepo = BackupRepository();

  bool isLoading = true;
  String? loadError;
  double todaySales = 0;
  double todayExpenses = 0;
  double todayProfit = 0;
  double weeklySales = 0;
  double monthlySales = 0;
  double yearlySales = 0;
  double totalOutstandingCredit = 0;
  int todaySalesCount = 0;
  List<ProductModel> lowStockProducts = [];
  Map<String, dynamic>? highestCreditCustomer;
  List<Map<String, dynamic>> cashierPerformance = [];
  List<Map<String, dynamic>> branchSales = [];
  bool backupOverdue = false;

  Future<T> _safe<T>(Future<T> Function() fn, T fallback) async {
    try {
      return await fn();
    } catch (e) {
      loadError = e.toString().replaceFirst('Exception: ', '');
      return fallback;
    }
  }

  /// [isSuperAdmin] na [userId] (uid ya Firebase) vinatoka kwa AuthProvider.
  Future<void> loadDashboard({required bool isSuperAdmin, String? userId}) async {
    isLoading = true;
    loadError = null;
    notifyListeners();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfYear = DateTime(now.year, 1, 1);

    // Cashier: ichuje kwa uid yake. Super Admin: null = yote.
    final scope = isSuperAdmin ? null : userId;

    todaySales = await _safe(() => _salesRepo.getTotalSales(startOfDay, endOfDay, userId: scope), 0.0);
    todaySalesCount = await _safe(() => _salesRepo.getSalesCount(startOfDay, endOfDay, userId: scope), 0);
    weeklySales = await _safe(() => _salesRepo.getTotalSales(startOfWeek, endOfDay, userId: scope), 0.0);
    monthlySales = await _safe(() => _salesRepo.getTotalSales(startOfMonth, endOfDay, userId: scope), 0.0);
    totalOutstandingCredit =
        await _safe(() => _creditRepo.getTotalOutstandingCredit(createdBy: scope), 0.0);
    lowStockProducts = await _safe(() => _productRepo.getLowStockProducts(), <ProductModel>[]);

    if (isSuperAdmin) {
      yearlySales = await _safe(() => _salesRepo.getTotalSales(startOfYear, endOfDay), 0.0);
      todayExpenses = await _safe(() => _expenseRepo.getTotalExpenses(startOfDay, endOfDay), 0.0);
      todayProfit = todaySales - todayExpenses;
      highestCreditCustomer = await _safe(() => _creditRepo.getHighestCreditCustomer(), null);
      cashierPerformance = await _safe(() => _salesRepo.getCashierPerformance(startOfMonth, endOfDay), <Map<String, dynamic>>[]);
      branchSales = await _safe(() => _salesRepo.getBranchSales(startOfMonth, endOfDay), <Map<String, dynamic>>[]);
      backupOverdue = await _safe(() => _backupRepo.isBackupOverdue(), false);
    } else {
      yearlySales = 0;
      todayExpenses = 0;
      todayProfit = 0;
      highestCreditCustomer = null;
      cashierPerformance = [];
      branchSales = [];
      backupOverdue = false;
    }

    isLoading = false;
    notifyListeners();
  }
}
