import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/strings_sw.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/id_util.dart';
import '../../data/models/credit_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/repositories/credit_repository.dart';
import '../providers/auth_provider.dart';

/// RecordPaymentDialog - Kurekodi malipo ya deni (sehemu au kamili).
/// - Njia ya malipo: Fedha Taslimu au Pesa ya Simu (namba ya muamala inahitajika)
/// - Haikubali kiasi kinachozidi deni lililobaki
/// - Kitufe kinazimwa wakati wa kuhifadhi na ombi lina kitambulisho cha kipekee,
///   hivyo kubonyeza mara mbili hakuleti malipo mawili.
class RecordPaymentDialog extends StatefulWidget {
  final CreditSaleModel credit;
  const RecordPaymentDialog({super.key, required this.credit});

  /// Inarudisha true ikiwa malipo yamerekodiwa.
  static Future<bool> show(BuildContext context, CreditSaleModel credit) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordPaymentDialog(credit: credit),
    );
    return ok ?? false;
  }

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  final _fmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _repo = CreditRepository();
  final String _requestId = IdUtil.newRequestId();
  String _method = PayMethod.cash;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
    final balance = widget.credit.balance;
    if (amount <= 0) {
      setState(() => _error = 'Weka kiasi cha malipo');
      return;
    }
    if (amount > balance + 0.0001) {
      setState(() => _error = 'Kiasi kinazidi deni lililobaki (${_fmt.format(balance)})');
      return;
    }
    if (_method == PayMethod.mobileMoney && _refCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Weka namba ya muamala');
      return;
    }

    final user = context.read<AuthProvider>().currentUser;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.recordPayment(
        widget.credit.id!,
        amount,
        method: _method,
        reference: _refCtrl.text,
        cashierId: user?.uid,
        cashierName: user?.fullName ?? user?.username,
        requestId: _requestId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.credit.balance;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.credit.customerName ?? SW.customer),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${SW.amountOwed}: ${_fmt.format(balance)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: PayMethod.cash, label: Text('Taslimu'), icon: Icon(Icons.payments_outlined)),
                ButtonSegment(value: PayMethod.mobileMoney, label: Text('Simu'), icon: Icon(Icons.phone_android)),
              ],
              selected: {_method},
              onSelectionChanged: _busy ? null : (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              enabled: !_busy,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: SW.makePayment,
                suffixIcon: TextButton(
                  onPressed: _busy ? null : () => _amountCtrl.text = balance.toStringAsFixed(0),
                  child: const Text('Lipa Lote'),
                ),
              ),
            ),
            if (_method == PayMethod.mobileMoney) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _refCtrl,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Namba ya Muamala'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text(SW.cancel)),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text(SW.confirm),
        ),
      ],
    );
  }
}
