import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/strings_sw.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/expense_repository.dart';

/// DailyClosingDialog - Huuliza "Je, ungependa kufunga hesabu za leo?" na huonyesha muhtasari
class DailyClosingDialog extends StatefulWidget {
  const DailyClosingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(context: context, builder: (_) => const DailyClosingDialog());
  }

  @override
  State<DailyClosingDialog> createState() => _DailyClosingDialogState();
}

class _DailyClosingDialogState extends State<DailyClosingDialog> {
  final _salesRepo = SalesRepository();
  final _expenseRepo = ExpenseRepository();
  final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);

  bool _loading = true;
  bool _confirmed = false;
  double _totalSales = 0;
  double _cashSales = 0;
  double _creditSales = 0;
  double _totalExpenses = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final sales = await _salesRepo.getSalesBetween(start, end);
    _totalSales = sales.fold(0, (sum, s) => sum + s.totalAmount);
    _cashSales = sales.where((s) => s.paymentMethod == SW.cash).fold(0, (sum, s) => sum + s.totalAmount);
    _creditSales = sales.where((s) => s.paymentMethod == SW.credit).fold(0, (sum, s) => sum + s.totalAmount);
    _totalExpenses = await _expenseRepo.getTotalExpenses(start, end);

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final profit = _totalSales - _totalExpenses;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(_confirmed ? SW.dailyClosingSummary : SW.dailyClosingQuestion),
      content: _loading
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row(SW.todaySales, _totalSales),
                _row(SW.cashReceived, _cashSales),
                _row(SW.creditSalesLabel, _creditSales),
                _row(SW.expenses, _totalExpenses),
                const Divider(),
                _row(SW.todayProfit, profit, bold: true, color: profit >= 0 ? AppColors.primaryGreen : AppColors.danger),
              ],
            ),
      actions: _confirmed
          ? [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text(SW.close))]
          : [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text(SW.no)),
              ElevatedButton(
                onPressed: _loading ? null : () => setState(() => _confirmed = true),
                child: const Text(SW.yes),
              ),
            ],
    );
  }

  Widget _row(String label, double value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            _currencyFmt.format(value),
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color),
          ),
        ],
      ),
    );
  }
}
