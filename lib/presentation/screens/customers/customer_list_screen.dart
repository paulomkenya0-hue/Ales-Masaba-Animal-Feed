import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../data/models/customer_model.dart';
import '../../providers/customer_provider.dart';
import 'customer_detail_screen.dart';

/// CustomerListScreen - Orodha ya wateja WOTE (profile moja kwa kila
/// mteja - hakuna kurudia), inayopatikana kwa Super Admin na Cashier wote
/// wawili (Cashier anahitaji kuona wateja ili kuuza kwa mkopo).
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _searchCtrl = TextEditingController();
  final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);
  List<CustomerModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<CustomerProvider>();
      await provider.loadCustomers();
      setState(() => _filtered = provider.customers);
    });
  }

  void _onSearchChanged(String query, List<CustomerModel> all) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? all
          : all.where((c) => c.name.toLowerCase().contains(q) || (c.phone ?? '').contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text(SW.customers)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: SW.searchCustomer,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => _onSearchChanged(v, provider.customers),
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text(SW.noData))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final c = _filtered[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                child: Icon(Icons.person_outline),
                              ),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${c.phone ?? ''} • ${c.customerType}'),
                              trailing: FutureBuilder<double>(
                                future: provider.getBalance(c.id!),
                                builder: (context, snap) {
                                  final balance = snap.data ?? 0;
                                  if (!snap.hasData) {
                                    return const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    );
                                  }
                                  return Text(
                                    balance > 0 ? _currencyFmt.format(balance) : 'Hana Deni',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: balance > 0 ? AppColors.danger : AppColors.primaryGreen,
                                    ),
                                  );
                                },
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: c)),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
