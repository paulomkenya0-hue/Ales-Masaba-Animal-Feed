import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/models/expense_model.dart';

/// ExpenseScreen - Rekodi matumizi ya biashara (Usafiri, Umeme, Kodi, Mishahara, n.k.)
class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _repo = ExpenseRepository();
  final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);
  List<ExpenseModel> _expenses = [];
  bool _loading = true;

  final _categories = const [SW.transport, SW.electricity, SW.rent, SW.salary, SW.maintenance, SW.other];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    _expenses = await _repo.getExpensesBetween(start, end);
    setState(() => _loading = false);
  }

  void _showAddExpenseDialog() {
    String selectedCategory = _categories.first;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(SW.addExpense),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: SW.category),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setDialogState(() => selectedCategory = v ?? _categories.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: SW.expenseAmount),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: '${SW.description} (Hiari)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text(SW.cancel)),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) return;
                await _repo.addExpense(ExpenseModel(
                  category: selectedCategory,
                  amount: amount,
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  expenseDate: DateTime.now().toIso8601String(),
                ));
                if (context.mounted) {
                  Navigator.pop(context);
                  _load();
                }
              },
              child: const Text(SW.save),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _expenses.fold<double>(0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(title: const Text(SW.expenses)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jumla ya Matumizi (Mwezi Huu)'),
                      Text(_currencyFmt.format(total), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                    ],
                  ),
                ),
                Expanded(
                  child: _expenses.isEmpty
                      ? const Center(child: Text(SW.noData))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _expenses.length,
                          itemBuilder: (context, i) {
                            final e = _expenses[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(e.category),
                                subtitle: Text(e.description ?? DateFormat('dd/MM/yyyy').format(DateTime.parse(e.expenseDate))),
                                trailing: Text(_currencyFmt.format(e.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryGreen,
        onPressed: _showAddExpenseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
