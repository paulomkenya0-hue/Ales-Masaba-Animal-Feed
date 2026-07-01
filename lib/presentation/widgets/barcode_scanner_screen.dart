import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/strings_sw.dart';

/// BarcodeScannerScreen - Imezimwa kwa sasa (inahitaji ruhusa ya CAMERA)
class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skana Barcode')),
      body: const Center(
        child: Text(
          'Kipengele hiki kitapatikana hivi karibuni.',
          style: TextStyle(color: AppColors.darkGreen, fontSize: 16),
        ),
      ),
    );
  }
}
