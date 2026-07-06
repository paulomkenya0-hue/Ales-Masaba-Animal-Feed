import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../providers/auth_provider.dart';

/// MySalesReportScreen - Ripoti ya mauzo ya Muuzaji (Cashier) mwenyewe TU.
/// Kwa mujibu wa Firestore Security Rules, maswali haya yanarudisha mauzo
/// yale tu aliyoyafanya mtumiaji aliyeingia - hakuna haja ya kuchuja tena
/// upande wa programu.
class MySalesReportScreen extends StatefulWidget {
  const MySalesReportScreen({super.key});

  @override
  State<MySalesReportScreen> createState() => _MySalesReportScreenState();
}

enum _P { today, week, month }

class _MySalesReportScreenState extends State<MySalesReportScreen> {
  final _repo = SalesRepository();
  final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);
  _P _period = _P.today;
  bool _loading = true;
  double _total = 0;
  int _count = 0;
  List<Map<String, dynamic>> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
    switch (_period) {
      case _P.today:
        return (startOfDay, endOfDay);
      case _P.week:
        return (startOfDay.subtract(Duration(days: now.weekday - 1)), endOfDay);
      case _P.month:
        return (DateTime(now.year, now.month, 1), endOfDay);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (start, end) = _range();
    final results = await Future.wait([
      _repo.getTotalSales(start, end),
      _repo.getSalesCount(start, end),
      _repo.getTopSellingProducts(start, end, limit: 5),
    ]);
    if (!mounted) return;
    setState(() {
      _total = results[0] as double;
      _count = results[1] as int;
      _topProducts = results[2] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text(SW.mySalesReport)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _chip('Leo', _P.today)),
                const SizedBox(width: 8),
                Expanded(child: _chip('Wiki Hii', _P.week)),
                const SizedBox(width: 8),
                Expanded(child: _chip('Mwezi Huu', _P.month)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        if (user?.branchName != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(user!.branchName!, style: const TextStyle(color: Colors.grey)),
                          ),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(_currencyFmt.format(_total),
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                              const SizedBox(height: 4),
                              Text('$_count ${SW.numberOfSales}', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(SW.topSellingProducts, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        if (_topProducts.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text(SW.noSalesInPeriod))
                        else
                          ..._topProducts.map((p) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryGreen),
                                  title: Text(p['productName'] as String? ?? '—'),
                                  subtitle: Text('${(p['quantity'] as double).toStringAsFixed(0)} vitengo'),
                                  trailing: Text(_currencyFmt.format(p['revenue']), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              )),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _P p) {
    final selected = _period == p;
    return ChoiceChip(
      label: Text(label, textAlign: TextAlign.center),
      selected: selected,
      selectedColor: AppColors.primaryGreen,
      labelStyle: TextStyle(color: selected ? Colors.white : null),
      onSelected: (_) {
        setState(() => _period = p);
        _load();
      },
    );
  }
}
