import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/entities/delivery_accounting_models.dart';
import '../domain/services/accounting_calculator.dart';

/// خدمة توليد وطباعة كشوفات المحاسبة الأسبوعية (PDF & Printing Service)
class DeliveryAccountingPdfService {
  const DeliveryAccountingPdfService._();

  /// توليد كشف حساب PDF وإرساله لمنظومة الطباعة
  static Future<void> printWeeklyAccountingReport({
    required String title,
    required List<DeliveryOrderRecord> orders,
    required String tabName,
    String? govName,
    Map<String, String> restaurantNamesMap = const {},
    Map<String, String> storeNamesMap = const {},
  }) async {
    final fontData = await rootBundle.load('Cairo-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    pw.MemoryImage? logoImage;
    try {
      final ByteData imageByteData = await rootBundle.load('imges/dala_alqaim_logo.png');
      final Uint8List imageBytes = imageByteData.buffer.asUint8List();
      logoImage = pw.MemoryImage(imageBytes);
    } catch (_) {}

    final pdf = pw.Document();

    final int totalOrdersCount = orders.length;
    double totalAmount = 0.0;
    double totalDeliveryFees = 0.0;
    double totalAppCommission = 0.0;
    double netPayout = 0.0;

    for (final order in orders) {
      totalAmount += order.totalAmount;
      if (order.type == DeliveryOrderType.rideDelivery) {
        totalDeliveryFees += order.totalAmount;
      } else {
        totalDeliveryFees += order.deliveryFee;
      }
    }

    if (tabName == 'drivers') {
      totalAppCommission = totalOrdersCount * 500.0;
      netPayout = totalDeliveryFees - totalAppCommission;
    } else {
      totalAppCommission = totalAmount * 0.10;
      netPayout = totalAmount - totalAppCommission;
    }

    final typeLabel = tabName == 'drivers'
        ? 'كشف الكباتن'
        : (tabName == 'restaurants' ? 'كشف المطاعم' : 'كشف المتاجر');

    final sortedOrders = List<DeliveryOrderRecord>.from(orders);
    sortedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttf, italic: ttf, boldItalic: ttf),
        header: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'كشف حساب تفصيلي - المحاسبة الأسبوعية',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'نوع الحساب: $typeLabel | $title',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          'المحافظة: ${govName ?? ""} | تاريخ الإصدار: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                    if (logoImage != null)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: PdfColors.teal100, width: 1.5),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Image(logoImage, width: 28, height: 28),
                            pw.SizedBox(width: 6),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text(
                                  'تطبيقات مدار',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.orange900,
                                  ),
                                ),
                                pw.Text(
                                  'مدار',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.teal900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.teal50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.teal100),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'خلاصة التقرير المالي:',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal900,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(tabName == 'drivers' ? 'إجمالي أجور التوصيل:' : 'إجمالي المبيعات:', style: const pw.TextStyle(fontSize: 9)),
                                pw.Text(
                                  '${NumberFormat('#,###', 'ar').format(tabName == 'drivers' ? totalDeliveryFees : totalAmount)} د.ع',
                                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                                ),
                              ],
                            ),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('عمولة التطبيق المستقطعة:', style: const pw.TextStyle(fontSize: 9)),
                                pw.Text(
                                  '${NumberFormat('#,###', 'ar').format(totalAppCommission)} د.ع',
                                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
                                ),
                              ],
                            ),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('صافي المستحقات للتسوية:', style: const pw.TextStyle(fontSize: 9)),
                                pw.Text(
                                  '${NumberFormat('#,###', 'ar').format(netPayout)} د.ع',
                                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                                ),
                              ],
                            ),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('عدد العمليات:', style: const pw.TextStyle(fontSize: 9)),
                                pw.Text(
                                  '$totalOrdersCount عملية',
                                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'سجل العمليات المفصل:',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal900,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.TableHelper.fromTextArray(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
                    headerStyle: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal900,
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    cellAlignment: pw.Alignment.center,
                    headers: ['#', 'رقم العملية', 'الجهة', 'العميل', 'التاريخ والوقت', 'قيمة الطلب', 'أجر التوصيل'],
                    data: List<List<String>>.generate(sortedOrders.length, (idx) {
                      final order = sortedOrders[idx];
                      final id = order.id;
                      final total = order.totalAmount;
                      final date = order.createdAt;
                      final client = order.customerName ?? 'زبون';
                      final type = order.type;
                      final fee = order.deliveryFee;

                      String entityName = '';
                      if (type == DeliveryOrderType.foodOrder) {
                        entityName = restaurantNamesMap[order.restaurantId ?? ''] ?? 'مطعم';
                      } else if (type == DeliveryOrderType.storeOrder) {
                        entityName = storeNamesMap[order.storeId ?? ''] ?? 'متجر';
                      } else {
                        entityName = 'طلب دليفري';
                      }

                      final displayId = id.substring(0, id.length > 8 ? 8 : id.length).toUpperCase();

                      return [
                        '${idx + 1}',
                        displayId,
                        entityName,
                        client,
                        DateFormat('yyyy/MM/dd hh:mm a').format(date),
                        '${NumberFormat('#,###', 'ar').format(total)} د.ع',
                        '${NumberFormat('#,###', 'ar').format(fee)} د.ع',
                      ];
                    }),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'اعتماد وتدقيق قسم المحاسبة',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 25),
                        pw.Container(
                          width: 100,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              top: pw.BorderSide(color: PdfColors.grey400, width: 1),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'توقيع المدقق المالي',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              children: [
                pw.SizedBox(height: 6),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'تم إصدار الكشف من تطبيق مدار - نظام الإدارة المالي للعمليات',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'الصفحة ${context.pageNumber} من ${context.pagesCount}',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'weekly_accounting_statement_${tabName}_${title.replaceAll(" ", "_")}',
    );
  }
}
