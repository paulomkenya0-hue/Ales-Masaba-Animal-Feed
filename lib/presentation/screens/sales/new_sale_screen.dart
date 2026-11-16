import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../providers/product_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/models/customer_model.dart';
import 'receipt_screen.dart';

final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// NewSaleScreen - POS: tafuta bidhaa, ongeza bidhaa nyingi kwenye kikapu kimoja,
/// hariri/ondoa kabla ya kulipa, kisha lipa (Taslimu / Pesa ya Simu / sehemu / Mkopo).
class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  String _priceLevel = 'retail'; // retail | wholesale
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double _basePrice(ProductModel p) => _priceLevel == 'retail' ? p.retailPrice : p.wholesalePrice;

  /// Bei ya chini kabisa anayoruhusiwa Cashier kuuzia (Msimamizi hana kikomo).
  /// Cashier haoni bei ya kununua, kwa hiyo kikomo ni bei ya jumla ya bidhaa.
  double _minPriceFor(ProductModel p, bool isSuperAdmin) {
    if (isSuperAdmin) return 0;
    if (p.wholesalePrice > 0) return p.wholesalePrice < p.retailPrice ? p.wholesalePrice : p.retailPrice;
    return p.retailPrice;
  }

  Future<void> _addProductToCart(ProductModel product, {int? editIndex}) async {
    final auth = context.read<AuthProvider>();
    final cart = context.read<SalesProvider>();
    final isAdmin = auth.isSuperAdmin;
    final existing = editIndex != null ? cart.cartItems[editIndex] : null;

    final qtyCtrl = TextEditingController(text: existing != null ? _num(existing.quantity) : '1');
    final priceCtrl = TextEditingController(text: _num(existing?.unitPrice ?? _basePrice(product)));
    final minPrice = _minPriceFor(product, isAdmin);
    // Kiasi kilichopo kwenye kikapu kwa mistari MINGINE ya bidhaa hii
    final otherInCart = cart.cartItems.asMap().entries
        .where((e) => e.value.productId == product.id && e.key != editIndex)
        .fold<double>(0, (s, e) => s + e.value.quantity);
    final available = product.quantity - otherInCart;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '')) ?? 0;
          final price = double.tryParse(priceCtrl.text.replaceAll(',', '')) ?? 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(product.name),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAdmin
                        ? 'Hifadhi: ${_num(product.quantity)} ${product.unit}'
                        : (product.isLowStock ? 'Hifadhi inapungua' : 'Ipo kwenye hifadhi'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: qtyCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: '${SW.quantity} (${product.unit})'),
                    onChanged: (_) => setDialogState(() => error = null),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '${SW.negotiatedPrice} (kwa ${product.unit})',
                      helperText: isAdmin ? SW.negotiatedPriceHint : 'Bei ya chini: ${_currencyFmt.format(minPrice)}',
                      prefixIcon: const Icon(Icons.handshake_outlined),
                    ),
                    onChanged: (_) => setDialogState(() => error = null),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(SW.subtotal, style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_currencyFmt.format(qty * price),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text(SW.cancel)),
              ElevatedButton(
                onPressed: () {
                  if (qty <= 0 || price <= 0) {
                    setDialogState(() => error = 'Weka kiasi na bei zilizo sahihi');
                    return;
                  }
                  if (price < minPrice) {
                    setDialogState(() => error =
                        'Bei ni ndogo kuliko kikomo (${_currencyFmt.format(minPrice)}). Omba idhini ya Msimamizi.');
                    return;
                  }
                  // Cashier hawezi kuuza zaidi ya hifadhi. Msimamizi anaruhusiwa (idhini
                  // ya wazi) - hifadhi haishuki chini ya sifuri, upungufu unarekodiwa.
                  if (qty > available && !isAdmin) {
                    setDialogState(() => error = '${SW.outOfStock}: iliyobaki ni ${_num(available < 0 ? 0 : available)} ${product.unit}');
                    return;
                  }
                  if (existing != null) {
                    cart.updateItem(editIndex!, quantity: qty, unitPrice: price);
                  } else {
                    cart.addToCart(SaleItemModel(
                      productId: product.id!,
                      productName: product.name,
                      unit: product.unit,
                      quantity: qty,
                      unitPrice: price,
                      subtotal: price * qty,
                    ));
                  }
                  Navigator.pop(dialogContext);
                },
                child: Text(existing != null ? SW.save : SW.add),
              ),
            ],
          );
        },
      ),
    );
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }

  /// Je, kuna mstari wowote kwenye kikapu unaozidi hifadhi? (Msimamizi pekee anaweza kuendelea)
  bool _cartExceedsStock(SalesProvider cart, ProductProvider products) {
    final byProduct = <String, double>{};
    for (final i in cart.cartItems) {
      byProduct[i.productId] = (byProduct[i.productId] ?? 0) + i.quantity;
    }
    for (final e in byProduct.entries) {
      final p = products.products.where((p) => p.id == e.key).firstOrNull;
      if (p == null || e.value > p.quantity) return true;
    }
    return false;
  }

  void _openCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CartSheet(
        onEdit: (index) {
          final item = context.read<SalesProvider>().cartItems[index];
          final p = context.read<ProductProvider>().products.where((p) => p.id == item.productId).firstOrNull;
          if (p != null) _addProductToCart(p, editIndex: index);
        },
        onCheckout: _checkout,
      ),
    );
  }

  void _checkout() {
    final cart = context.read<SalesProvider>();
    if (cart.cartItems.isEmpty) return;
    final overstock = _cartExceedsStock(cart, context.read<ProductProvider>());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CheckoutSheet(allowOverstock: overstock && context.read<AuthProvider>().isSuperAdmin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final cart = context.watch<SalesProvider>();
    final isAdmin = context.watch<AuthProvider>().isSuperAdmin;

    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? products.products
        : products.products
            .where((p) => p.name.toLowerCase().contains(q) || (p.barcode ?? '').toLowerCase().contains(q))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(SW.newSale),
        actions: [
          if (cart.cartCount > 0)
            IconButton(
              tooltip: 'Futa kikapu',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Futa kikapu chote?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(SW.no)),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text(SW.yes)),
                    ],
                  ),
                );
                if (ok == true && context.mounted) context.read<SalesProvider>().clearCart();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: SW.searchProduct,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                        }),
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
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
                : visible.isEmpty
                    ? const Center(child: Text(SW.noData))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final p = visible[i];
                          final price = _basePrice(p);
                          final inCart = cart.quantityInCart(p.id ?? '');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(p.name),
                              subtitle: Text(isAdmin
                                  ? '${_currencyFmt.format(price)} / ${p.unit} • Hifadhi: ${_num(p.quantity)}'
                                  : '${_currencyFmt.format(price)} / ${p.unit} • ${p.isOutOfStock ? "Haipo Stoo" : p.isLowStock ? "Inapungua" : "Ipo"}'),
                              trailing: inCart > 0
                                  ? Chip(label: Text('${_num(inCart)} ${p.unit}'), avatar: const Icon(Icons.check, size: 16))
                                  : const Icon(Icons.add_circle_outline, color: AppColors.primaryGreen),
                              enabled: !p.isOutOfStock || isAdmin,
                              onTap: (p.isOutOfStock && !isAdmin) ? null : () => _addProductToCart(p),
                            ),
                          );
                        },
                      ),
          ),
          if (cart.cartCount > 0)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${cart.cartCount} bidhaa kwenye kikapu', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            _currencyFmt.format(cart.cartTotal),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openCart,
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text('Kikapu'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _checkout, child: const Text('Lipa')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kikapu: orodha ya bidhaa zilizochaguliwa, hariri/ondoa kabla ya kulipa
class _CartSheet extends StatelessWidget {
  final void Function(int index) onEdit;
  final VoidCallback onCheckout;
  const _CartSheet({required this.onEdit, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<SalesProvider>();
    final items = cart.cartItems;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(child: Text('Kikapu cha Mauzo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                Text('${items.length} bidhaa', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Kikapu kiko tupu'))
                : ListView.separated(
                    controller: scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final it = items[i];
                      return ListTile(
                        title: Text(it.productName ?? ''),
                        subtitle: Text('${_num(it.quantity)} ${it.unit ?? ''} × ${_currencyFmt.format(it.unitPrice)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_currencyFmt.format(it.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              tooltip: SW.edit,
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () {
                                Navigator.pop(context);
                                onEdit(i);
                              },
                            ),
                            IconButton(
                              tooltip: SW.delete,
                              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                              onPressed: () => context.read<SalesProvider>().removeFromCart(i),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(SW.grandTotal, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_currencyFmt.format(cart.cartTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryGreen)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: items.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context);
                              onCheckout();
                            },
                      child: const Text('Endelea kulipa'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Malipo: Taslimu / Pesa ya Simu / sehemu / Mkopo, mteja, chenji au salio la deni
class _CheckoutSheet extends StatefulWidget {
  /// Msimamizi ameruhusiwa kuuza zaidi ya hifadhi (kikapu kinazidi hifadhi)
  final bool allowOverstock;
  const _CheckoutSheet({required this.allowOverstock});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  String _method = PayMethod.cash; // Fedha Taslimu | Pesa ya Simu | Mkopo
  final _paidCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  String _customerType = SW.farmer;

  CustomerModel? _selectedCustomer;
  bool _showNewCustomerForm = false;
  bool _paidEdited = false;
  String? _error;

  double get _total => context.read<SalesProvider>().cartTotal;

  double get _tendered => double.tryParse(_paidCtrl.text.replaceAll(',', '').trim()) ?? 0;
  double get _paid => _method == PayMethod.credit ? 0 : (_tendered > _total ? _total : _tendered);
  double get _change => (_method == PayMethod.cash && _tendered > _total) ? _tendered - _total : 0;
  double get _balance => _total - _paid;

  @override
  void initState() {
    super.initState();
    _paidCtrl.text = _total.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _refCtrl.dispose();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _villageCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _selectedCustomer = null);
    await context.read<CustomerProvider>().search(query);
  }

  void _selectCustomer(CustomerModel c) {
    setState(() {
      _selectedCustomer = c;
      _showNewCustomerForm = false;
      _searchCtrl.text = c.name;
    });
    context.read<CustomerProvider>().clearSearch();
  }

  void _setMethod(String m) {
    setState(() {
      _method = m;
      _error = null;
      if (m == PayMethod.credit) {
        _paidCtrl.text = '0';
      } else if (!_paidEdited || _tendered == 0) {
        _paidCtrl.text = _total.toStringAsFixed(0);
      }
    });
  }

  Future<void> _confirm() async {
    final sales = context.read<SalesProvider>();
    if (sales.isProcessing) return;
    final auth = context.read<AuthProvider>();

    // ---- Uthibitisho wa fomu ----
    if (_method == PayMethod.mobileMoney) {
      if (_tendered > _total) {
        setState(() => _error = 'Malipo ya Pesa ya Simu hayawezi kuzidi jumla');
        return;
      }
      if (_refCtrl.text.trim().isEmpty && _paid > 0) {
        setState(() => _error = 'Weka namba ya muamala wa Pesa ya Simu');
        return;
      }
    }
    if (_method != PayMethod.credit && _paid <= 0) {
      setState(() => _error = 'Weka kiasi kilicholipwa, au chagua Mkopo');
      return;
    }

    CustomerModel? newCustomer;
    String? existingCustomerId;
    if (_balance > 0.0001) {
      // Deni linahitaji mteja
      if (_selectedCustomer != null) {
        existingCustomerId = _selectedCustomer!.id;
      } else {
        if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
          setState(() => _error = 'Kuna salio la deni - tafuta mteja aliyepo au jaza jina na simu ya mteja mpya');
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
    } else if (_selectedCustomer != null) {
      // Mauzo yaliyolipwa kamili - mteja ni hiari, lakini tukimchagua tunamhifadhi kwenye risiti
      existingCustomerId = _selectedCustomer!.id;
    }

    setState(() => _error = null);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await sales.checkout(
      amountPaid: _method == PayMethod.credit ? 0 : _tendered,
      paymentMethod: _method == PayMethod.credit ? PayMethod.cash : _method,
      paymentReference: _refCtrl.text,
      existingCustomerId: existingCustomerId,
      existingCustomerName: _selectedCustomer?.name,
      existingCustomerPhone: _selectedCustomer?.phone,
      newCustomer: newCustomer,
      userId: auth.currentUser?.uid,
      cashierName: auth.currentUser?.fullName ?? auth.currentUser?.username,
      branchName: auth.currentUser?.branchName,
      allowOverstock: widget.allowOverstock,
    );

    if (!mounted) return;
    if (ok) {
      final sale = sales.lastSale;
      nav.pop(); // funga sheet ya malipo
      if (sale != null) {
        nav.pushReplacement(MaterialPageRoute(builder: (_) => ReceiptScreen(sale: sale)));
      } else {
        nav.pop(); // funga skrini ya mauzo
        messenger.showSnackBar(const SnackBar(content: Text('Mauzo yamerekodiwa')));
      }
    } else {
      setState(() => _error = sales.errorMessage ?? SW.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();
    final customerProvider = context.watch<CustomerProvider>();
    final needsCustomer = _balance > 0.0001;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(SW.grandTotal, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_currencyFmt.format(_total),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                ],
              ),
            ),
            if (widget.allowOverstock) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Onyo: kikapu kinazidi hifadhi iliyopo. Kama Msimamizi, unaweza kuendelea - hifadhi itakuwa sifuri na upungufu utarekodiwa.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(SW.paymentMethod, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: PayMethod.cash, label: Text('Taslimu'), icon: Icon(Icons.payments_outlined)),
                ButtonSegment(value: PayMethod.mobileMoney, label: Text('Simu'), icon: Icon(Icons.phone_android)),
                ButtonSegment(value: PayMethod.credit, label: Text('Mkopo'), icon: Icon(Icons.schedule)),
              ],
              selected: {_method},
              onSelectionChanged: (s) => _setMethod(s.first),
            ),
            const SizedBox(height: 16),
            if (_method != PayMethod.credit) ...[
              TextField(
                controller: _paidCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Kiasi Kilicholipwa',
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixIcon: TextButton(
                    onPressed: () => setState(() {
                      _paidCtrl.text = _total.toStringAsFixed(0);
                      _paidEdited = false;
                    }),
                    child: const Text('Jumla'),
                  ),
                ),
                onChanged: (_) => setState(() {
                  _paidEdited = true;
                  _error = null;
                }),
              ),
              if (_method == PayMethod.mobileMoney) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _refCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Namba ya Muamala',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
            // Chenji au salio la deni - linaonekana papo hapo
            if (_change > 0)
              _infoRow('Chenji', _currencyFmt.format(_change), AppColors.primaryGreen)
            else if (_balance > 0.0001)
              _infoRow('Salio la Deni', _currencyFmt.format(_balance), AppColors.danger)
            else
              _infoRow('Imelipwa Kamili', _currencyFmt.format(_paid), AppColors.primaryGreen),
            const SizedBox(height: 12),

            // ---- Mteja ----
            Text(needsCustomer ? 'Mteja (inahitajika kwa deni)' : 'Mteja (hiari)',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: SW.searchCustomer,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _selectedCustomer != null
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedCustomer = null;
                            _searchCtrl.clear();
                          });
                          context.read<CustomerProvider>().clearSearch();
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                if (_selectedCustomer == null) _search(v);
              },
            ),
            if (_selectedCustomer == null && _searchCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              if (customerProvider.isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (customerProvider.searchResults.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text(SW.newCustomerNoneFound),
                    onPressed: () => setState(() {
                      _showNewCustomerForm = true;
                      _nameCtrl.text = _searchCtrl.text.trim();
                    }),
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: customerProvider.searchResults.length,
                    itemBuilder: (context, i) {
                      final c = customerProvider.searchResults[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_outline),
                        title: Text(c.name),
                        subtitle: Text(c.phone ?? ''),
                        onTap: () => _selectCustomer(c),
                      );
                    },
                  ),
                ),
            ],
            if (_selectedCustomer != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${SW.existingCustomer}: ${_selectedCustomer!.name}')),
                  ],
                ),
              ),
            if (_showNewCustomerForm && _selectedCustomer == null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const Text(SW.newCustomerDetails, style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: SW.customerName)),
              const SizedBox(height: 12),
              TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: SW.phoneNumber),
                  keyboardType: TextInputType.phone),
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
            ],
            if (_error != null || sales.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_error ?? sales.errorMessage!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: sales.isProcessing ? null : _confirm,
              child: sales.isProcessing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Thibitisha Mauzo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );
}
