import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/strings_sw.dart';
import '../../providers/settings_provider.dart';
import '../backup/backup_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().load();
    });
  }

  Future<void> _editTextField(
      String key, String label, String currentValue) async {
    final ctrl = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(label),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(SW.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text(SW.save),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await context.read<SettingsProvider>().update({key: result});
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final s = settings.settings;

    return Scaffold(
      appBar: AppBar(title: const Text(SW.settings)),
      body: settings.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _tile(Icons.store, SW.businessName, s['business_name'] ?? '',
                    () => _editTextField('business_name', SW.businessName, s['business_name'] ?? '')),
                _tile(Icons.phone, SW.phoneNumber, s['phone'] ?? '—',
                    () => _editTextField('phone', SW.phoneNumber, s['phone'] ?? '')),
                _tile(Icons.location_on, SW.address, s['address'] ?? '—',
                    () => _editTextField('address', SW.address, s['address'] ?? '')),
                _tile(Icons.attach_money, SW.currency, s['currency'] ?? 'TZS',
                    () => _editTextField('currency', SW.currency, s['currency'] ?? 'TZS')),
                _tile(Icons.percent, SW.taxPercentage, '${s['tax_percentage'] ?? 0}%',
                    () => _editTextField('tax_percentage', SW.taxPercentage, '${s['tax_percentage'] ?? 0}')),
                const SizedBox(height: 16),
                const Divider(),
                _tile(Icons.backup, SW.backup, '',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()))),
                _tile(Icons.lock, SW.changePassword, '',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
              ],
            ),
    );
  }

  Widget _tile(IconData icon, String title, String value, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: value.isNotEmpty
            ? Text(value, style: const TextStyle(color: Colors.grey))
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
