import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../data/repositories/credit_repository.dart';
import '../../../data/models/credit_model.dart';

/// CreditListScreen - Orodha ya wateja wenye mkopo, malipo ya sehemu/kamili, historia
class CreditListScreen extends StatefulWidget {
  const CreditListScreen({super.key});

  @override
  State<CreditListScreen> createState() => _CreditListScreenState();
}

class _CreditListScreenState extends State<CreditListScreen> {
  final _repo = CreditRepository();
  final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);
  List<CreditSaleModel> _credits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _credits = await _repo.getActiveCredits();
    setState(() => _loading = false);
  }

  void _showPaymentDialog(CreditSaleModel credit) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(credit.customerName ?? SW.customer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${SW.amountOwed}: ${_currencyFmt.format(credit.balance)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: SW.makePayment),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(SW.cancel)),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0 || credit.id == null) return;
              await _repo.recordPayment(credit.id!, amount);
              if (context.mounted) {
                Navigator.pop(context);
                _load();
              }
            },
            child: const Text(SW.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(SW.creditList)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _credits.isEmpty
              ? const Center(child: Text(SW.noData))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _credits.length,
                    itemBuilder: (context, i) {
                      final c = _credits[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0x1AD32F2F),
                            child: Icon(Icons.person, color: AppColors.danger),
                          ),
                          title: Text(c.customerName ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${c.customerPhone ?? ''} • ${SW.status}: ${c.status}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_currencyFmt.format(c.balance), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                              TextButton(onPressed: () => _showPaymentDialog(c), child: const Text(SW.makePayment)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
