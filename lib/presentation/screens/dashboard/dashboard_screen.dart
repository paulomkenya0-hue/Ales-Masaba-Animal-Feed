import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../products/product_list_screen.dart';
import '../sales/new_sale_screen.dart';
import '../credit/credit_list_screen.dart';
import '../expenses/expense_screen.dart';
import '../reports/reports_screen.dart';
import '../backup/backup_screen.dart';
import '../settings/settings_screen.dart';
import '../about/about_screen.dart';
import '../auth/login_screen.dart';
import '../../widgets/weekly_sales_chart.dart';
import '../../widgets/daily_closing_dialog.dart';

/// DashboardScreen - Mwonekano mkuu wa programu: takwimu, arifa, na uingiaji wa moduli zote
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(SW.dashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: dash.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => dash.loadDashboard(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dash.lowStockProducts.isNotEmpty || dash.todaySales == 0 || dash.backupOverdue) _buildAlerts(dash),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        _statCard(SW.todaySales, _currencyFmt.format(dash.todaySales), Icons.point_of_sale, AppColors.primaryGreen),
                        _statCard(SW.todayProfit, _currencyFmt.format(dash.todayProfit), Icons.trending_up, AppColors.lightGreen),
                        _statCard(SW.weeklySales, _currencyFmt.format(dash.weeklySales), Icons.calendar_view_week, AppColors.warning),
                        _statCard(SW.monthlySales, _currencyFmt.format(dash.monthlySales), Icons.calendar_month, AppColors.darkGreen),
                        _statCard(SW.customersWithCredit, _currencyFmt.format(dash.totalOutstandingCredit), Icons.people_outline, AppColors.danger),
                        _statCard(SW.lowStockProducts, '${dash.lowStockProducts.length}', Icons.warning_amber, AppColors.warning),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Text(SW.recentActivities, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    if (dash.highestCreditCustomer != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.person, color: AppColors.danger),
                          title: const Text(SW.highestCreditCustomer),
                          subtitle: Text('${dash.highestCreditCustomer!['name']} • ${dash.highestCreditCustomer!['phone'] ?? ''}'),
                          trailing: Text(_currencyFmt.format(dash.highestCreditCustomer!['balance'])),
                        ),
                      ),

                    const SizedBox(height: 16),
                    _buildQuickActions(context),
                    const SizedBox(height: 24),
                    const WeeklySalesChart(),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event_note),
                      label: const Text(SW.dailyClosingQuestion),
                      onPressed: () => DailyClosingDialog.show(context),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewSaleScreen())),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text(SW.newSale),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Widget _buildAlerts(DashboardProvider dash) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.notifications_active, color: AppColors.warning),
              SizedBox(width: 8),
              Text(SW.notifications, style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          if (dash.todaySales == 0) const Text('• ${SW.alertNoSalesToday}'),
          if (dash.lowStockProducts.isNotEmpty) Text('• Bidhaa ${dash.lowStockProducts.length} zinapungua kwenye hifadhi'),
          if (dash.totalOutstandingCredit > 0) const Text('• ${SW.alertCustomersOwe}'),
          if (dash.backupOverdue) const Text('• ${SW.backupReminder}'),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 26),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _actionChip(context, SW.products, Icons.inventory_2_outlined, const ProductListScreen()),
        _actionChip(context, SW.creditList, Icons.credit_score_outlined, const CreditListScreen()),
        _actionChip(context, SW.expenses, Icons.receipt_long_outlined, const ExpenseScreen()),
        _actionChip(context, SW.reports, Icons.bar_chart_outlined, const ReportsScreen()),
        _actionChip(context, SW.backup, Icons.backup_outlined, const BackupScreen()),
      ],
    );
  }

  Widget _actionChip(BuildContext context, String label, IconData icon, Widget screen) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.primaryGreen),
      label: Text(label),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
    );
  }
}
