import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/constants/strings_sw.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../backup/backup_screen.dart';
import '../users/cashier_list_screen.dart';
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

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final dir = await getApplicationDocumentsDirectory();
    final ext = picked.path.split('.').last;
    final savedFile = File('${dir.path}/business_logo.$ext');
    await savedFile.writeAsBytes(await picked.readAsBytes());

    if (mounted) {
      await context.read<SettingsProvider>().update({'logo_path': savedFile.path});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(SW.savedSuccess)),
      );
    }
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
    final auth = context.watch<AuthProvider>();
    final s = settings.settings;

    return Scaffold(
      appBar: AppBar(title: const Text(SW.settings)),
      body: settings.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (auth.isSuperAdmin) ...[
                  _logoTile(s['logo_path'] as String?),
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
                  _tile(Icons.groups, SW.cashierManagement, '',
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashierListScreen()))),
                  _tile(Icons.backup, SW.backup, '',
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()))),
                ],
                _tile(Icons.lock, SW.changePassword, '',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
              ],
            ),
    );
  }

  Widget _logoTile(String? logoPath) {
    final hasLogo = logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          backgroundImage: hasLogo ? FileImage(File(logoPath)) : null,
          child: hasLogo ? null : const Icon(Icons.image_outlined),
        ),
        title: const Text(SW.businessLogo),
        subtitle: Text(hasLogo ? SW.savedSuccess : 'Bado hujaweka nembo'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _pickLogo,
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
