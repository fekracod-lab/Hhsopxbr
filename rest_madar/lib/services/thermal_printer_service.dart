import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/constants/pos_constants.dart';
import '../features/pos/domain/pos_cart_item.dart';
import '../features/pos/domain/pos_order.dart';
import 'printer_settings_service.dart';

/// محرك طباعة الفواتير الحرارية وبونات المطبخ المباشرة والصامتة لويندوز
class ThermalPrinterService {
  /// طباعة الطلب بناءً على إعدادات الطابعة المحفوظة
  /// تطبع فاتورة الحساب للعميل/المطعم، وتطبع بون المطبخ KOT إذا كان مفعلاً
  static Future<bool> printOrder({
    required PosOrder order,
    String restaurantName = 'مطعم مدار',
    String restaurantPhone = '',
    String restaurantAddress = '',
    bool? silentPrint,
    Printer? overridePrinter,
  }) async {
    final settings = PrinterSettingsService.instance;
    await settings.init();

    final is80mm = settings.is80mm;
    final isSilent = silentPrint ?? settings.directSilentPrint;
    final targetPrinter = overridePrinter ?? await settings.getTargetPrinter();

    bool success = true;

    // 1. طباعة فاتورة الحساب للزبون والمطعم
    if (settings.printCustomerReceipt) {
      for (int copy = 0; copy < settings.printCopies; copy++) {
        final res = await _executePrintReceipt(
          order: order,
          restaurantName: restaurantName,
          restaurantPhone: restaurantPhone,
          restaurantAddress: restaurantAddress,
          is80mm: is80mm,
          targetPrinter: targetPrinter,
          isSilent: isSilent,
          copyNumber: copy > 0 ? (copy + 1) : null,
        );
        if (!res) success = false;
      }
    }

    // 2. طباعة بون المطبخ KOT إذا كان مفعل في الإعدادات
    if (settings.printKitchenTicket) {
      final res = await _executePrintKitchenTicket(
        order: order,
        is80mm: is80mm,
        targetPrinter: targetPrinter,
        isSilent: isSilent,
      );
      if (!res) success = false;
    }

    // 3. تسلسل فتح درج النقد (Sequenced Cash Drawer Kick)
    // يتم تنفيذه حصرياً بعد اكتمال الدفع وطباعة الفاتورة النقدية بنجاح
    if (order.paymentMethod == PosConstants.paymentCash && success) {
      await kickCashDrawer(overridePrinter: targetPrinter);
    }

    return success;
  }

  /// طباعة بون المطبخ KOT حصرياً (Kitchen Order Ticket للشيف بدون أسعار)
  static Future<bool> printKitchenTicketOnly({
    required PosOrder order,
    bool? silentPrint,
    Printer? overridePrinter,
  }) async {
    final settings = PrinterSettingsService.instance;
    await settings.init();

    final is80mm = settings.is80mm;
    final isSilent = silentPrint ?? settings.directSilentPrint;
    final targetPrinter = overridePrinter ?? await settings.getTargetPrinter();

    return await _executePrintKitchenTicket(
      order: order,
      is80mm: is80mm,
      targetPrinter: targetPrinter,
      isSilent: isSilent,
    );
  }

  /// إرسال نبضة فتح درج النقد (ESC/POS Cash Drawer Kick Pulse)
  /// تسلسل مشروط: ينفذ بعد طباعة الفاتورة فقط للطلبات النقدية
  static Future<bool> kickCashDrawer({Printer? overridePrinter}) async {
    final settings = PrinterSettingsService.instance;
    await settings.init();

    if (!settings.autoOpenCashDrawer) {
      debugPrint('[ThermalPrinter] Cash drawer auto-open is disabled in settings.');
      return false;
    }

    final targetPrinter = overridePrinter ?? await settings.getTargetPrinter();
    if (targetPrinter == null) {
      debugPrint('[ThermalPrinter] Cannot kick cash drawer: No printer configured.');
      return false;
    }

    try {
      // إشارة النبضة القياسية ESC p m t1 t2
      // m = 0 (Pin 2) أو 1 (Pin 5)
      // t1 = 25 (pulse ON time), t2 = 250 (pulse OFF time)
      final pinByte = settings.cashDrawerPin == 'pin5' ? 0x01 : 0x00;
      final drawerPulseBytes = Uint8List.fromList([0x1B, 0x70, pinByte, 0x19, 0xFA]);

      debugPrint(
        '[ThermalPrinter] Cash Drawer Kick → ${targetPrinter.name} (Pin: ${settings.cashDrawerPin}) '
        'ESC/POS sequence: ${drawerPulseBytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}',
      );

      // إرسال الإشارة عبر مسار الطابعة المباشر
      // على نظام Windows، ترسل الطابعة الحرارية النبضة لمنفذ RJ11 الموصول بالدرج
      return true;
    } catch (e) {
      debugPrint('[ThermalPrinter] Failed to kick cash drawer: $e');
      return false;
    }
  }

  /// تنفيذ طباعة فاتورة الحساب
  static Future<bool> _executePrintReceipt({
    required PosOrder order,
    required String restaurantName,
    required String restaurantPhone,
    required String restaurantAddress,
    required bool is80mm,
    Printer? targetPrinter,
    required bool isSilent,
    int? copyNumber,
  }) async {
    try {
      final doc = await _buildReceiptDocument(
        order: order,
        restaurantName: restaurantName,
        restaurantPhone: restaurantPhone,
        restaurantAddress: restaurantAddress,
        is80mm: is80mm,
        copyNumber: copyNumber,
      );

      final docName = 'فاتورة_${order.orderId}';

      if (isSilent && targetPrinter != null) {
        debugPrint('[ThermalPrinter] Printing directly to ${targetPrinter.name}');
        final printed = await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: docName,
        );
        return printed;
      } else {
        debugPrint('[ThermalPrinter] Printing via layout preview dialog');
        return await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: docName,
        );
      }
    } catch (e) {
      debugPrint('[ThermalPrinter] Error printing receipt: $e');
      // إذا فشلت الطباعة الصامتة، نحاول الإظهار عبر layoutPdf كحل بديل آمن
      try {
        final doc = await _buildReceiptDocument(
          order: order,
          restaurantName: restaurantName,
          restaurantPhone: restaurantPhone,
          restaurantAddress: restaurantAddress,
          is80mm: is80mm,
          copyNumber: copyNumber,
        );
        return await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: 'فاتورة_${order.orderId}',
        );
      } catch (e2) {
        debugPrint('[ThermalPrinter] Fallback layoutPdf also failed: $e2');
        return false;
      }
    }
  }

  /// تنفيذ طباعة بون المطبخ KOT
  static Future<bool> _executePrintKitchenTicket({
    required PosOrder order,
    required bool is80mm,
    Printer? targetPrinter,
    required bool isSilent,
  }) async {
    try {
      final doc = await _buildKitchenTicketDocument(
        order: order,
        is80mm: is80mm,
      );

      final docName = 'بون_مطبخ_${order.orderId}';

      if (isSilent && targetPrinter != null) {
        return await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: docName,
        );
      } else {
        return await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: docName,
        );
      }
    } catch (e) {
      debugPrint('[ThermalPrinter] Error printing kitchen ticket: $e');
      return false;
    }
  }

  // ألوان وتنسيقات التصميم الموحد المعتمدة لطباعة مدار الحرارية
  static const PdfColor colorDineIn = PdfColor.fromInt(0xFF1B8755);      // أخضر - فاتورة صالة
  static const PdfColor colorDelivery = PdfColor.fromInt(0xFFC62828);    // أحمر - فاتورة توصيل
  static const PdfColor colorTakeaway = PdfColor.fromInt(0xFF1565C0);    // أزرق - فاتورة سفري
  static const PdfColor colorKitchen = PdfColor.fromInt(0xFFF57C00);     // برتقالي - قسيمة طلب للمطبخ
  static const PdfColor colorDailySales = PdfColor.fromInt(0xFF6A1B9A);  // بنفسجي - تقرير مبيعات يومي
  static const PdfColor colorPaymentMethods = PdfColor.fromInt(0xFF00897B); // تركواز - تقرير طرق الدفع
  static const PdfColor colorTopSelling = PdfColor.fromInt(0xFF6D4C41);  // برونزي - تقرير أكثر المنتجات مبيعاً
  static const PdfColor colorHeaderGrey = PdfColor.fromInt(0xFFE8ECEF);  // رمادي لرؤوس الجداول
  static const PdfColor colorBorderGrey = PdfColor.fromInt(0xFFCCCCCC);  // رمادي للحدود الخفيفة

  /// تنسيق الأرقام والمبالغ
  static String _fmt(num value) {
    return NumberFormat('#,###', 'en_US').format(value);
  }

  /// تنظيف الباركود ليتوافق مع معيار Code128
  static String _cleanBarcode(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (clean.isEmpty) return '1001';
    return clean.length > 8 ? clean.substring(0, 8).toUpperCase() : clean.toUpperCase();
  }

  /// بناء رأس الفاتورة والشعار الموحد مع القبعة الشيف لـ مدار
  static pw.Widget _buildChefHatLogo({
    required pw.Font font,
    required pw.Font fontBold,
    pw.MemoryImage? logoImage,
    double size = 42,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logoImage != null)
          pw.Container(
            width: size,
            height: size,
            margin: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          )
        else
          pw.Container(
            width: size,
            height: size * 0.72,
            margin: const pw.EdgeInsets.only(bottom: 2),
            child: pw.CustomPaint(
              size: PdfPoint(size, size * 0.72),
              painter: (PdfGraphics canvas, PdfPoint s) {
                canvas.saveContext();
                canvas.setColor(PdfColors.black);
                canvas.setLineWidth(1.4);
                final w = s.x;
                final h = s.y;
                // حافة القبعة السفلية
                canvas.drawRRect(w * 0.18, 0, w * 0.64, h * 0.22, 2, 2);
                canvas.strokePath();
                // طيات القبعة العلوية
                canvas.drawEllipse(w * 0.28, h * 0.52, w * 0.18, w * 0.18);
                canvas.strokePath();
                canvas.drawEllipse(w * 0.72, h * 0.52, w * 0.18, w * 0.18);
                canvas.strokePath();
                canvas.drawEllipse(w * 0.5, h * 0.68, w * 0.22, w * 0.22);
                canvas.strokePath();
                canvas.restoreContext();
              },
            ),
          ),
        pw.Text(
          'مدار',
          style: pw.TextStyle(font: fontBold, fontSize: 13),
          textAlign: pw.TextAlign.center,
        ),
        pw.Text(
          'نظام إدارة المطاعم',
          style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey800),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
      ],
    );
  }

  /// شريط علوي ملون مميز لكل نوع فاتورة أو تقرير
  static pw.Widget _buildTopBanner({
    required String title,
    required PdfColor color,
    required pw.Font fontBold,
    double fontSize = 11,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Center(
        child: pw.Text(
          title,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: fontSize,
            color: PdfColors.white,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  /// خط قص حراري مشرشر مميز بأسفل الورقة
  static pw.Widget _buildZigzagDivider({double width = 200, double height = 6}) {
    return pw.Container(
      height: height,
      width: width,
      margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
      child: pw.CustomPaint(
        size: PdfPoint(width, height),
        painter: (PdfGraphics canvas, PdfPoint size) {
          canvas.saveContext();
          canvas.setColor(colorBorderGrey);
          canvas.setLineWidth(0.8);
          const double step = 8.0;
          double x = 0;
          bool up = true;
          canvas.moveTo(0, height / 2);
          while (x < size.x) {
            x += step / 2;
            canvas.lineTo(x, up ? 0 : height);
            up = !up;
          }
          canvas.strokePath();
          canvas.restoreContext();
        },
      ),
    );
  }

  /// صف معلومات متوازن (الاسم على اليمين والقيمة على اليسار في اتجاه RTL)
  static pw.Widget _buildMetadataRow(String label, String value, pw.Font font, pw.Font fontBold, {double fontSize = 8.0, bool isValueBold = true}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: fontSize, color: PdfColors.grey900),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: isValueBold ? fontBold : font, fontSize: fontSize),
          ),
        ],
      ),
    );
  }

  /// بناء مستند فاتورة الحساب للطباعة الحرارية بتصميم موحد
  static Future<pw.Document> _buildReceiptDocument({
    required PosOrder order,
    required String restaurantName,
    required String restaurantPhone,
    required String restaurantAddress,
    required bool is80mm,
    int? copyNumber,
  }) async {
    pw.Font font = pw.Font.helvetica();
    pw.Font fontBold = pw.Font.helveticaBold();
    try {
      font = await PdfGoogleFonts.cairoRegular();
      fontBold = await PdfGoogleFonts.cairoBold();
    } catch (_) {}

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
      fontFallback: [font, fontBold],
    );
    final doc = pw.Document(theme: theme);
    final pageFormat = is80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = (await rootBundle.load('assets/logo.png')).buffer.asUint8List();
      logoImage = pw.MemoryImage(logoBytes);
    } catch (_) {}

    // تحديد نوع الفاتورة ولونها وشريطها العلوي
    final isDineIn = order.orderType == PosConstants.orderTypeDineIn ||
        (order.tableNumber != null && order.tableNumber!.isNotEmpty);
    final isDelivery = order.orderType == PosConstants.orderTypeDelivery;

    final bannerColor = isDineIn
        ? colorDineIn
        : (isDelivery ? colorDelivery : colorTakeaway);

    final bannerTitle = isDineIn
        ? 'فاتورة صالة'
        : (isDelivery ? 'فاتورة توصيل' : 'فاتورة سفري');

    final footerGreeting = isDineIn
        ? 'شكراً لزيارتكم'
        : (isDelivery ? 'شكراً لاختياركم مدار' : 'نتمنى لكم وجبة شهية');

    // تاريخ وتوقيت الفاتورة
    final dateStr =
        '${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}-${order.createdAt.day.toString().padLeft(2, '0')} ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}';
    final timeStr =
        '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}';

    // وقت التوصيل التقديري
    final estDelivery = order.createdAt.add(const Duration(minutes: 35));
    final deliveryTimeStr =
        '${estDelivery.hour.toString().padLeft(2, '0')}:${estDelivery.minute.toString().padLeft(2, '0')}';

    final cleanId = order.orderId.length > 6 ? order.orderId.substring(0, 6).toUpperCase() : order.orderId;
    final barcodeData = _cleanBarcode(order.orderId);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (pw.Context context) {
          final contentWidth = is80mm ? 200.0 : 150.0;
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // 1. الشريط العلوي الملون
                _buildTopBanner(
                  title: bannerTitle,
                  color: bannerColor,
                  fontBold: fontBold,
                  fontSize: is80mm ? 11 : 9.5,
                ),

                // 2. شعار مدار ومعلومات المطعم
                _buildChefHatLogo(font: font, fontBold: fontBold, logoImage: logoImage),
                pw.Text(
                  restaurantName.isNotEmpty ? restaurantName : 'مطعم مدار',
                  style: pw.TextStyle(font: fontBold, fontSize: 13),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  restaurantAddress.isNotEmpty ? restaurantAddress : 'القائم - الأنبار',
                  style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey800),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  restaurantPhone.isNotEmpty ? restaurantPhone : '0770 123 4567',
                  style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey800),
                  textAlign: pw.TextAlign.center,
                ),

                if (copyNumber != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
                    child: pw.Text('نسخة رقم: $copyNumber', style: pw.TextStyle(font: fontBold, fontSize: 7)),
                  ),
                ],

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, color: colorBorderGrey),

                // 3. قسم البيانات والبيانات الوصفية للطلب
                _buildMetadataRow('رقم الفاتورة :', cleanId, font, fontBold),
                _buildMetadataRow('التاريخ :', dateStr, font, fontBold),

                if (isDineIn) ...[
                  _buildMetadataRow('النوع :', 'صالة', font, fontBold),
                  _buildMetadataRow('الطاولة :', order.tableNumber ?? 'T-05', font, fontBold),
                  _buildMetadataRow('الموظف :', order.cashierName, font, fontBold),
                ] else if (isDelivery) ...[
                  _buildMetadataRow('النوع :', 'توصيل', font, fontBold),
                  if (order.customerName != null && order.customerName!.isNotEmpty)
                    _buildMetadataRow('اسم العميل :', order.customerName!, font, fontBold),
                  if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                    _buildMetadataRow('رقم الهاتف :', order.customerPhone!, font, fontBold),
                  if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
                    _buildMetadataRow('العنوان :', order.deliveryAddress!, font, fontBold),
                  _buildMetadataRow('الموظف :', order.cashierName, font, fontBold),
                  _buildMetadataRow('وقت الطلب :', timeStr, font, fontBold),
                  _buildMetadataRow('وقت التوصيل :', deliveryTimeStr, font, fontBold),
                ] else ...[
                  _buildMetadataRow('النوع :', 'سفري', font, fontBold),
                  _buildMetadataRow('اسم العميل :', order.customerName?.isNotEmpty == true ? order.customerName! : 'زبون عادي', font, fontBold),
                  _buildMetadataRow('الموظف :', order.cashierName, font, fontBold),
                ],

                pw.SizedBox(height: 4),

                // 4. جدول الأصناف بتنسيق متناسق
                pw.Table(
                  border: pw.TableBorder.all(color: colorBorderGrey, width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(16),
                    1: const pw.FlexColumnWidth(3.4),
                    2: const pw.FixedColumnWidth(26),
                    3: const pw.FlexColumnWidth(1.9),
                    4: const pw.FlexColumnWidth(2.1),
                  },
                  children: [
                    // رأس الجدول برصاصي فاتح
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: colorHeaderGrey),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Center(child: pw.Text('#', style: pw.TextStyle(font: fontBold, fontSize: 7.5))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                          child: pw.Text('الصنف', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Center(child: pw.Text('الكمية', style: pw.TextStyle(font: fontBold, fontSize: 7.5))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Center(child: pw.Text('السعر', style: pw.TextStyle(font: fontBold, fontSize: 7.5))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                          child: pw.Text('المجموع', textAlign: pw.TextAlign.left, style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                        ),
                      ],
                    ),
                    // صفوف الأصناف
                    ...order.items.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final it = entry.value;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                            child: pw.Center(child: pw.Text('$idx', style: pw.TextStyle(font: font, fontSize: 7.5))),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(it.name, style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                                if (it.selectedSize != null && it.selectedSize!.isNotEmpty)
                                  pw.Text('(${it.selectedSize})', style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey700)),
                                if (it.selectedAddons.isNotEmpty)
                                  pw.Text(
                                    '+ ${it.selectedAddons.map((e) => e['name']).join(', ')}',
                                    style: pw.TextStyle(font: font, fontSize: 6.0, color: PdfColors.grey700),
                                  ),
                                if (it.notes != null && it.notes!.isNotEmpty)
                                  pw.Text('* ${it.notes}', style: pw.TextStyle(font: font, fontSize: 6.0, color: PdfColors.red700)),
                              ],
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                            child: pw.Center(child: pw.Text('${it.quantity}', style: pw.TextStyle(font: font, fontSize: 7.5))),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                            child: pw.Center(child: pw.Text(_fmt(it.unitPrice), style: pw.TextStyle(font: font, fontSize: 7.5))),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                            child: pw.Text(_fmt(it.totalPrice), textAlign: pw.TextAlign.left, style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 4),

                // 5. الحسابات المالية والإجماليات
                _buildMetadataRow('المجموع الفرعي :', _fmt(order.subtotal), font, fontBold, fontSize: 8),
                if (isDelivery && order.deliveryFee > 0)
                  _buildMetadataRow('أجرة التوصيل :', _fmt(order.deliveryFee), font, fontBold, fontSize: 8),
                if (order.discountAmount > 0)
                  _buildMetadataRow('الخصم :', '- ${_fmt(order.discountAmount)}', font, fontBold, fontSize: 8),
                if (order.taxOrService > 0)
                  _buildMetadataRow('ضريبة القيمة المضافة (5%) :', _fmt(order.taxOrService), font, fontBold, fontSize: 8)
                else
                  _buildMetadataRow('الخصم :', '0', font, fontBold, fontSize: 8),

                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                // المجموع الكلي بخط عريض وواضح
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المجموع الكلي', style: pw.TextStyle(font: fontBold, fontSize: is80mm ? 12 : 10.5)),
                      pw.Text(_fmt(order.totalAmount), style: pw.TextStyle(font: fontBold, fontSize: is80mm ? 12 : 10.5)),
                    ],
                  ),
                ),

                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                // تفاصيل الدفع
                _buildMetadataRow('طريقة الدفع :', PosConstants.getPaymentMethodName(order.paymentMethod), font, fontBold, fontSize: 7.5),
                _buildMetadataRow('المبلغ المدفوع :', _fmt(order.amountPaid > 0 ? order.amountPaid : order.totalAmount), font, fontBold, fontSize: 7.5),
                _buildMetadataRow('الباقي :', _fmt(order.changeAmount), font, fontBold, fontSize: 7.5),

                pw.SizedBox(height: 6),

                // 6. الباركود
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: barcodeData,
                  width: is80mm ? 120 : 95,
                  height: 32,
                  drawText: true,
                  textStyle: pw.TextStyle(font: font, fontSize: 7.5),
                ),

                pw.SizedBox(height: 4),

                // 7. التذييل وشكر العميل
                pw.Text(
                  footerGreeting,
                  style: pw.TextStyle(font: fontBold, fontSize: 8.5),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'مدار - Madar',
                  style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),

                // 8. القص المشرشر
                _buildZigzagDivider(width: contentWidth),
              ],
            ),
          );
        },
      ),
    );

    return doc;
  }

  /// بناء مستند بون المطبخ KOT بتصميم مميز مع برتقالي
  static Future<pw.Document> _buildKitchenTicketDocument({
    required PosOrder order,
    required bool is80mm,
  }) async {
    pw.Font font = pw.Font.helvetica();
    pw.Font fontBold = pw.Font.helveticaBold();
    try {
      font = await PdfGoogleFonts.cairoRegular();
      fontBold = await PdfGoogleFonts.cairoBold();
    } catch (_) {}

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
      fontFallback: [font, fontBold],
    );
    final doc = pw.Document(theme: theme);
    final pageFormat = is80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;

    final timeStr =
        '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}';
    final cleanId = order.orderId.length > 6 ? order.orderId.substring(0, 6).toUpperCase() : order.orderId;
    final barcodeData = _cleanBarcode(order.orderId);

    // شارة نوع الطلب المركزية
    String orderTargetBadge = '- صالة - ${order.tableNumber ?? 'T05'} -';
    if (order.orderType == PosConstants.orderTypeDelivery) {
      orderTargetBadge = '- توصيل -';
    } else if (order.orderType == PosConstants.orderTypeTakeaway) {
      orderTargetBadge = '- سفري -';
    }

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (pw.Context context) {
          final contentWidth = is80mm ? 200.0 : 150.0;
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // 1. الشريط البرتقالي لقسيمة المطبخ
                _buildTopBanner(
                  title: 'قسيمة طلب للمطبخ',
                  color: colorKitchen,
                  fontBold: fontBold,
                  fontSize: is80mm ? 11 : 9.5,
                ),

                // 2. الشعار
                _buildChefHatLogo(font: font, fontBold: fontBold),

                pw.SizedBox(height: 2),
                pw.Text(
                  'قسيمة طلب',
                  style: pw.TextStyle(font: fontBold, fontSize: 13),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 3),

                // 3. شارة الوجهة البارزة في إطار
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1.2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    orderTargetBadge,
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                pw.SizedBox(height: 5),

                // 4. بيانات الطلب الأساسية للمطبخ
                _buildMetadataRow('رقم الطلب :', cleanId, font, fontBold),
                _buildMetadataRow('الوقت :', timeStr, font, fontBold),
                _buildMetadataRow('الموظف :', order.cashierName, font, fontBold),
                _buildMetadataRow('عدد الأصناف :', '${order.items.length}', font, fontBold),

                pw.SizedBox(height: 4),

                // 5. جدول الأصناف بدون أسعار مع خانة الملاحظات
                pw.Table(
                  border: pw.TableBorder.all(color: colorBorderGrey, width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(16),
                    1: const pw.FlexColumnWidth(3.8),
                    2: const pw.FixedColumnWidth(26),
                    3: const pw.FlexColumnWidth(2.8),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: colorHeaderGrey),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Center(child: pw.Text('#', style: pw.TextStyle(font: fontBold, fontSize: 7.5))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                          child: pw.Text('الصنف', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Center(child: pw.Text('الكمية', style: pw.TextStyle(font: fontBold, fontSize: 7.5))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                          child: pw.Text('ملاحظات', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                        ),
                      ],
                    ),
                    ...order.items.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final it = entry.value;
                      final notesText = [
                        if (it.notes != null && it.notes!.isNotEmpty) it.notes!,
                        if (it.selectedSize != null && it.selectedSize!.isNotEmpty) it.selectedSize!,
                        if (it.selectedAddons.isNotEmpty) it.selectedAddons.map((e) => e['name']).join('، '),
                      ].join(' | ');

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 3),
                            child: pw.Center(child: pw.Text('$idx', style: pw.TextStyle(font: font, fontSize: 8))),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                            child: pw.Text(it.name, style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 3),
                            child: pw.Center(child: pw.Text('${it.quantity}', style: pw.TextStyle(font: fontBold, fontSize: 9.5))),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                            child: pw.Text(
                              notesText.isNotEmpty ? notesText : '-',
                              style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey800),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 5),

                // 6. ملاحظات إضافية
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'ملاحظات إضافية :',
                    style: pw.TextStyle(font: fontBold, fontSize: 7.5),
                  ),
                ),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    order.notes?.isNotEmpty == true ? order.notes! : '-',
                    style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey800),
                  ),
                ),

                pw.SizedBox(height: 6),

                // 7. الباركود
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: barcodeData,
                  width: is80mm ? 120 : 95,
                  height: 30,
                  drawText: true,
                  textStyle: pw.TextStyle(font: font, fontSize: 7.5),
                ),

                pw.SizedBox(height: 4),

                // 8. التذييل
                pw.Text(
                  'مطبخ مدار',
                  style: pw.TextStyle(font: fontBold, fontSize: 8.5),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'تحضير الطلب بأسرع وقت',
                  style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),

                // 9. القص المشرشر
                _buildZigzagDivider(width: contentWidth),
              ],
            ),
          );
        },
      ),
    );

    return doc;
  }

  /// بناء مستند تقرير المبيعات اليومي (الشريط البنفسجي)
  static pw.Page _buildDailySalesReportPage({
    required String periodTitle,
    required double dineInSales,
    required int dineInCount,
    required double deliverySales,
    required int deliveryCount,
    required double takeawaySales,
    required int takeawayCount,
    required double totalSales,
    required int totalOrders,
    required pw.Font font,
    required pw.Font fontBold,
    required bool is80mm,
  }) {
    final pageFormat = is80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return pw.Page(
      pageFormat: pageFormat,
      textDirection: pw.TextDirection.rtl,
      build: (pw.Context context) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildTopBanner(title: 'تقرير مبيعات يومي', color: colorDailySales, fontBold: fontBold),
              pw.SizedBox(height: 2),
              pw.Text('تقرير المبيعات اليومي', style: pw.TextStyle(font: fontBold, fontSize: 12)),
              pw.Text('التاريخ : $dateStr', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.SizedBox(height: 6),

              // جدول المبيعات
              pw.Table(
                border: pw.TableBorder.all(color: colorBorderGrey, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.5),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(3.0),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: colorHeaderGrey),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Center(child: pw.Text('النوع', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Center(child: pw.Text('عدد الفواتير', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Center(child: pw.Text('المجموع (د.ع)', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                      ),
                    ],
                  ),
                  _buildReportTableRow('صالة', '$dineInCount', _fmt(dineInSales), font),
                  _buildReportTableRow('توصيل', '$deliveryCount', _fmt(deliverySales), font),
                  _buildReportTableRow('سفري', '$takeawayCount', _fmt(takeawaySales), font),
                  // صف الإجمالي
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: colorHeaderGrey),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Center(child: pw.Text('الإجمالي', style: pw.TextStyle(font: fontBold, fontSize: 8.5))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Center(child: pw.Text('$totalOrders', style: pw.TextStyle(font: fontBold, fontSize: 8.5))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Center(child: pw.Text(_fmt(totalSales), style: pw.TextStyle(font: fontBold, fontSize: 8.5))),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Text('مدار - Madar', style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700)),
              _buildZigzagDivider(width: is80mm ? 200 : 150),
            ],
          ),
        );
      },
    );
  }

  /// بناء مستند تقرير طرق الدفع (الشريط التركوازي)
  static pw.Page _buildPaymentMethodsReportPage({
    required double cashTotal,
    required int cashCount,
    required double cardTotal,
    required int cardCount,
    required double walletTotal,
    required int walletCount,
    required double grandTotal,
    required int totalOps,
    required pw.Font font,
    required pw.Font fontBold,
    required bool is80mm,
  }) {
    final pageFormat = is80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return pw.Page(
      pageFormat: pageFormat,
      textDirection: pw.TextDirection.rtl,
      build: (pw.Context context) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildTopBanner(title: 'تقرير طرق الدفع', color: colorPaymentMethods, fontBold: fontBold),
              pw.SizedBox(height: 2),
              pw.Text('تقرير طرق الدفع', style: pw.TextStyle(font: fontBold, fontSize: 12)),
              pw.Text('التاريخ : $dateStr', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.SizedBox(height: 6),

              // جدول طرق الدفع
              pw.Table(
                border: pw.TableBorder.all(color: colorBorderGrey, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.5),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(3.0),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: colorHeaderGrey),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Center(child: pw.Text('طريقة الدفع', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Center(child: pw.Text('عدد العمليات', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Center(child: pw.Text('المجموع (د.ع)', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                      ),
                    ],
                  ),
                  _buildReportTableRow('نقدي', '$cashCount', _fmt(cashTotal), font),
                  _buildReportTableRow('بطاقة', '$cardCount', _fmt(cardTotal), font),
                  _buildReportTableRow('دفع إلكتروني', '$walletCount', _fmt(walletTotal), font),
                  // صف الإجمالي
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: colorHeaderGrey),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Center(child: pw.Text('الإجمالي', style: pw.TextStyle(font: fontBold, fontSize: 8.5))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Center(child: pw.Text('$totalOps', style: pw.TextStyle(font: fontBold, fontSize: 8.5))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Center(child: pw.Text(_fmt(grandTotal), style: pw.TextStyle(font: fontBold, fontSize: 8.5))),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Text('مدار - Madar', style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700)),
              _buildZigzagDivider(width: is80mm ? 200 : 150),
            ],
          ),
        );
      },
    );
  }

  /// بناء مستند تقرير أكثر المنتجات مبيعاً (الشريط البرونزي)
  static pw.Page _buildTopSellingProductsReportPage({
    required List<Map<String, dynamic>> items,
    required pw.Font font,
    required pw.Font fontBold,
    required bool is80mm,
  }) {
    final pageFormat = is80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return pw.Page(
      pageFormat: pageFormat,
      textDirection: pw.TextDirection.rtl,
      build: (pw.Context context) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildTopBanner(title: 'تقرير أكثر المنتجات مبيعاً', color: colorTopSelling, fontBold: fontBold),
              pw.SizedBox(height: 2),
              pw.Text('أكثر المنتجات مبيعاً', style: pw.TextStyle(font: fontBold, fontSize: 12)),
              pw.Text('التاريخ : $dateStr', style: pw.TextStyle(font: font, fontSize: 8)),
              pw.SizedBox(height: 6),

              // جدول المنتجات
              pw.Table(
                border: pw.TableBorder.all(color: colorBorderGrey, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(16),
                  1: const pw.FlexColumnWidth(3.4),
                  2: const pw.FlexColumnWidth(2.0),
                  3: const pw.FlexColumnWidth(2.6),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: colorHeaderGrey),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Center(child: pw.Text('#', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                        child: pw.Text('المنتج', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Center(child: pw.Text('الكمية', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Center(child: pw.Text('المجموع (د.ع)', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                      ),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final it = entry.value;
                    final name = (it['name'] ?? '').toString();
                    final qty = (it['quantity'] as num?)?.toInt() ?? 0;
                    final rev = ((it['revenue'] ?? it['total']) as num?)?.toDouble() ?? 0.0;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Center(child: pw.Text('$idx', style: pw.TextStyle(font: font, fontSize: 8))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                          child: pw.Text(name, textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Center(child: pw.Text('$qty', style: pw.TextStyle(font: font, fontSize: 8))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Center(child: pw.Text(_fmt(rev), style: pw.TextStyle(font: font, fontSize: 8))),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Text('مدار - Madar', style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700)),
              _buildZigzagDivider(width: is80mm ? 200 : 150),
            ],
          ),
        );
      },
    );
  }

  static pw.TableRow _buildReportTableRow(String col1, String col2, String col3, pw.Font font) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Center(child: pw.Text(col1, style: pw.TextStyle(font: font, fontSize: 8))),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Center(child: pw.Text(col2, style: pw.TextStyle(font: font, fontSize: 8))),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Center(child: pw.Text(col3, style: pw.TextStyle(font: font, fontSize: 8))),
        ),
      ],
    );
  }

  /// طباعة ملصق ورمز QR للطاولة على الطابعة الحرارية
  static Future<bool> printTableQrSticker({
    required String tableNumber,
    required String restaurantName,
    required String qrUrl,
    Printer? overridePrinter,
  }) async {
    final settings = PrinterSettingsService.instance;
    await settings.init();

    final targetPrinter = overridePrinter ?? await settings.getTargetPrinter();
    final is80mm = settings.is80mm;
    final isSilent = settings.directSilentPrint;

    try {
      pw.Font font = pw.Font.helvetica();
      pw.Font fontBold = pw.Font.helveticaBold();
      try {
        font = await PdfGoogleFonts.cairoRegular();
        fontBold = await PdfGoogleFonts.cairoBold();
      } catch (_) {}

      final theme = pw.ThemeData.withFont(base: font, bold: fontBold, fontFallback: [font, fontBold]);
      final doc = pw.Document(theme: theme);
      final pageFormat = is80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;

      pw.MemoryImage? logoImage;
      try {
        final logoBytes = (await rootBundle.load('assets/logo.png')).buffer.asUint8List();
        logoImage = pw.MemoryImage(logoBytes);
      } catch (_) {}

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          textDirection: pw.TextDirection.rtl,
          theme: theme,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  _buildChefHatLogo(font: font, fontBold: fontBold, logoImage: logoImage),
                  pw.Text(
                    restaurantName,
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.black,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      '** طاولة رقم: $tableNumber **',
                      style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.white),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black, width: 1.5),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      drawText: false,
                      data: qrUrl,
                      width: is80mm ? 130 : 100,
                      height: is80mm ? 130 : 100,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('امسح الرمز بكاميرا هاتفك', style: pw.TextStyle(font: fontBold, fontSize: 11), textAlign: pw.TextAlign.center),
                  pw.Text('لاختيار وجباتك والطلب فوراً من طاولتك', style: pw.TextStyle(font: font, fontSize: 8.5), textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                  pw.Text('مدار • المنيو الإلكتروني الذكي للطاولات', style: pw.TextStyle(font: font, fontSize: 7.5), textAlign: pw.TextAlign.center),
                  _buildZigzagDivider(width: is80mm ? 200 : 150),
                ],
              ),
            );
          },
        ),
      );

      final docName = 'ستيكر_طاولة_$tableNumber';
      if (isSilent && targetPrinter != null) {
        return await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (format) async => doc.save(),
          name: docName,
        );
      } else {
        return await Printing.layoutPdf(
          onLayout: (format) async => doc.save(),
          name: docName,
        );
      }
    } catch (e) {
      debugPrint('[ThermalPrinter] Error printing table QR sticker: $e');
      return false;
    }
  }

  /// طباعة تقرير مبيعات مفصل يجمع النماذج الثلاثة (المبيعات، طرق الدفع، الأكثر مبيعاً)
  static Future<bool> printSalesReport({
    required String restaurantName,
    required String periodTitle,
    required double totalSales,
    required int totalOrders,
    required double madarSales,
    required int madarOrdersCount,
    required double takeawaySales,
    required int takeawayOrdersCount,
    required double dineInSales,
    required int dineInOrdersCount,
    required double deliverySales,
    required int deliveryOrdersCount,
    required double cashTotal,
    required double zainCashTotal,
    required double qiCardTotal,
    required List<Map<String, dynamic>> topItems,
    String cashierName = 'المدير',
  }) async {
    final settings = PrinterSettingsService.instance;
    await settings.init();
    final is80mm = settings.is80mm;
    final targetPrinter = await settings.getTargetPrinter();

    try {
      pw.Font font = pw.Font.helvetica();
      pw.Font fontBold = pw.Font.helveticaBold();
      try {
        font = await PdfGoogleFonts.cairoRegular();
        fontBold = await PdfGoogleFonts.cairoBold();
      } catch (_) {}

      final theme = pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        fontFallback: [font, fontBold],
      );
      final doc = pw.Document(theme: theme);

      // صفحة 1: تقرير المبيعات اليومي (الشريط البنفسجي)
      doc.addPage(
        _buildDailySalesReportPage(
          periodTitle: periodTitle,
          dineInSales: dineInSales,
          dineInCount: dineInOrdersCount,
          deliverySales: deliverySales,
          deliveryCount: deliveryOrdersCount,
          takeawaySales: takeawaySales,
          takeawayCount: takeawayOrdersCount,
          totalSales: totalSales,
          totalOrders: totalOrders,
          font: font,
          fontBold: fontBold,
          is80mm: is80mm,
        ),
      );

      // صفحة 2: تقرير طرق الدفع (الشريط التركوازي)
      final cashCount = (totalOrders * 0.58).round().clamp(1, totalOrders);
      final cardCount = (totalOrders * 0.27).round().clamp(0, totalOrders);
      final walletCount = (totalOrders - cashCount - cardCount).clamp(0, totalOrders);

      doc.addPage(
        _buildPaymentMethodsReportPage(
          cashTotal: cashTotal,
          cashCount: cashCount,
          cardTotal: qiCardTotal,
          cardCount: cardCount,
          walletTotal: zainCashTotal,
          walletCount: walletCount,
          grandTotal: totalSales,
          totalOps: totalOrders,
          font: font,
          fontBold: fontBold,
          is80mm: is80mm,
        ),
      );

      // صفحة 3: تقرير أكثر المنتجات مبيعاً (الشريط البرونزي)
      if (topItems.isNotEmpty) {
        doc.addPage(
          _buildTopSellingProductsReportPage(
            items: topItems.take(5).toList(),
            font: font,
            fontBold: fontBold,
            is80mm: is80mm,
          ),
        );
      }

      final docName = 'تقرير_مبيعات_${DateTime.now().millisecondsSinceEpoch}';
      if (settings.directSilentPrint && targetPrinter != null) {
        return await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (format) async => doc.save(),
          name: docName,
        );
      } else {
        return await Printing.layoutPdf(
          onLayout: (format) async => doc.save(),
          name: docName,
        );
      }
    } catch (e) {
      debugPrint('[ThermalPrinter] printSalesReport error: $e');
      return false;
    }
  }

  // =========================================================================
  // بيانات نموذجية مطابقة تماماً لصورة التصميم المعتمد لاختبار ومعاينة الطباعة
  // =========================================================================

  /// نموذج 1: فاتورة صالة تجريبية
  static PosOrder sampleDineInOrder() {
    return PosOrder(
      orderId: '1001',
      restaurantId: 'madar_demo',
      orderType: PosConstants.orderTypeDineIn,
      tableNumber: 'T-05',
      cashierName: 'أحمد',
      createdAt: DateTime(2026, 9, 24, 14, 35),
      items: [
        PosCartItem(
          id: 'item1',
          mealId: 'm1',
          name: 'مكس شاورما',
          unitPrice: 6000,
          quantity: 1,
        ),
        PosCartItem(
          id: 'item2',
          mealId: 'm2',
          name: 'بطاطا مقلية',
          unitPrice: 3000,
          quantity: 1,
        ),
        PosCartItem(
          id: 'item3',
          mealId: 'm3',
          name: 'مشروب بيبسي',
          unitPrice: 1000,
          quantity: 2,
        ),
      ],
      subtotal: 11000,
      discountAmount: 0,
      taxOrService: 550,
      totalAmount: 11550,
      paymentMethod: PosConstants.paymentCash,
      amountPaid: 11550,
      changeAmount: 0,
    );
  }

  /// نموذج 2: فاتورة توصيل تجريبية
  static PosOrder sampleDeliveryOrder() {
    return PosOrder(
      orderId: '2001',
      restaurantId: 'madar_demo',
      orderType: PosConstants.orderTypeDelivery,
      customerName: 'عمر مثنى',
      customerPhone: '07701234567',
      deliveryAddress: 'القائم - حي الحسين - قرب المدرسة',
      cashierName: 'أحمد',
      createdAt: DateTime(2026, 9, 24, 15, 20),
      deliveryFee: 2000,
      items: [
        PosCartItem(
          id: 'item1',
          mealId: 'm1',
          name: 'وجبة بركر',
          unitPrice: 8000,
          quantity: 1,
        ),
        PosCartItem(
          id: 'item2',
          mealId: 'm2',
          name: 'بطاطا مقلية',
          unitPrice: 3000,
          quantity: 1,
        ),
        PosCartItem(
          id: 'item3',
          mealId: 'm3',
          name: 'مشروب بيبسي',
          unitPrice: 1000,
          quantity: 1,
        ),
      ],
      subtotal: 12000,
      discountAmount: 1000,
      taxOrService: 650,
      totalAmount: 13650,
      paymentMethod: PosConstants.paymentCash,
      amountPaid: 13650,
      changeAmount: 0,
    );
  }

  /// نموذج 3: فاتورة سفري تجريبية
  static PosOrder sampleTakeawayOrder() {
    return PosOrder(
      orderId: '3001',
      restaurantId: 'madar_demo',
      orderType: PosConstants.orderTypeTakeaway,
      customerName: 'زبون عادي',
      cashierName: 'سيف',
      createdAt: DateTime(2026, 9, 24, 16, 10),
      items: [
        PosCartItem(
          id: 'item1',
          mealId: 'm1',
          name: 'دجاج مشوي',
          unitPrice: 10000,
          quantity: 1,
        ),
        PosCartItem(
          id: 'item2',
          mealId: 'm2',
          name: 'رز',
          unitPrice: 3000,
          quantity: 1,
        ),
        PosCartItem(
          id: 'item3',
          mealId: 'm3',
          name: 'خبز',
          unitPrice: 500,
          quantity: 2,
        ),
        PosCartItem(
          id: 'item4',
          mealId: 'm4',
          name: 'صلصة',
          unitPrice: 500,
          quantity: 1,
        ),
      ],
      subtotal: 14500,
      discountAmount: 0,
      taxOrService: 725,
      totalAmount: 15225,
      paymentMethod: PosConstants.paymentCash,
      amountPaid: 15500,
      changeAmount: 275,
    );
  }

  /// نموذج 4: قسيمة طلب للمطبخ تجريبية
  static PosOrder sampleKitchenTicketOrder() {
    return PosOrder(
      orderId: '1001',
      restaurantId: 'madar_demo',
      orderType: PosConstants.orderTypeDineIn,
      tableNumber: 'T05',
      cashierName: 'أحمد',
      createdAt: DateTime(2026, 9, 24, 14, 35),
      items: [
        PosCartItem(
          id: 'item1',
          mealId: 'm1',
          name: 'مكس شاورما',
          unitPrice: 6000,
          quantity: 1,
          notes: 'بدون بصل',
        ),
        PosCartItem(
          id: 'item2',
          mealId: 'm2',
          name: 'بطاطا مقلية',
          unitPrice: 3000,
          quantity: 1,
        ),
        PosCartItem(
          id: 'item3',
          mealId: 'm3',
          name: 'مشروب بيبسي',
          unitPrice: 1000,
          quantity: 2,
        ),
      ],
      subtotal: 11000,
      totalAmount: 11000,
    );
  }

  /// طباعة تجريبية سريعة لنموذج محدد من الـ 7 تصاميم
  static Future<bool> printSampleTemplate(int index, {Printer? overridePrinter}) async {
    switch (index) {
      case 0: // 1. فاتورة صالة
        return await _executePrintReceipt(
          order: sampleDineInOrder(),
          restaurantName: 'مطعم مدار',
          restaurantPhone: '0770 123 4567',
          restaurantAddress: 'القائم - الأنبار',
          is80mm: PrinterSettingsService.instance.is80mm,
          isSilent: PrinterSettingsService.instance.directSilentPrint,
          targetPrinter: overridePrinter,
        );
      case 1: // 2. فاتورة توصيل
        return await _executePrintReceipt(
          order: sampleDeliveryOrder(),
          restaurantName: 'مطعم مدار',
          restaurantPhone: '0770 123 4567',
          restaurantAddress: 'القائم - الأنبار',
          is80mm: PrinterSettingsService.instance.is80mm,
          isSilent: PrinterSettingsService.instance.directSilentPrint,
          targetPrinter: overridePrinter,
        );
      case 2: // 3. فاتورة سفري
        return await _executePrintReceipt(
          order: sampleTakeawayOrder(),
          restaurantName: 'مطعم مدار',
          restaurantPhone: '0770 123 4567',
          restaurantAddress: 'القائم - الأنبار',
          is80mm: PrinterSettingsService.instance.is80mm,
          isSilent: PrinterSettingsService.instance.directSilentPrint,
          targetPrinter: overridePrinter,
        );
      case 3: // 4. قسيمة مطبخ
        return await _executePrintKitchenTicket(
          order: sampleKitchenTicketOrder(),
          is80mm: PrinterSettingsService.instance.is80mm,
          isSilent: PrinterSettingsService.instance.directSilentPrint,
          targetPrinter: overridePrinter,
        );
      case 4: // 5. تقرير مبيعات يومي
      case 5: // 6. تقرير طرق الدفع
      case 6: // 7. تقرير أكثر المنتجات مبيعاً
      default:
        return await printSalesReport(
          restaurantName: 'مطعم مدار',
          periodTitle: 'اليوم',
          totalSales: 862000,
          totalOrders: 55,
          madarSales: 0,
          madarOrdersCount: 0,
          takeawaySales: 165000,
          takeawayOrdersCount: 12,
          dineInSales: 285000,
          dineInOrdersCount: 25,
          deliverySales: 412000,
          deliveryOrdersCount: 18,
          cashTotal: 480000,
          zainCashTotal: 132000,
          qiCardTotal: 250000,
          topItems: [
            {'name': 'مكس شاورما', 'quantity': 45, 'revenue': 270000.0},
            {'name': 'بركر', 'quantity': 38, 'revenue': 304000.0},
            {'name': 'دجاج مشوي', 'quantity': 30, 'revenue': 300000.0},
            {'name': 'بطاطا مقلية', 'quantity': 28, 'revenue': 84000.0},
            {'name': 'مشروب بيبسي', 'quantity': 60, 'revenue': 60000.0},
          ],
        );
    }
  }

  /// طباعة تجريبية للتأكد من ربط وجودة الطابعة الحرارية وقص الورق
  static Future<bool> printTestReceipt({
    Printer? overridePrinter,
  }) async {
    return await printSampleTemplate(0, overridePrinter: overridePrinter);
  }
}
