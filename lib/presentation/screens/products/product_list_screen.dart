import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/product_model.dart';
import 'add_edit_product_screen.dart';
import 'category_management_screen.dart';
import '../../widgets/barcode_scanner_screen.dart';
import '../../widgets/access_denied_view.dart';

/// ProductListScreen - Bidhaa zimepangwa kwa Category -> Variants
/// (mf. Pumba -> Pumba Mchele, Pumba Karanga), Super Admin PEKEE
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchCtrl = TextEditingController();
  final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);
  bool get _isSearching => _searchCtrl.text.trim().isNotEmpty;

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
    final isSuperAdmin = context.watch<AuthProvider>().isSuperAdmin;

    if (!isSuperAdmin) {
      return const Scaffold(body: AccessDeniedView());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(SW.products),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: SW.manageCategories,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: SW.searchProduct,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final result = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                    );
                    if (result != null) {
                      _searchCtrl.text = result;
                      context.read<ProductProvider>().loadProducts(searchQuery: result);
                      setState(() {});
                    }
                  },
                ),
              ),
              onChanged: (v) {
                context.read<ProductProvider>().loadProducts(searchQuery: v);
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.products.isEmpty
                    ? const Center(child: Text(SW.noData))
                    : (_isSearching ? _buildFlatList(provider.products) : _buildGroupedByCategory(provider)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryGreen,
        tooltip: SW.addProduct,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditProductScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Mwonekano wa utafutaji - orodha bapa ya matokeo
  Widget _buildFlatList(List<ProductModel> products) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: products.length,
      itemBuilder: (context, index) => _productTile(products[index]),
    );
  }

  /// Mwonekano chaguomsingi: Category -> Variants (mf. Pumba -> Pumba
  /// Mchele, Pumba Karanga), kila category ikiwa na jopo linaloweza
  /// kufunguliwa/kufungwa.
  Widget _buildGroupedByCategory(ProductProvider provider) {
    final grouped = provider.productsByCategory;
    final categories = [...provider.categories];
    // Hakikisha category zote zenye bidhaa lakini hazipo tena kwenye orodha
    // ya categories (nadra) bado zinaonekana
    final categoryIds = categories.map((c) => c.id).toSet();
    final orphanIds = grouped.keys.where((id) => id != null && !categoryIds.contains(id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      children: [
        for (final c in categories)
          if ((grouped[c.id] ?? []).isNotEmpty) _categorySection(c.name, grouped[c.id] ?? []),
        for (final id in orphanIds) _categorySection('Category Nyingine', grouped[id] ?? []),
        if ((grouped[null] ?? []).isNotEmpty) _categorySection(SW.other, grouped[null] ?? []),
      ],
    );
  }

  Widget _categorySection(String categoryName, List<ProductModel> products) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.category_outlined, color: AppColors.primaryGreen),
        title: Text(categoryName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${products.length} ${SW.variantsCount}'),
        children: products.map((p) => _productTile(p, dense: true)).toList(),
      ),
    );
  }

  Widget _productTile(ProductModel p, {bool dense = false}) {
    return Card(
      margin: dense
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const EdgeInsets.only(bottom: 10),
      elevation: dense ? 0 : 1,
      color: dense ? Colors.grey.shade50 : null,
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
          '${p.quantity.toStringAsFixed(0)} ${p.unit} • ${_currencyFmt.format(p.retailPrice)}',
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
  }

  void _confirmDelete(String id) {
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
