import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'register_cashier_screen.dart';

/// CashierListScreen - Super Admin anaona maduka/Cashier zote alizosajili,
/// anaweza kuzima/kuwasha akaunti, kubadilisha jina la tawi, au kubadilisha
/// password.
class CashierListScreen extends StatelessWidget {
  const CashierListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text(SW.cashierManagement)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegisterCashierScreen()),
        ),
        icon: const Icon(Icons.person_add),
        label: const Text(SW.registerCashier),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: authProvider.watchCashiers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Imeshindikana kupakia orodha: ${snapshot.error}'),
              ),
            );
          }
          final cashiers = snapshot.data ?? [];
          if (cashiers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(SW.noCashiersYet, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: cashiers.length,
            itemBuilder: (context, i) => _CashierCard(cashier: cashiers[i]),
          );
        },
      ),
    );
  }
}

class _CashierCard extends StatelessWidget {
  final UserModel cashier;
  const _CashierCard({required this.cashier});

  void _openActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_location_alt_outlined),
              title: const Text(SW.editBranch),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditBranchDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text(SW.changeCashierPassword),
              onTap: () {
                Navigator.pop(sheetContext);
                _showChangePasswordDialog(context);
              },
            ),
            ListTile(
              leading: Icon(
                cashier.isActive ? Icons.block : Icons.check_circle_outline,
                color: cashier.isActive ? AppColors.danger : AppColors.primaryGreen,
              ),
              title: Text(cashier.isActive ? SW.deactivateAccount : SW.activateAccount),
              onTap: () async {
                Navigator.pop(sheetContext);
                final ok = await context
                    .read<AuthProvider>()
                    .setCashierActive(cashier.uid!, !cashier.isActive);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? SW.savedSuccess : SW.error)),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBranchDialog(BuildContext context) {
    final ctrl = TextEditingController(text: cashier.branchName ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(SW.editBranch),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: SW.branchName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(SW.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final ok = await context
                  .read<AuthProvider>()
                  .updateCashierBranch(cashier.uid!, ctrl.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? SW.savedSuccess : SW.error)),
                );
              }
            },
            child: const Text(SW.save),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${SW.changeCashierPassword} (${cashier.username})'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: SW.currentPassword),
                validator: (v) => (v == null || v.isEmpty) ? SW.required : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: SW.newPassword),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Angalau herufi 6'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: SW.confirmNewPassword),
                validator: (v) => (v == null || v.isEmpty) ? SW.required : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(SW.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Password hazifanani')),
                );
                return;
              }
              final authProvider = context.read<AuthProvider>();
              final ok = await authProvider.changeCashierPassword(
                username: cashier.username,
                oldPassword: oldCtrl.text,
                newPassword: newCtrl.text,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(ok
                          ? SW.savedSuccess
                          : (authProvider.errorMessage ?? SW.error))),
                );
              }
            },
            child: const Text(SW.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor:
              cashier.isActive ? AppColors.primaryGreen : AppColors.danger,
          foregroundColor: Colors.white,
          child: Text(
            cashier.branchName?.isNotEmpty == true
                ? cashier.branchName![0].toUpperCase()
                : cashier.username.isNotEmpty
                    ? cashier.username[0].toUpperCase()
                    : '?',
          ),
        ),
        title: Text(cashier.branchName?.isNotEmpty == true
            ? cashier.branchName!
            : cashier.username),
        subtitle: Text(
          '@${cashier.username}${cashier.fullName != null ? ' · ${cashier.fullName}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (cashier.isActive ? AppColors.primaryGreen : AppColors.danger)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                cashier.isActive ? SW.active : SW.inactive,
                style: TextStyle(
                  color: cashier.isActive ? AppColors.primaryGreen : AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _openActions(context),
            ),
          ],
        ),
      ),
    );
  }
}
