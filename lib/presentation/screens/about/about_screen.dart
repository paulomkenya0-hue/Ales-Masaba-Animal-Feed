import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';

/// AboutScreen - Taarifa za mtengenezaji, toleo, na hakimiliki
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(SW.aboutApp)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.eco, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(SW.appName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _infoRow(SW.developerName, 'Paulo Mkenya'),
              _infoRow('Toleo', '1.0.0'),
              _infoRow(SW.appInfo, 'Mfumo wa kusimamia biashara ya vyakula vya mifugo - 100% Offline'),
              const SizedBox(height: 24),
              const Text(SW.copyright, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
