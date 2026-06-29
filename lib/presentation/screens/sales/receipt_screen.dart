import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../core/utils/receipt_generator.dart';
import '../../../data/models/sale_model.dart';

/// ReceiptScreen - Huonyesha risiti baada ya mauzo, na chaguo za Chapisha/Shiriki/Hifadhi
class ReceiptScreen extends StatelessWidget {
  final SaleModel sale;
  const ReceiptScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text(SW.receipt)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 56),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '${SW.receiptNumber}: ${sale.receiptNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Divider(height: 24),
                    if (sale.customerName != null)
                      _row(SW.customerName, sale.customerName!),
                    _row(SW.paymentMethod, sale.paymentMethod),
                    const Divider(height: 24),
                    ...sale.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text('${item.productName} x${item.quantity.toStringAsFixed(0)}')),
                              Text(currencyFmt.format(item.subtotal)),
                            ],
                          ),
                        )),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(SW.grandTotal, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          currencyFmt.format(sale.totalAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text(SW.print),
                    onPressed: () => ReceiptGenerator.printReceipt(sale),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text(SW.sharePdf),
                    onPressed: () => ReceiptGenerator.shareReceipt(sale),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt),
              label: const Text(SW.savePdf),
              onPressed: () async {
                final path = await ReceiptGenerator.saveReceipt(sale);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${SW.savedSuccess}: $path')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label, style: const TextStyle(color: Colors.grey)), Text(value)],
        ),
      );
}
