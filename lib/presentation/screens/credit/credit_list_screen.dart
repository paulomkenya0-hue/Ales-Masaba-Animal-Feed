import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../data/repositories/credit_repository.dart';
import '../../../data/models/credit_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/record_payment_dialog.dart';

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
    try {
      final auth = context.read<AuthProvider>();
      // Cashier anaona madeni aliyoyaanzisha yeye tu (Firestore Rules)
      _credits = await _repo.getActiveCredits(createdBy: auth.isSuperAdmin ? null : auth.currentUser?.uid);
    } catch (e) {
      _credits = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${SW.error}: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showPaymentDialog(CreditSaleModel credit) async {
    final ok = await RecordPaymentDialog.show(context, credit);
    if (ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Malipo yamerekodiwa')));
      }
      _load();
    }
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
