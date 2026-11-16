import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../core/utils/receipt_generator.dart';
import '../../../data/models/sale_model.dart';
import '../../providers/settings_provider.dart';

/// ReceiptScreen - Onyesho la awali (preview) la risiti ya PDF baada ya mauzo,
/// pamoja na Chapisha / Shiriki / Hifadhi PDF.
class ReceiptScreen extends StatelessWidget {
  final SaleModel sale;
  const ReceiptScreen({super.key, required this.sale});

  BusinessInfo _business(SettingsProvider settings) => BusinessInfo(
        name: settings.businessName,
        phone: settings.settings['phone'] as String?,
        address: settings.settings['address'] as String?,
        logoPath: settings.settings['logo_path'] as String?,
      );

  @override
  Widget build(BuildContext context) {
    final business = _business(context.watch<SettingsProvider>());

    return Scaffold(
      appBar: AppBar(
        title: Text('${SW.receipt} ${sale.receiptNumber}'),
        actions: [
          IconButton(
            tooltip: SW.savePdf,
            icon: const Icon(Icons.save_alt),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final path = await ReceiptGenerator.saveReceipt(sale, business: business);
              messenger.showSnackBar(SnackBar(content: Text('${SW.savedSuccess}: $path')));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Muhtasari wa haraka juu ya risiti
          Container(
            width: double.infinity,
            color: (sale.hasDebt ? AppColors.danger : AppColors.primaryGreen).withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(sale.hasDebt ? Icons.schedule : Icons.check_circle,
                    color: sale.hasDebt ? AppColors.danger : AppColors.primaryGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sale.hasDebt
                        ? 'Mauzo yamerekodiwa - deni lililobaki TZS ${sale.balance.toStringAsFixed(0)}'
                        : 'Mauzo yamekamilika - imelipwa kamili',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (format) async => (await ReceiptGenerator.buildReceipt(sale, business: business)).save(),
              pdfFileName: '${sale.receiptNumber}.pdf',
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              allowPrinting: true,
              allowSharing: true,
              loadingWidget: const CircularProgressIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}
