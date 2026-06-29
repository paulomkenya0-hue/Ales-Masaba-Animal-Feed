import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/strings_sw.dart';
import '../../providers/product_provider.dart';
import '../../../data/models/product_model.dart';

/// AddEditProductScreen - Fomu ya kuongeza au kuhariri bidhaa, na uthibitishaji kamili
class AddEditProductScreen extends StatefulWidget {
  final ProductModel? product;
  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _buyingCtrl;
  late TextEditingController _retailCtrl;
  late TextEditingController _wholesaleCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _lowStockCtrl;
  late TextEditingController _barcodeCtrl;
  String _unit = 'Kg';
  int? _categoryId;

  final _units = const ['Kg', 'Gunia', 'Lita', 'Kipande'];

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _buyingCtrl = TextEditingController(text: p?.buyingPrice.toString() ?? '');
    _retailCtrl = TextEditingController(text: p?.retailPrice.toString() ?? '');
    _wholesaleCtrl = TextEditingController(text: p?.wholesalePrice.toString() ?? '');
    _quantityCtrl = TextEditingController(text: p?.quantity.toString() ?? '');
    _lowStockCtrl = TextEditingController(text: p?.lowStockLimit.toString() ?? '10');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _unit = p?.unit ?? 'Kg';
    _categoryId = p?.categoryId;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ProductProvider>();
    final now = DateTime.now().toIso8601String();

    final product = ProductModel(
      id: widget.product?.id,
      name: _nameCtrl.text.trim(),
      categoryId: _categoryId,
      buyingPrice: double.tryParse(_buyingCtrl.text) ?? 0,
      retailPrice: double.tryParse(_retailCtrl.text) ?? 0,
      wholesalePrice: double.tryParse(_wholesaleCtrl.text) ?? 0,
      quantity: double.tryParse(_quantityCtrl.text) ?? 0,
      unit: _unit,
      lowStockLimit: double.tryParse(_lowStockCtrl.text) ?? 10,
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      createdAt: widget.product?.createdAt ?? now,
      updatedAt: now,
    );

    final ok = _isEditing ? await provider.updateProduct(product) : await provider.addProduct(product);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? SW.savedSuccess : SW.error)),
      );
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ProductProvider>().categories;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? SW.editProduct : SW.addProduct)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: SW.productName),
                validator: (v) => (v == null || v.isEmpty) ? SW.required : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: SW.category),
                items: categories
                    .map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['name'] as String)))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _buyingCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: SW.buyingPrice),
                      validator: (v) => (v == null || v.isEmpty) ? SW.required : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _retailCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: SW.retailPrice),
                      validator: (v) => (v == null || v.isEmpty) ? SW.required : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _wholesaleCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: SW.wholesalePrice),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: SW.quantity),
                      validator: (v) => (v == null || v.isEmpty) ? SW.required : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: SW.unit),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _unit = v ?? 'Kg'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lowStockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: SW.lowStockLimit),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _barcodeCtrl,
                decoration: const InputDecoration(labelText: '${SW.barcode} (Hiari)'),
              ),
              const SizedBox(height: 28),
              ElevatedButton(onPressed: _save, child: const Text(SW.save)),
            ],
          ),
        ),
      ),
    );
  }
}
