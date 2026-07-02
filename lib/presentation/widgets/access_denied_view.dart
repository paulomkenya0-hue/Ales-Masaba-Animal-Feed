import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// AccessDeniedView - Inaonekana kama Cashier atajaribu kufikia skrini
/// iliyozuiwa kwa Super Admin pekee (ulinzi wa ziada; ulinzi halisi upo
/// kwenye Firestore Security Rules upande wa server).
class AccessDeniedView extends StatelessWidget {
  const AccessDeniedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 56, color: AppColors.danger.withOpacity(0.7)),
            const SizedBox(height: 16),
            const Text(
              'Huna ruhusa ya kufikia sehemu hii',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sehemu hii ni ya Msimamizi Mkuu pekee. Wasiliana naye kama unahitaji taarifa hii.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Rudi Nyuma'),
            ),
          ],
        ),
      ),
    );
  }
}
