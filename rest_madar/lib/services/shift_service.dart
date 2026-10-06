import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants/pos_constants.dart';

/// خدمة إدارة الوردية وصندوق الكاشير وإصدار تقرير Z-Report
class ShiftService extends ChangeNotifier {
  bool _isShiftOpen = false;
  String? _currentShiftId;
  DateTime? _shiftStartTime;
  double _openingCash = 0.0;
  String _cashierName = 'كاشير رئيسي';

  ShiftService() {
    initActiveShift();
  }

  bool get isShiftOpen => _isShiftOpen;
  String? get currentShiftId => _currentShiftId;
  DateTime? get shiftStartTime => _shiftStartTime;
  double get openingCash => _openingCash;
  String get cashierName => _cashierName;

  /// فحص واستعادة الوردية النشطة من السحابة في حال إعادة تشغيل التطبيق
  Future<void> initActiveShift() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(uid)
          .collection('shifts')
          .where('status', isEqualTo: 'open')
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final data = doc.data();
        _isShiftOpen = true;
        _currentShiftId = doc.id;
        final openedAt = data['openedAt'];
        if (openedAt is Timestamp) {
          _shiftStartTime = openedAt.toDate();
        }
        _openingCash = (data['openingCash'] as num?)?.toDouble() ?? 0.0;
        _cashierName = data['cashierName']?.toString() ?? 'كاشير رئيسي';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ShiftService] initActiveShift error: $e');
    }
  }

  /// بدء وردية جديدة
  Future<void> openShift({required double initialCash, required String cashier}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final shiftRef = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(uid)
        .collection('shifts')
        .doc();

    final now = DateTime.now();
    await shiftRef.set({
      'shiftId': shiftRef.id,
      'restaurantId': uid,
      'cashierName': cashier,
      'openingCash': initialCash,
      'openedAt': Timestamp.fromDate(now),
      'status': 'open',
    });

    _isShiftOpen = true;
    _currentShiftId = shiftRef.id;
    _shiftStartTime = now;
    _openingCash = initialCash;
    _cashierName = cashier;
    notifyListeners();
  }

  /// إغلاق الوردية وإصدار تقرير Z-Report
  Future<Map<String, dynamic>> closeShift({
    required double actualCashInDrawer,
    String? notes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final now = DateTime.now();

    // جلب طلبيات الكاشير خلال الوردية
    double totalCashSales = 0.0;
    double totalCardSales = 0.0;
    int ordersCount = 0;

    if (_shiftStartTime != null) {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_shiftStartTime!))
          .get();

      for (var doc in snap.docs) {
        final data = doc.data();
        final method = data['paymentMethod'] ?? 'cash';
        final total = (data['total'] ?? data['totalPrice'] ?? 0).toDouble();
        ordersCount++;

        if (method == 'cash') {
          totalCashSales += total;
        } else {
          totalCardSales += total;
        }
      }
    }

    // جلب مصروفات الوردية (مرتبطة بمعرف الوردية أو فترتها الزمنية)
    double totalShiftExpenses = 0.0;
    double totalCashExpenses = 0.0;
    int expensesCount = 0;

    try {
      QuerySnapshot<Map<String, dynamic>> expSnap;

      // أولاً: البحث بمعرف الوردية المباشر
      if (_currentShiftId != null && _currentShiftId!.isNotEmpty) {
        expSnap = await FirebaseFirestore.instance
            .collection('merchant_expenses')
            .doc(uid)
            .collection('expenses')
            .where('shiftId', isEqualTo: _currentShiftId)
            .get();
      } else if (_shiftStartTime != null) {
        // ثانياً: البحث بالفترة الزمنية كبديل
        expSnap = await FirebaseFirestore.instance
            .collection('merchant_expenses')
            .doc(uid)
            .collection('expenses')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_shiftStartTime!))
            .get();
      } else {
        expSnap = await FirebaseFirestore.instance
            .collection('merchant_expenses')
            .doc(uid)
            .collection('expenses')
            .limit(0)
            .get();
      }

      for (var doc in expSnap.docs) {
        final data = doc.data();
        final amt = (data['amount'] ?? 0).toDouble();
        final method = (data['paymentMethod'] ?? 'cash').toString();
        totalShiftExpenses += amt;
        expensesCount++;
        if (method == 'cash') {
          totalCashExpenses += amt;
        }
      }
    } catch (e) {
      debugPrint('[ShiftService] Error fetching shift expenses: $e');
    }

    // حساب النقد المتوقع = الرصيد الافتتاحي + مبيعات نقدية - مصروفات نقدية
    final expectedCash = _openingCash + totalCashSales - totalCashExpenses;
    final cashDifference = actualCashInDrawer - expectedCash; // سالب: عجز، موجب: فائض

    final result = {
      'shiftId': _currentShiftId,
      'cashierName': _cashierName,
      'openedAt': _shiftStartTime,
      'closedAt': now,
      'openingCash': _openingCash,
      'totalCashSales': totalCashSales,
      'totalCardSales': totalCardSales,
      'totalSales': totalCashSales + totalCardSales,
      'ordersCount': ordersCount,
      'totalShiftExpenses': totalShiftExpenses,
      'totalCashExpenses': totalCashExpenses,
      'expensesCount': expensesCount,
      'netProfit': (totalCashSales + totalCardSales) - totalShiftExpenses,
      'actualCash': actualCashInDrawer,
      'expectedCash': expectedCash,
      'difference': cashDifference,
      'notes': notes ?? '',
    };

    if (_currentShiftId != null) {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(uid)
          .collection('shifts')
          .doc(_currentShiftId)
          .update({
        'status': 'closed',
        'closedAt': Timestamp.fromDate(now),
        'totalCashSales': totalCashSales,
        'totalCardSales': totalCardSales,
        'totalSales': totalCashSales + totalCardSales,
        'ordersCount': ordersCount,
        'totalShiftExpenses': totalShiftExpenses,
        'totalCashExpenses': totalCashExpenses,
        'expensesCount': expensesCount,
        'netProfit': (totalCashSales + totalCardSales) - totalShiftExpenses,
        'actualCash': actualCashInDrawer,
        'expectedCash': expectedCash,
        'difference': cashDifference,
        'notes': notes ?? '',
      });
    }

    _isShiftOpen = false;
    _currentShiftId = null;
    notifyListeners();

    return result;
  }


  /// طباعة تقرير Z-Report حرارياً
  static Future<void> printZReport(Map<String, dynamic> reportData, String restaurantName) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final theme = pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
      italic: font,
      boldItalic: fontBold,
      fontFallback: [font, fontBold],
    );
    final doc = pw.Document(theme: theme);

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = (await rootBundle.load('assets/logo.png')).buffer.asUint8List();
      logoImage = pw.MemoryImage(logoBytes);
    } catch (_) {}

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (pw.Context context) {
          final diff = (reportData['difference'] ?? 0.0) as double;

          return pw.Container(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null) ...[
                  pw.Container(
                    width: 38,
                    height: 38,
                    margin: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                ],
                pw.Text(restaurantName, style: pw.TextStyle(font: fontBold, fontSize: 14)),
                pw.Text('--- تقرير الوردية اليومي (Z-Report) ---', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                pw.Divider(thickness: 1),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الكاشير: ${reportData['cashierName']}', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text('الطلبات: ${reportData['ordersCount']}', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                  ],
                ),
                pw.Divider(thickness: 0.5),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('العهدة الافتتاحية:', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text(PosConstants.formatMoney(reportData['openingCash']), style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('مبيعات النقد (كاش):', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text(PosConstants.formatMoney(reportData['totalCashSales']), style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('مبيعات البطاقة / شبكة:', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text(PosConstants.formatMoney(reportData['totalCardSales']), style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('إجمالي المبيعات:', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                    pw.Text(PosConstants.formatMoney(reportData['totalSales']), style: pw.TextStyle(font: fontBold, fontSize: 11)),
                  ],
                ),

                // قسم المصروفات
                if ((reportData['expensesCount'] ?? 0) > 0) ...[
                  pw.Divider(thickness: 0.5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المصروفات (${reportData['expensesCount']} سند):', style: pw.TextStyle(font: font, fontSize: 9)),
                      pw.Text('- ${PosConstants.formatMoney(reportData['totalShiftExpenses'])}', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.red)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('صافي الربح:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.Text(PosConstants.formatMoney(reportData['netProfit'] ?? 0), style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    ],
                  ),
                ],

                pw.Divider(thickness: 1),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('النقد المفترض بالصندوق:', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text(PosConstants.formatMoney(reportData['expectedCash']), style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('النقد الفعلي بالجرد:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    pw.Text(PosConstants.formatMoney(reportData['actualCash']), style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  color: diff == 0 ? PdfColors.grey200 : (diff < 0 ? PdfColors.red100 : PdfColors.green100),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(diff == 0 ? 'المطابقة: دقيقة تماماً' : (diff < 0 ? 'العجز في الصندوق:' : 'الفائض في الصندوق:'),
                          style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      pw.Text(PosConstants.formatMoney(diff.abs()),
                          style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('تاريخ الإغلاق: ${DateTime.now().toString().substring(0, 16)}',
                    style: pw.TextStyle(font: font, fontSize: 8)),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
                pw.Text('منظومة مدار لإدارة المطاعم والكاشير • Madar POS',
                    style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'تقرير_الوردية_${reportData['shiftId']}',
    );
  }
}
