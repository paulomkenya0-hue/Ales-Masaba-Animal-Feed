import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../data/repositories/expense_repository.dart';

/// ReportsScreen - Muhtasari wa ripoti za msingi.
/// MAELEZO: Uhamishaji kamili kwa PDF/Excel/CSV utajengwa katika Awamu ya 2 (tazama roadmap).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _salesRepo = SalesRepository();
  final _expenseRepo = ExpenseRepository();
  final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);

  double _daily = 0, _weekly = 0, _monthly = 0, _yearly = 0;
  double _dailyExpense = 0, _monthlyExpense = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfYear = DateTime(now.year, 1, 1);

    _daily = await _salesRepo.getTotalSales(startOfDay, endOfDay);
    _weekly = await _salesRepo.getTotalSales(startOfWeek, endOfDay);
    _monthly = await _salesRepo.getTotalSales(startOfMonth, endOfDay);
    _yearly = await _salesRepo.getTotalSales(startOfYear, endOfDay);
    _dailyExpense = await _expenseRepo.getTotalExpenses(startOfDay, endOfDay);
    _monthlyExpense = await _expenseRepo.getTotalExpenses(startOfMonth, endOfDay);

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(SW.reports)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _reportCard(SW.dailySales, _daily),
                _reportCard(SW.weeklySalesReport, _weekly),
                _reportCard(SW.monthlySalesReport, _monthly),
                _reportCard(SW.yearlySales, _yearly),
                const Divider(height: 32),
                _reportCard(SW.profitReport, _daily - _dailyExpense, subtitle: 'Leo'),
                _reportCard(SW.profitReport, _monthly - _monthlyExpense, subtitle: 'Mwezi Huu'),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.construction, color: AppColors.warning),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${SW.exportPdf} / ${SW.exportExcel} / ${SW.exportCsv} - vinakuja katika sasisho linalofuata.',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _reportCard(String title, double value, {String? subtitle}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: Text(
          _currencyFmt.format(value),
          style: TextStyle(fontWeight: FontWeight.bold, color: value < 0 ? AppColors.danger : AppColors.primaryGreen),
        ),
      ),
    );
  }
}
