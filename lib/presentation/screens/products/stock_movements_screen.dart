import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../core/utils/id_util.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/stock_movement_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/access_denied_view.dart';

/// StockMovementsScreen - Historia ya mabadiliko ya hifadhi (mauzo, ongezeko,
/// marekebisho, iliyoharibika) na kitufe cha kurekebisha hifadhi. Msimamizi pekee.
class StockMovementsScreen extends StatefulWidget {
  const StockMovementsScreen({super.key});

  @override
  State<StockMovementsScreen> createState() => _StockMovementsScreenState();
}

class _StockMovementsScreenState extends State<StockMovementsScreen> {
  final _repo = ProductRepository();
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  List<StockMovementModel> _moves = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _moves = await _repo.getStockMovements();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<void> _openAdjust() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AdjustStockSheet(),
    );
    if (done == true && mounted) {
      await context.read<ProductProvider>().loadProducts();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isSuperAdmin) {
      return const Scaffold(body: AccessDeniedView());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Historia ya Hifadhi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdjust,
        icon: const Icon(Icons.tune),
        label: const Text('Rekebisha Hifadhi'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : _moves.isEmpty
                  ? const Center(child: Text(SW.noData))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                        itemCount: _moves.length,
                        itemBuilder: (context, i) {
                          final m = _moves[i];
                          final up = m.change > 0;
                          final when = DateTime.tryParse(m.createdAt);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (up ? AppColors.primaryGreen : AppColors.danger).withOpacity(0.12),
                                child: Icon(up ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: up ? AppColors.primaryGreen : AppColors.danger, size: 18),
                              ),
                              title: Text(m.productName ?? m.productId, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text([
                                m.type + (m.receiptNumber != null ? ' • ${m.receiptNumber}' : ''),
                                '${_n(m.before)} → ${_n(m.after)}',
                                if (m.reason != null && m.reason!.isNotEmpty) m.reason!,
                                '${when != null ? _dateFmt.format(when) : m.createdAt}${m.userName != null ? ' • ${m.userName}' : ''}',
                              ].join('\n')),
                              isThreeLine: true,
                              trailing: Text('${up ? '+' : ''}${_n(m.change)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: up ? AppColors.primaryGreen : AppColors.danger)),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _AdjustStockSheet extends StatefulWidget {
  const _AdjustStockSheet();

  @override
  State<_AdjustStockSheet> createState() => _AdjustStockSheetState();
}

class _AdjustStockSheetState extends State<_AdjustStockSheet> {
  final _repo = ProductRepository();
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final String _requestId = IdUtil.newRequestId();
  ProductModel? _product;
  String _type = StockMoveType.purchase;
  bool _increase = true; // kwa 'Marekebisho' pekee
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '').trim()) ?? 0;
    if (_product == null) {
      setState(() => _error = 'Chagua bidhaa');
      return;
    }
    if (qty <= 0) {
      setState(() => _error = 'Weka kiasi kikubwa kuliko sifuri');
      return;
    }
    if (_type != StockMoveType.purchase && _reasonCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Andika sababu ya marekebisho');
      return;
    }
    final delta = switch (_type) {
      StockMoveType.purchase => qty,
      StockMoveType.damage => -qty,
      _ => _increase ? qty : -qty,
    };
    final user = context.read<AuthProvider>().currentUser;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.adjustStock(
        productId: _product!.id!,
        change: delta,
        type: _type,
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
        userId: user?.uid,
        userName: user?.fullName ?? user?.username,
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
    final products = context.watch<ProductProvider>().products;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Rekebisha Hifadhi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProductModel>(
              value: _product,
              isExpanded: true,
              decoration: const InputDecoration(labelText: SW.selectProduct),
              items: products
                  .map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.quantity.toStringAsFixed(0)} ${p.unit})')))
                  .toList(),
              onChanged: _busy ? null : (p) => setState(() => _product = p),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Aina'),
              items: StockMoveType.manual.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: _busy ? null : (t) => setState(() => _type = t ?? _type),
            ),
            if (_type == StockMoveType.adjustment) ...[
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Ongeza'), icon: Icon(Icons.add)),
                  ButtonSegment(value: false, label: Text('Punguza'), icon: Icon(Icons.remove)),
                ],
                selected: {_increase},
                onSelectionChanged: (s) => setState(() => _increase = s.first),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '${SW.quantity}${_product != null ? ' (${_product!.unit})' : ''}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              decoration: InputDecoration(
                  labelText: _type == StockMoveType.purchase ? 'Maelezo (hiari, mf. muuzaji)' : 'Sababu'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text(SW.save),
            ),
          ],
        ),
      ),
    );
  }
}
