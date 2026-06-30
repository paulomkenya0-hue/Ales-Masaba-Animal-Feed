import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../providers/product_provider.dart';
import 'add_edit_product_screen.dart';

/// ProductListScreen - Orodha, tafuta, hariri na futa bidhaa
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchCtrl = TextEditingController();
  final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
      context.read<ProductProvider>().loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text(SW.products)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: SW.searchProduct,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => context.read<ProductProvider>().loadProducts(searchQuery: v),
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.products.isEmpty
                    ? const Center(child: Text(SW.noData))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.products.length,
                        itemBuilder: (context, index) {
                          final p = provider.products[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: p.isLowStock
                                    ? AppColors.warning.withOpacity(0.2)
                                    : AppColors.primaryGreen.withOpacity(0.15),
                                child: Icon(
                                  Icons.inventory_2,
                                  color: p.isLowStock ? AppColors.warning : AppColors.primaryGreen,
                                ),
                              ),
                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${p.categoryName ?? ''} • ${p.quantity.toStringAsFixed(0)} ${p.unit} • ${_currencyFmt.format(p.retailPrice)}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditProductScreen(product: p)));
                                  } else if (value == 'delete') {
                                    _confirmDelete(p.id!);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: Text(SW.edit)),
                                  const PopupMenuItem(value: 'delete', child: Text(SW.delete)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditProductScreen())),
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(SW.deleteProduct),
        content: const Text(SW.confirmDelete),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(SW.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await context.read<ProductProvider>().deleteProduct(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(SW.delete),
          ),
        ],
      ),
    );
  }
}
