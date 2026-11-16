import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/sale_model.dart';

/// Taarifa za biashara zinazoonekana juu ya risiti
class BusinessInfo {
  final String name;
  final String? phone;
  final String? address;
  final String? logoPath;
  const BusinessInfo({
    this.name = 'Ales Masaba Animal Feed',
    this.phone,
    this.address,
    this.logoPath,
  });
}

/// ReceiptGenerator - Hutengeneza risiti ya kitaalamu (PDF) kutoka kwenye SaleModel:
/// jina la biashara, namba ya risiti, tarehe na saa, muuzaji, mteja, bidhaa zote
/// (kiasi, bei, jumla), jumla kuu, kilicholipwa, salio/chenji na njia ya malipo.
/// Inatumika kwa: Print, Share PDF, Save PDF.
class ReceiptGenerator {
  static final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);
  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  static String _qty(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// Hujenga hati ya PDF ya risiti moja (A5 - inaweza kuchapishwa au kutumwa WhatsApp).
  /// Ukurasa unajipanua kwa bidhaa nyingi (MultiPage), hivyo orodha ndefu haikatiki.
  static Future<pw.Document> buildReceipt(SaleModel sale, {BusinessInfo business = const BusinessInfo()}) async {
    final doc = pw.Document();
    pw.MemoryImage? logo;
    if (business.logoPath != null && business.logoPath!.isNotEmpty) {
      final file = File(business.logoPath!);
      if (await file.exists()) {
        logo = pw.MemoryImage(await file.readAsBytes());
      }
    }

    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    const small = pw.TextStyle(fontSize: 10);
    final when = DateTime.tryParse(sale.saleDate);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Center(
            child: pw.Column(
              children: [
                if (logo != null) ...[
                  pw.Image(logo, height: 56, width: 56),
                  pw.SizedBox(height: 6),
                ],
                pw.Text(business.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                if (business.address != null && business.address!.isNotEmpty) pw.Text(business.address!, style: small),
                if (business.phone != null && business.phone!.isNotEmpty) pw.Text('Simu: ${business.phone}', style: small),
                pw.SizedBox(height: 4),
                pw.Text('RISITI', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Namba ya Risiti: ${sale.receiptNumber}', style: small),
              pw.Text(when != null ? _dateFmt.format(when) : sale.saleDate, style: small),
            ],
          ),
          if (sale.cashierName != null && sale.cashierName!.isNotEmpty)
            pw.Text('Muuzaji: ${sale.cashierName}', style: small),
          if (sale.branchName != null && sale.branchName!.isNotEmpty) pw.Text('Tawi: ${sale.branchName}', style: small),
          if (sale.customerName != null && sale.customerName!.isNotEmpty)
            pw.Text('Mteja: ${sale.customerName}', style: small),
          pw.SizedBox(height: 10),
          pw.Table(
            border: const pw.TableBorder(bottom: pw.BorderSide(width: 0.5)),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                children: [
                  _cell('Bidhaa', bold: true),
                  _cell('Kiasi', bold: true, right: true),
                  _cell('Bei', bold: true, right: true),
                  _cell('Jumla', bold: true, right: true),
                ],
              ),
              ...sale.items.map((item) => pw.TableRow(children: [
                    _cell(item.productName ?? ''),
                    _cell('${_qty(item.quantity)} ${item.unit ?? ''}'.trim(), right: true),
                    _cell(_currencyFmt.format(item.unitPrice), right: true),
                    _cell(_currencyFmt.format(item.subtotal), right: true),
                  ])),
            ],
          ),
          pw.SizedBox(height: 10),
          _totalRow('JUMLA KUU', _currencyFmt.format(sale.totalAmount), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          _totalRow('Njia ya Malipo', sale.amountPaid > 0 ? sale.paymentMethod : 'Mkopo', style: small),
          if (sale.paymentReference != null) _totalRow('Namba ya Muamala', sale.paymentReference!, style: small),
          _totalRow('Kiasi Kilicholipwa', _currencyFmt.format(sale.amountPaid), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          if (sale.changeGiven > 0) _totalRow('Chenji', _currencyFmt.format(sale.changeGiven), style: small),
          if (sale.hasDebt) ...[
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('DENI LILILOBAKI', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_currencyFmt.format(sale.balance), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ] else ...[
            pw.SizedBox(height: 6),
            pw.Center(child: pw.Text('IMELIPWA KAMILI', style: bold)),
          ],
          pw.SizedBox(height: 20),
          pw.Center(child: pw.Text('Asante kwa Kununua Nasi!', style: const pw.TextStyle(fontSize: 11))),
        ],
      ),
    );

    return doc;
  }

  static pw.Widget _totalRow(String label, String value, {required pw.TextStyle style}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Text(label, style: style), pw.Text(value, style: style)],
        ),
      );

  static pw.Widget _cell(String text, {bool bold = false, bool right = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
      );

  /// Chapisha risiti moja kwa moja kwenye printer (Bluetooth/USB inayotambuliwa na mfumo)
  static Future<void> printReceipt(SaleModel sale, {BusinessInfo business = const BusinessInfo()}) async {
    final doc = await buildReceipt(sale, business: business);
    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: sale.receiptNumber);
  }

  /// Shiriki PDF kupitia WhatsApp, Email, n.k.
  static Future<void> shareReceipt(SaleModel sale, {BusinessInfo business = const BusinessInfo()}) async {
    final doc = await buildReceipt(sale, business: business);
    await Printing.sharePdf(bytes: await doc.save(), filename: '${sale.receiptNumber}.pdf');
  }

  /// Hifadhi PDF kwenye hifadhi ya simu, inarudisha njia (path) ya faili
  static Future<String> saveReceipt(SaleModel sale, {BusinessInfo business = const BusinessInfo()}) async {
    final doc = await buildReceipt(sale, business: business);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${sale.receiptNumber}.pdf');
    await file.writeAsBytes(await doc.save());
    return file.path;
  }
}
