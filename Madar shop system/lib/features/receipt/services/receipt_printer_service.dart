import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../pos/domain/entities/pos_transaction.dart';

/// خدمة طباعة وتصدير الفواتير والإيصالات الحرارية (80mm Thermal Receipt Printer)
class ReceiptPrinterService {
  static final ReceiptPrinterService instance = ReceiptPrinterService._();
  ReceiptPrinterService._();

  /// طباعة إيصال حراري فوري للعملية
  Future<void> printReceipt(PosTransaction transaction) async {
    final doc = await generateReceiptPdf(transaction);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_${transaction.invoiceNumber}',
    );
  }

  /// إنشاء مستند PDF للإيصال بتنسيق 80mm مع دعم كامل للغة العربية
  Future<pw.Document> generateReceiptPdf(PosTransaction transaction) async {
    final pdf = pw.Document();
    
    // تحميل خط عربي للطباعة
    final fontData = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final timeFormatter = DateFormat('yyyy/MM/dd hh:mm a');
    final formattedDate = timeFormatter.format(transaction.createdAt);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: fontData, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // ── Header ──
              pw.Text(
                'منظومة مدار — كاشير المتاجر',
                style: pw.TextStyle(font: fontBold, fontSize: 13),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                transaction.storeName,
                style: pw.TextStyle(font: fontBold, fontSize: 16),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // ── Details ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('رقم الفاتورة: ${transaction.invoiceNumber}', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(formattedDate, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('الكاشير: ${transaction.cashierName}', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('العميل: ${transaction.customerName}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // ── Items Table ──
              pw.Table(
                border: null,
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.8),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('المادة', style: pw.TextStyle(font: fontBold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('العدد', style: pw.TextStyle(font: fontBold, fontSize: 9), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('السعر', style: pw.TextStyle(font: fontBold, fontSize: 9), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('المجموع', style: pw.TextStyle(font: fontBold, fontSize: 9), textAlign: pw.TextAlign.left)),
                    ],
                  ),
                  ...transaction.items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text(item.product.name, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('${item.quantity}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text(item.unitPrice.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text(item.totalPrice.toStringAsFixed(0), style: pw.TextStyle(font: fontBold, fontSize: 9), textAlign: pw.TextAlign.left)),
                      ],
                    );
                  }),
                ],
              ),

              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // ── Financial Summary ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('المجموع الفرعي:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('${transaction.subtotal.toStringAsFixed(0)} د.ع', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              if (transaction.discount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الخصم:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('- ${transaction.discount.toStringAsFixed(0)} د.ع', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الصافي المطلوب:', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    pw.Text('${transaction.total.toStringAsFixed(0)} د.ع', style: pw.TextStyle(font: fontBold, fontSize: 13)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('المدفوع نقداً:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('${transaction.paidAmount.toStringAsFixed(0)} د.ع', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('المتبقي للزبون:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('${transaction.changeAmount.toStringAsFixed(0)} د.ع', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                ],
              ),

              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // ── QR / Barcode & Footer ──
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: transaction.invoiceNumber,
                width: 130,
                height: 35,
                drawText: false,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'شكراً لتسوقكم من ${transaction.storeName}',
                style: pw.TextStyle(font: fontBold, fontSize: 10),
              ),
              pw.Text(
                'نظام كاشير مدار — دلال القائم',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return pdf;
  }
}
