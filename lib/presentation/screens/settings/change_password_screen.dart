import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/strings_sw.dart';
import '../../providers/auth_provider.dart';

/// ChangePasswordScreen - Hubadilisha nenosiri la mtumiaji aliyeingia
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _isSaving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenosiri hayafanani')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final ok = await context.read<AuthProvider>().changePassword(_newPassCtrl.text);
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? SW.savedSuccess : SW.error)),
      );
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(SW.changePassword)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _newPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nenosiri Jipya'),
                validator: (v) => (v == null || v.length < 4) ? 'Nenosiri linahitaji herufi/namba angalau 4' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Thibitisha Nenosiri Jipya'),
                validator: (v) => (v == null || v.isEmpty) ? SW.required : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text(SW.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
