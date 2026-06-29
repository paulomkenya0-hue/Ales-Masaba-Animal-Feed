import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/sale_model.dart';

/// ReceiptGenerator - Hutengeneza risiti ya kitaalamu kwa PDF kutoka kwenye SaleModel.
/// Inatumika kwa: Print, Share PDF, Save PDF (kama ilivyoombwa kwenye hitaji).
class ReceiptGenerator {
  static final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);
  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  /// Hujenga hati ya PDF ya risiti moja.
  static Future<pw.Document> buildReceipt(SaleModel sale, {String businessName = 'Ales Masaba Animal Feed', String? businessPhone, String? businessAddress}) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(businessName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      if (businessAddress != null) pw.Text(businessAddress, style: const pw.TextStyle(fontSize: 10)),
                      if (businessPhone != null) pw.Text(businessPhone, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Namba ya Risiti: ${sale.receiptNumber}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(_dateFmt.format(DateTime.parse(sale.saleDate)), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                if (sale.customerName != null)
                  pw.Text('Mteja: ${sale.customerName}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Njia ya Malipo: ${sale.paymentMethod}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder(bottom: pw.BorderSide(width: 0.5)),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(3),
                    1: pw.FlexColumnWidth(1.2),
                    2: pw.FlexColumnWidth(1.5),
                    3: pw.FlexColumnWidth(1.8),
                  },
                  children: [
                    pw.TableRow(children: [
                      _cell('Bidhaa', bold: true),
                      _cell('Kiasi', bold: true),
                      _cell('Bei', bold: true),
                      _cell('Jumla', bold: true),
                    ]),
                    ...sale.items.map((item) => pw.TableRow(children: [
                          _cell(item.productName ?? ''),
                          _cell(item.quantity.toStringAsFixed(0)),
                          _cell(_currencyFmt.format(item.unitPrice)),
                          _cell(_currencyFmt.format(item.subtotal)),
                        ])),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('JUMLA KUU', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_currencyFmt.format(sale.totalAmount), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Center(child: pw.Text('Asante kwa Kununua Nasi!', style: const pw.TextStyle(fontSize: 11))),
              ],
            ),
          );
        },
      ),
    );

    return doc;
  }

  static pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  /// Chapisha risiti moja kwa moja kwenye printer (Bluetooth/USB inayotambuliwa na mfumo)
  static Future<void> printReceipt(SaleModel sale) async {
    final doc = await buildReceipt(sale);
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  /// Shiriki PDF kupitia WhatsApp, Email, n.k.
  static Future<void> shareReceipt(SaleModel sale) async {
    final doc = await buildReceipt(sale);
    await Printing.sharePdf(bytes: await doc.save(), filename: '${sale.receiptNumber}.pdf');
  }

  /// Hifadhi PDF kwenye hifadhi ya simu, inarudisha njia (path) ya faili
  static Future<String> saveReceipt(SaleModel sale) async {
    final doc = await buildReceipt(sale);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${sale.receiptNumber}.pdf');
    await file.writeAsBytes(await doc.save());
    return file.path;
  }
}
