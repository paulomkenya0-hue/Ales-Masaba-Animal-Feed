import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../core/utils/report_export.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/credit_repository.dart';
import '../../../data/models/sale_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/access_denied_view.dart';

enum _Period { today, week, month, year, custom }

/// ReportsScreen - Ripoti za kina: mauzo/faida kwa kipindi chochote
/// (Leo/Wiki/Mwezi/Mwaka/Tarehe Maalum), Bidhaa Zinazouzwa Zaidi, Matumizi
/// kwa Aina, Thamani ya Hifadhi, na Madeni Yanayodaiwa. Super Admin PEKEE.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _salesRepo = SalesRepository();
  final _expenseRepo = ExpenseRepository();
  final _productRepo = ProductRepository();
  final _creditRepo = CreditRepository();
  final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);
  final _dateFmt = DateFormat('dd/MM/yyyy');

  _Period _period = _Period.today;
  DateTime _customStart = DateTime.now().subtract(const Duration(days: 7));
  DateTime _customEnd = DateTime.now();

  bool _loading = true;
  bool _exporting = false;
  double _totalSales = 0, _totalExpenses = 0, _outstandingCredit = 0;
  int _salesCount = 0;
  List<Map<String, dynamic>> _topProducts = [];
  Map<String, double> _expenseByCategory = {};
  Map<String, double> _stockValue = {'cost': 0, 'retail': 0};
  List<SaleModel> _salesList = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) _rangeFor(_Period p) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
    switch (p) {
      case _Period.today:
        return (startOfDay, endOfDay);
      case _Period.week:
        return (startOfDay.subtract(Duration(days: now.weekday - 1)), endOfDay);
      case _Period.month:
        return (DateTime(now.year, now.month, 1), endOfDay);
      case _Period.year:
        return (DateTime(now.year, 1, 1), endOfDay);
      case _Period.custom:
        return (_customStart, DateTime(_customEnd.year, _customEnd.month, _customEnd.day, 23, 59, 59));
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (start, end) = _rangeFor(_period);

    final results = await Future.wait([
      _salesRepo.getTotalSales(start, end),
      _expenseRepo.getTotalExpenses(start, end),
      _salesRepo.getSalesCount(start, end),
      _salesRepo.getTopSellingProducts(start, end),
      _expenseRepo.getExpensesByCategory(start, end),
      _productRepo.getTotalStockValue(),
      _creditRepo.getTotalOutstandingCredit(),
      _salesRepo.getSalesBetween(start, end),
    ]);

    if (!mounted) return;
    setState(() {
      _totalSales = results[0] as double;
      _totalExpenses = results[1] as double;
      _salesCount = results[2] as int;
      _topProducts = results[3] as List<Map<String, dynamic>>;
      _expenseByCategory = results[4] as Map<String, double>;
      _stockValue = results[5] as Map<String, double>;
      _outstandingCredit = results[6] as double;
      _salesList = results[7] as List<SaleModel>;
      _loading = false;
    });
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _customStart, end: _customEnd),
    );
    if (range != null) {
      setState(() {
        _customStart = range.start;
        _customEnd = range.end;
        _period = _Period.custom;
      });
      _load();
    }
  }

  String get _periodLabel {
    switch (_period) {
      case _Period.today:
        return SW.dailySales;
      case _Period.week:
        return SW.weeklySalesReport;
      case _Period.month:
        return SW.monthlySalesReport;
      case _Period.year:
        return SW.yearlySales;
      case _Period.custom:
        return '${_dateFmt.format(_customStart)} - ${_dateFmt.format(_customEnd)}';
    }
  }

  Future<void> _exportPdf() async {
    final settings = context.read<SettingsProvider>();
    setState(() => _exporting = true);
    try {
      await ReportExporter.exportPdf(
        periodLabel: _periodLabel,
        totalSales: _totalSales,
        totalExpenses: _totalExpenses,
        salesCount: _salesCount,
        topProducts: _topProducts,
        expenseByCategory: _expenseByCategory,
        stockValue: _stockValue,
        outstandingCredit: _outstandingCredit,
        businessName: settings.businessName,
        logoPath: settings.settings['logo_path'] as String?,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      await ReportExporter.exportExcel(
        periodLabel: _periodLabel,
        totalSales: _totalSales,
        totalExpenses: _totalExpenses,
        topProducts: _topProducts,
        expenseByCategory: _expenseByCategory,
        sales: _salesList,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      await ReportExporter.exportCsv(_salesList, _periodLabel);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isSuperAdmin) {
      return const Scaffold(body: AccessDeniedView());
    }
    final profit = _totalSales - _totalExpenses;

    return Scaffold(
      appBar: AppBar(title: const Text(SW.reports)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _periodChip(SW.dailySales, _Period.today),
                _periodChip(SW.weeklySalesReport, _Period.week),
                _periodChip(SW.monthlySalesReport, _Period.month),
                _periodChip(SW.yearlySales, _Period.year),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(_period == _Period.custom ? _periodLabel : SW.customPeriod),
                  backgroundColor: _period == _Period.custom ? AppColors.primaryGreen : null,
                  labelStyle: TextStyle(color: _period == _Period.custom ? Colors.white : null),
                  onPressed: _pickCustomRange,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        Row(
                          children: [
                            Expanded(child: _statTile(SW.totalSales, _currencyFmt.format(_totalSales), AppColors.primaryGreen)),
                            const SizedBox(width: 10),
                            Expanded(child: _statTile(SW.expenses, _currencyFmt.format(_totalExpenses), AppColors.warning)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _statTile(SW.profitReport, _currencyFmt.format(profit), profit >= 0 ? AppColors.primaryGreen : AppColors.danger)),
                            const SizedBox(width: 10),
                            Expanded(child: _statTile(SW.numberOfSales, '$_salesCount', AppColors.darkGreen)),
                          ],
                        ),
                        if (_salesCount > 0) ...[
                          const SizedBox(height: 10),
                          _statTile(SW.averageSale, _currencyFmt.format(_totalSales / _salesCount), AppColors.lightGreen, fullWidth: true),
                        ],

                        const SizedBox(height: 24),
                        Text(SW.topSellingProducts, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        if (_topProducts.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text(SW.noSalesInPeriod))
                        else
                          ..._topProducts.asMap().entries.map((entry) {
                            final rank = entry.key + 1;
                            final p = entry.value;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: rank <= 3 ? AppColors.warning : Colors.grey.shade300,
                                  foregroundColor: Colors.white,
                                  child: Text('$rank'),
                                ),
                                title: Text(p['productName'] as String? ?? '—'),
                                subtitle: Text('${(p['quantity'] as double).toStringAsFixed(0)} vitengo'),
                                trailing: Text(
                                  _currencyFmt.format(p['revenue']),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                                ),
                              ),
                            );
                          }),

                        const SizedBox(height: 24),
                        Text(SW.expensesByCategory, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        if (_expenseByCategory.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text(SW.noData))
                        else
                          ..._expenseByCategory.entries.map((e) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.receipt_long_outlined, color: AppColors.warning),
                                  title: Text(e.key),
                                  trailing: Text(_currencyFmt.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              )),

                        const SizedBox(height: 24),
                        Text(SW.stockValue, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        _reportCard(SW.stockValueCost, _stockValue['cost'] ?? 0),
                        _reportCard(SW.stockValueRetail, _stockValue['retail'] ?? 0),

                        const SizedBox(height: 24),
                        Text(SW.outstandingCreditReport, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        _reportCard(SW.outstandingCreditReport, _outstandingCredit, isDanger: _outstandingCredit > 0),

                        const SizedBox(height: 24),
                        Text('Hamisha Ripoti', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                label: const Text('PDF'),
                                onPressed: _exporting ? null : _exportPdf,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.grid_on_outlined),
                                label: const Text('Excel'),
                                onPressed: _exporting ? null : _exportExcel,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.table_rows_outlined),
                                label: const Text('CSV'),
                                onPressed: _exporting ? null : _exportCsv,
                              ),
                            ),
                          ],
                        ),
                        if (_exporting) ...[
                          const SizedBox(height: 12),
                          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, _Period p) {
    final selected = _period == p;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryGreen,
      labelStyle: TextStyle(color: selected ? Colors.white : null),
      onSelected: (_) {
        setState(() => _period = p);
        _load();
      },
    );
  }

  Widget _statTile(String label, String value, Color color, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _reportCard(String title, double value, {String? subtitle, bool isDanger = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: Text(
          _currencyFmt.format(value),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDanger ? AppColors.danger : (value < 0 ? AppColors.danger : AppColors.primaryGreen),
          ),
        ),
      ),
    );
  }
}
