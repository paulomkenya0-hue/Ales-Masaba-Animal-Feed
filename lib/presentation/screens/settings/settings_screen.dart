import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../core/utils/biometric_helper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../backup/backup_screen.dart';
import 'change_password_screen.dart';

/// SettingsScreen - Mipangilio halisi ya biashara, zinazohifadhiwa kwenye SQLite
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricSupported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().load();
      _loadBiometricState();
    });
  }

  Future<void> _loadBiometricState() async {
    final supported = await BiometricHelper.isAvailable();
    final enabled = await context.read<AuthProvider>().isBiometricEnabled();
    if (mounted) setState(() {
      _biometricSupported = supported;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _editTextField(String key, String label, String currentValue) async {
    final ctrl = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(label),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(SW.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text(SW.save)),
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
                _settingsTile(Icons.store, SW.businessName, s['business_name'] ?? '',
                    () => _editTextField('business_name', SW.businessName, s['business_name'] ?? '')),
                _settingsTile(Icons.phone, SW.phoneNumber, s['phone'] ?? '—',
                    () => _editTextField('phone', SW.phoneNumber, s['phone'] ?? '')),
                _settingsTile(Icons.location_on, SW.address, s['address'] ?? '—',
                    () => _editTextField('address', SW.address, s['address'] ?? '')),
                _settingsTile(Icons.attach_money, SW.currency, s['currency'] ?? 'TZS',
                    () => _editTextField('currency', SW.currency, s['currency'] ?? 'TZS')),
                _settingsTile(Icons.percent, SW.taxPercentage, '${s['tax_percentage'] ?? 0}%',
                    () => _editTextField('tax_percentage', SW.taxPercentage, '${s['tax_percentage'] ?? 0}')),
                const SizedBox(height: 16),
                const Divider(),
                if (_biometricSupported)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: SwitchListTile(
                      secondary: const Icon(Icons.fingerprint),
                      title: const Text(SW.useFingerprint),
                      value: _biometricEnabled,
                      onChanged: (v) async {
                        await context.read<AuthProvider>().setBiometricEnabled(v);
                        setState(() => _biometricEnabled = v);
                      },
                    ),
                  ),
                _settingsTile(Icons.backup, SW.backup, '',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()))),
                _settingsTile(Icons.lock, SW.changePassword, '',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
              ],
            ),
    );
  }

  Widget _settingsTile(IconData icon, String title, String value, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: value.isNotEmpty ? Text(value, style: const TextStyle(color: Colors.grey)) : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
