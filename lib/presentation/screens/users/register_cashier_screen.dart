import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/strings_sw.dart';
import '../../providers/auth_provider.dart';

/// RegisterCashierScreen - Super Admin anasajili Cashier mpya (duka/tawi
/// jipya) akiwa na Username na Password fixed. Cashier ataingia kwa taarifa
/// hizi hizi (Super Admin pekee ndiye anayeweza kuzibadilisha baadaye).
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
    );
    setState(() => _isSaving = false);

    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(SW.cashierRegistered)),
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
    return Scaffold(
      appBar: AppBar(title: const Text(SW.registerCashier)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _branchCtrl,
                decoration: const InputDecoration(
                  labelText: SW.branchName,
                  prefixIcon: Icon(Icons.storefront),
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
