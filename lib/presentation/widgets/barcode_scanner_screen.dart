import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skana Barcode')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 80, color: AppColors.primaryGreen),
            SizedBox(height: 16),
            Text(
              'Kipengele hiki kitapatikana hivi karibuni.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.darkGreen),
            ),
          ],
        ),
      ),
    );
  }
}
