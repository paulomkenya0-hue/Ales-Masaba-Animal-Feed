import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';

/// RegisterCashierScreen - Super Admin anasajili Cashier mpya (duka/tawi
/// jipya) AU Msimamizi Mkuu mwingine (akaunti huru), akiwa na Username na
/// Password fixed. Super Admin ndiye pekee anayeweza kubadilisha baadaye.
class RegisterCashierScreen extends StatefulWidget {
  const RegisterCashierScreen({super.key});

  @override
  State<RegisterCashierScreen> createState() => _RegisterCashierScreenState();
}

class _RegisterCashierScreenState extends State<RegisterCashierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _branchCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isSaving = false;
  String _role = AppRole.cashier;

  @override
  void dispose() {
    _branchCtrl.dispose();
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password hazifanani')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.registerCashier(
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      branchName: _branchCtrl.text.trim(),
      fullName: _fullNameCtrl.text.trim().isEmpty ? null : _fullNameCtrl.text.trim(),
      role: _role,
    );
    setState(() => _isSaving = false);

    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_role == AppRole.superAdmin ? 'Msimamizi Mkuu ameongezwa' : SW.cashierRegistered)),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage ?? SW.error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdminRole = _role == AppRole.superAdmin;
    return Scaffold(
      appBar: AppBar(title: Text(isSuperAdminRole ? 'Ongeza Msimamizi Mkuu' : SW.registerCashier)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: AppRole.cashier, label: Text(SW.cashierLabel)),
                  ButtonSegment(value: AppRole.superAdmin, label: Text('Msimamizi Mkuu')),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 14),
              if (isSuperAdminRole)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'Akaunti hii itakuwa na uwezo KAMILI (kama wako) - itumike kwa mmiliki/developer pekee, '
                    'ili asifungiwe nje hata kama akaunti nyingine zikibadilishwa password.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              TextFormField(
                controller: _branchCtrl,
                decoration: InputDecoration(
                  labelText: isSuperAdminRole ? 'Jina la Kutambulisha (mf. Mmiliki)' : SW.branchName,
                  prefixIcon: const Icon(Icons.storefront),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? SW.required : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _fullNameCtrl,
                decoration: const InputDecoration(
                  labelText: SW.fullName,
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: SW.username,
                  prefixIcon: Icon(Icons.account_circle_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return SW.required;
                  if (v.trim().contains(' ')) return 'Jina la mtumiaji lisiwe na nafasi';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: SW.password,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Password inahitaji angalau herufi 6'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmPasswordCtrl,
                obscureText: _obscurePassword,
                decoration: const InputDecoration(
                  labelText: SW.confirmNewPassword,
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) => (v == null || v.isEmpty) ? SW.required : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(SW.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
