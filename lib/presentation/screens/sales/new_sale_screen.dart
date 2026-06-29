import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../providers/product_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/models/customer_model.dart';
import 'receipt_screen.dart';

/// NewSaleScreen - Huunda mauzo mapya: chagua bidhaa, jumla otomatiki, Cash au Mkopo
class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);
  String _priceLevel = 'retail'; // retail | wholesale

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  void _addProductToCart(ProductModel product) {
    final qtyCtrl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(product.name),
        content: TextField(
          controller: qtyCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: '${SW.quantity} (${product.unit})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(SW.cancel)),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(qtyCtrl.text) ?? 0;
              if (qty <= 0) return;
              if (qty > product.quantity) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(SW.outOfStock)));
                return;
              }
              final price = _priceLevel == 'retail' ? product.retailPrice : product.wholesalePrice;
              context.read<SalesProvider>().addToCart(SaleItemModel(
                    productId: product.id!,
                    productName: product.name,
                    quantity: qty,
                    unitPrice: price,
                    subtotal: price * qty,
                  ));
              Navigator.pop(context);
            },
            child: const Text(SW.add),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout() async {
    final sales = context.read<SalesProvider>();
    if (sales.cartItems.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CheckoutSheet(currencyFmt: _currencyFmt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final sales = context.watch<SalesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text(SW.newSale)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'retail', label: Text(SW.retailPrice)),
                ButtonSegment(value: 'wholesale', label: Text(SW.wholesalePrice)),
              ],
              selected: {_priceLevel},
              onSelectionChanged: (s) => setState(() => _priceLevel = s.first),
            ),
          ),
          Expanded(
            child: products.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: products.products.length,
                    itemBuilder: (context, i) {
                      final p = products.products[i];
                      final price = _priceLevel == 'retail' ? p.retailPrice : p.wholesalePrice;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(p.name),
                          subtitle: Text('${_currencyFmt.format(price)} / ${p.unit} • Hifadhi: ${p.quantity.toStringAsFixed(0)}'),
                          trailing: ElevatedButton(
                            onPressed: p.isOutOfStock ? null : () => _addProductToCart(p),
                            child: const Text(SW.add),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (sales.cartItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${sales.cartItems.length} bidhaa zilizochaguliwa', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    '${SW.grandTotal}: ${_currencyFmt.format(sales.cartTotal)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _checkout, child: const Text(SW.next)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  final NumberFormat currencyFmt;
  const _CheckoutSheet({required this.currencyFmt});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  String _paymentMethod = SW.cash;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  String _customerType = SW.farmer;

  Future<void> _confirm() async {
    final sales = context.read<SalesProvider>();
    final auth = context.read<AuthProvider>();

    CustomerModel? newCustomer;
    if (_paymentMethod == SW.credit) {
      if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(SW.required)));
        return;
      }
      newCustomer = CustomerModel(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        village: _villageCtrl.text.trim().isEmpty ? null : _villageCtrl.text.trim(),
        customerType: _customerType,
        createdAt: DateTime.now().toIso8601String(),
      );
    }

    final ok = await sales.checkout(
      paymentMethod: _paymentMethod,
      newCustomer: newCustomer,
      userId: auth.currentUser?.id,
    );

    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        final sale = sales.lastSale;
        Navigator.pop(context); // funga skrini ya mauzo mapya
        if (sale != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(sale: sale)));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sales.errorMessage ?? SW.error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(SW.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: SW.cash, label: Text(SW.cash)),
                ButtonSegment(value: SW.credit, label: Text(SW.credit)),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (s) => setState(() => _paymentMethod = s.first),
            ),
            const SizedBox(height: 16),
            if (_paymentMethod == SW.credit) ...[
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: SW.customerName)),
              const SizedBox(height: 12),
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: SW.phoneNumber), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              TextField(controller: _villageCtrl, decoration: const InputDecoration(labelText: '${SW.village} (Hiari)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _customerType,
                decoration: const InputDecoration(labelText: SW.customerType),
                items: const [SW.farmer, SW.retailCustomer, SW.company]
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _customerType = v ?? SW.farmer),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              '${SW.grandTotal}: ${widget.currencyFmt.format(sales.cartTotal)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: sales.isProcessing ? null : _confirm,
              child: sales.isProcessing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text(SW.confirm),
            ),
          ],
        ),
      ),
    );
  }
}
