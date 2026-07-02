import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/credit_model.dart';
import '../../../data/repositories/credit_repository.dart';

/// CustomerDetailScreen - "Statement" kamili ya mteja mmoja: historia ya
/// madeni yote yanayodaiwa + salio linaloendelea (running balance), pamoja
/// na uwezo wa kurekodi malipo papo hapo.
class CustomerDetailScreen extends StatefulWidget {
  final CustomerModel customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _repo = CreditRepository();
  final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);
  final _dateFmt = DateFormat('dd/MM/yyyy');
  List<CreditSaleModel> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _repo.getActiveCredits();
    setState(() {
      _history = all.where((c) => c.customerId == widget.customer.id).toList();
      _loading = false;
    });
  }

  double get _totalBalance => _history.fold(0, (sum, c) => sum + c.balance);

  void _showPaymentDialog(CreditSaleModel credit) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${SW.makePayment} - ${widget.customer.name}'),
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
      appBar: AppBar(title: Text(widget.customer.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: AppColors.primaryGreen.withOpacity(0.06),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: AppColors.primaryGreen),
                              const SizedBox(width: 8),
                              Expanded(child: Text(widget.customer.phone ?? '—')),
                            ],
                          ),
                          if (widget.customer.village != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(widget.customer.village!),
                              ],
                            ),
                          ],
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(SW.totalOwed, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                _currencyFmt.format(_totalBalance),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: _totalBalance > 0 ? AppColors.danger : AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(SW.customerStatement, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text(SW.noCreditHistory)),
                    )
                  else
                    ..._history.map((c) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(
                              c.status == 'Imelipwa' ? Icons.check_circle : Icons.pending_actions,
                              color: c.status == 'Imelipwa' ? AppColors.primaryGreen : AppColors.warning,
                            ),
                            title: Text(_currencyFmt.format(c.amountOwed)),
                            subtitle: Text('${_dateFmt.format(DateTime.parse(c.createdAt))} • ${c.status}\nBaki: ${_currencyFmt.format(c.balance)}'),
                            isThreeLine: true,
                            trailing: c.balance > 0
                                ? TextButton(onPressed: () => _showPaymentDialog(c), child: const Text(SW.makePayment))
                                : null,
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
