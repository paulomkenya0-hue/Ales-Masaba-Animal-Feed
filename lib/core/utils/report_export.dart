import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as ex;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/sale_model.dart';

/// ReportExporter - Huhamisha ripoti kwenda PDF, Excel (.xlsx), na CSV.
class ReportExporter {
  static final _currencyFmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  // ---------------------------------------------------------------------
  // PDF - Muhtasari wa Ripoti
  // ---------------------------------------------------------------------
  static Future<void> exportPdf({
    required String periodLabel,
    required double totalSales,
    required double totalExpenses,
    required int salesCount,
    required List<Map<String, dynamic>> topProducts,
    required Map<String, double> expenseByCategory,
    required Map<String, double> stockValue,
    required double outstandingCredit,
    String businessName = 'Ales Masaba Animal Feed',
    String? logoPath,
  }) async {
    final doc = pw.Document();
    pw.MemoryImage? logo;
    if (logoPath != null && logoPath.isNotEmpty) {
      final file = File(logoPath);
      if (await file.exists()) logo = pw.MemoryImage(await file.readAsBytes());
    }
    final profit = totalSales - totalExpenses;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(businessName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Ripoti: $periodLabel', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('Imetolewa: ${_dateFmt.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if (logo != null) pw.Image(logo, height: 50, width: 50),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(),
          _summaryRow('Jumla ya Mauzo', totalSales),
          _summaryRow('Matumizi', totalExpenses),
          _summaryRow('Faida', profit),
          _summaryRow('Idadi ya Mauzo (Risiti)', salesCount.toDouble(), isCount: true),
          _summaryRow('Thamani ya Hifadhi (Ununuzi)', stockValue['cost'] ?? 0),
          _summaryRow('Thamani ya Hifadhi (Kuuzia)', stockValue['retail'] ?? 0),
          _summaryRow('Madeni Yanayodaiwa', outstandingCredit),
          pw.SizedBox(height: 20),

          pw.Text('Bidhaa Zinazouzwa Zaidi', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (topProducts.isEmpty)
            pw.Text('Hakuna mauzo kwenye kipindi hiki', style: const pw.TextStyle(fontSize: 10))
          else
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.5), 2: pw.FlexColumnWidth(2)},
              children: [
                pw.TableRow(children: [
                  _cell('Bidhaa', bold: true),
                  _cell('Kiasi', bold: true),
                  _cell('Mapato', bold: true),
                ]),
                ...topProducts.map((p) => pw.TableRow(children: [
                      _cell(p['productName'] as String? ?? '—'),
                      _cell((p['quantity'] as double).toStringAsFixed(0)),
                      _cell(_currencyFmt.format(p['revenue'])),
                    ])),
              ],
            ),
          pw.SizedBox(height: 20),

          pw.Text('Matumizi kwa Aina', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (expenseByCategory.isEmpty)
            pw.Text('Hakuna matumizi kwenye kipindi hiki', style: const pw.TextStyle(fontSize: 10))
          else
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
              children: [
                pw.TableRow(children: [_cell('Aina', bold: true), _cell('Kiasi', bold: true)]),
                ...expenseByCategory.entries.map((e) => pw.TableRow(children: [
                      _cell(e.key),
                      _cell(_currencyFmt.format(e.value)),
                    ])),
              ],
            ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'Ripoti_${_dateFmt.format(DateTime.now())}.pdf');
  }

  static pw.Widget _summaryRow(String label, double value, {bool isCount = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
            pw.Text(isCount ? value.toStringAsFixed(0) : _currencyFmt.format(value),
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  // ---------------------------------------------------------------------
  // EXCEL (.xlsx) - Majedwali kamili
  // ---------------------------------------------------------------------
  static Future<void> exportExcel({
    required String periodLabel,
    required double totalSales,
    required double totalExpenses,
    required List<Map<String, dynamic>> topProducts,
    required Map<String, double> expenseByCategory,
    required List<SaleModel> sales,
  }) async {
    final excel = ex.Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, 'Muhtasari');

    final summary = excel['Muhtasari'];
    summary.appendRow([ex.TextCellValue('Ripoti'), ex.TextCellValue(periodLabel)]);
    summary.appendRow([ex.TextCellValue('Jumla ya Mauzo'), ex.DoubleCellValue(totalSales)]);
    summary.appendRow([ex.TextCellValue('Matumizi'), ex.DoubleCellValue(totalExpenses)]);
    summary.appendRow([ex.TextCellValue('Faida'), ex.DoubleCellValue(totalSales - totalExpenses)]);

    final productsSheet = excel['Bidhaa Zinazouzwa Zaidi'];
    productsSheet.appendRow([ex.TextCellValue('Bidhaa'), ex.TextCellValue('Kiasi'), ex.TextCellValue('Mapato')]);
    for (final p in topProducts) {
      productsSheet.appendRow([
        ex.TextCellValue(p['productName'] as String? ?? '—'),
        ex.DoubleCellValue((p['quantity'] as double)),
        ex.DoubleCellValue((p['revenue'] as num).toDouble()),
      ]);
    }

    final expenseSheet = excel['Matumizi kwa Aina'];
    expenseSheet.appendRow([ex.TextCellValue('Aina'), ex.TextCellValue('Kiasi')]);
    for (final e in expenseByCategory.entries) {
      expenseSheet.appendRow([ex.TextCellValue(e.key), ex.DoubleCellValue(e.value)]);
    }

    final salesSheet = excel['Mauzo Yote'];
    salesSheet.appendRow([
      ex.TextCellValue('Risiti'),
      ex.TextCellValue('Tarehe'),
      ex.TextCellValue('Mteja'),
      ex.TextCellValue('Njia ya Malipo'),
      ex.TextCellValue('Jumla'),
    ]);
    for (final s in sales) {
      salesSheet.appendRow([
        ex.TextCellValue(s.receiptNumber),
        ex.TextCellValue(_dateFmt.format(DateTime.parse(s.saleDate))),
        ex.TextCellValue(s.customerName ?? '—'),
        ex.TextCellValue(s.paymentMethod),
        ex.DoubleCellValue(s.totalAmount),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) throw Exception('Imeshindikana kutengeneza Excel');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Ripoti_${_dateFmt.format(DateTime.now())}.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Ripoti - $periodLabel');
  }

  // ---------------------------------------------------------------------
  // CSV - Orodha bapa ya mauzo (kwa Excel/Google Sheets rahisi)
  // ---------------------------------------------------------------------
  static Future<void> exportCsv(List<SaleModel> sales, String periodLabel) async {
    final buffer = StringBuffer();
    buffer.writeln('Risiti,Tarehe,Mteja,Njia ya Malipo,Jumla');
    for (final s in sales) {
      final customer = (s.customerName ?? '—').replaceAll(',', ' ');
      buffer.writeln('${s.receiptNumber},${_dateFmt.format(DateTime.parse(s.saleDate))},$customer,${s.paymentMethod},${s.totalAmount}');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Mauzo_${_dateFmt.format(DateTime.now())}.csv');
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(file.path)], text: 'Mauzo - $periodLabel');
  }
}
