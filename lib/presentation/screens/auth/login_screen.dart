import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../core/utils/biometric_helper.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';

/// LoginScreen - Mfumo wa kuingia salama na PIN/Fingerprint, Remember Me, Forgot Password
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _rememberMe = false;
  bool _obscure = true;

  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadSavedUsername();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricHelper.isAvailable();
    final enabled = await context.read<AuthProvider>().isBiometricEnabled();
    if (mounted) setState(() => _biometricAvailable = available && enabled);
  }

  Future<void> _loginWithFingerprint() async {
    final success = await BiometricHelper.authenticate();
    if (!success) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithBiometric();
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? SW.error)));
    }
  }

  Future<void> _loadSavedUsername() async {
    final auth = context.read<AuthProvider>();
    final saved = await auth.getSavedUsername();
    if (saved != null && mounted) {
      setState(() {
        _usernameCtrl.text = saved;
        _rememberMe = true;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text, rememberMe: _rememberMe);
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(SW.forgotPassword),
        content: TextField(
          controller: emailCtrl,
          decoration: const InputDecoration(labelText: 'Barua Pepe Iliyosajiliwa'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(SW.cancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(SW.resetViaEmail)),
              );
            },
            child: const Text(SW.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.eco, size: 48, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  SW.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkGreen),
                ),
                const SizedBox(height: 32),

                if (auth.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(auth.errorMessage!, style: const TextStyle(color: AppColors.danger)),
                  ),

                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: SW.username,
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? SW.required : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: SW.password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? SW.required : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    ),
                    const Text(SW.rememberLogin),
                    const Spacer(),
                    TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text(SW.forgotPassword),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(SW.login),
                ),
                if (_biometricAvailable) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loginWithFingerprint,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text(SW.useFingerprint),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ingia kwa nenosiri kisha washa alama ya kidole kwenye Mipangilio')),
                      );
                    },
                    icon: const Icon(Icons.fingerprint),
                    label: const Text(SW.useFingerprint),
                  ),
                ],
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 12),
                const Text(SW.developedBy, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const Text(SW.version, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
