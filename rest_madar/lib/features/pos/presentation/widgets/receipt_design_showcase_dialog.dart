import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/thermal_printer_service.dart';

/// نافذة وشاشة المعاينة التفاعلية لتصاميم فواتير وتقارير مدار الحرارية
/// تعرض النماذج الـ 7 المعتمدة بتطابق تام مع الطابعات الحرارية
class ReceiptDesignShowcaseDialog extends StatefulWidget {
  const ReceiptDesignShowcaseDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const ReceiptDesignShowcaseDialog(),
    );
  }

  @override
  State<ReceiptDesignShowcaseDialog> createState() => _ReceiptDesignShowcaseDialogState();
}

class _ReceiptDesignShowcaseDialogState extends State<ReceiptDesignShowcaseDialog> {
  int _selectedFilter = 0; // 0: All 7, 1: Invoices, 2: Kitchen, 3: Reports
  int? _printingIndex;

  Future<void> _printTemplate(int index, String name) async {
    setState(() => _printingIndex = index);
    try {
      final success = await ThermalPrinterService.printSampleTemplate(index);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'تم إرسال ($name) إلى الطابعة الحرارية بنجاح 🖨️' : 'تعذرت الطباعة، يرجى فحص توصيل الطابعة.',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
            ),
            backgroundColor: success ? PosTheme.success : PosTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _printingIndex = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: const Color(0xFF1E2129),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF323846), width: 1.2),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: size.width.clamp(340.0, 1380.0),
          height: size.height.clamp(400.0, 880.0),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الرأس العلوي
              _buildHeader(context),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF323846), height: 1),
              const SizedBox(height: 16),

              // شريط التبويبات الفلاتر
              _buildFilterTabs(),
              const SizedBox(height: 18),

              // منطقة العرض التمريري للنماذج
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: _buildShowcaseContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PosTheme.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PosTheme.accent.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: PosTheme.accent, size: 26),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تصاميم فواتير وتقارير مدار الحرارية (Madar POS Thermal Layout)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'نماذج معتمدة ومطابقة تماماً لمقاسات الرول الحراري (80mm / 58mm) ونظام الكاشير',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white60,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
          tooltip: 'إغلاق',
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    final tabs = [
      {'title': 'عرض شامل (جميع النماذج الـ 7)', 'icon': Icons.grid_view_rounded},
      {'title': 'فواتير الزبائن (صالة / توصيل / سفري)', 'icon': Icons.point_of_sale_rounded},
      {'title': 'قسيمة المطبخ (KOT)', 'icon': Icons.restaurant_rounded},
      {'title': 'تقارير المبيعات والإحصائيات', 'icon': Icons.analytics_rounded},
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: tabs.asMap().entries.map((entry) {
        final idx = entry.key;
        final tab = entry.value;
        final isSelected = _selectedFilter == idx;

        return InkWell(
          onTap: () => setState(() => _selectedFilter = idx),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? PosTheme.accent : const Color(0xFF282D3A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? PosTheme.accent : const Color(0xFF3E4658),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tab['icon'] as IconData,
                  color: isSelected ? Colors.black : Colors.white70,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Text(
                  tab['title'] as String,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShowcaseContent() {
    switch (_selectedFilter) {
      case 1:
        // فواتير الزبائن فقط (صالة، توصيل، سفري)
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDineInReceiptCard(),
            const SizedBox(width: 18),
            _buildDeliveryReceiptCard(),
            const SizedBox(width: 18),
            _buildTakeawayReceiptCard(),
          ],
        );
      case 2:
        // قسيمة المطبخ
        return Center(
          child: SizedBox(
            width: 320,
            child: _buildKitchenTicketCard(),
          ),
        );
      case 3:
        // تقارير المبيعات
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDailySalesReportCard(),
            const SizedBox(width: 18),
            _buildPaymentMethodsReportCard(),
            const SizedBox(width: 18),
            _buildTopSellingReportCard(),
          ],
        );
      case 0:
      default:
        // العرض الشامل كالصورة: صفان (الفواتير والمطبخ بالأعلى، والتقارير بالأسفل)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // عنوان الصف الأول
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '• فواتير الطلبات وقسيمة المطبخ (Order Invoices & Kitchen Ticket):',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDineInReceiptCard(),
                  const SizedBox(width: 16),
                  _buildDeliveryReceiptCard(),
                  const SizedBox(width: 16),
                  _buildTakeawayReceiptCard(),
                  const SizedBox(width: 16),
                  _buildKitchenTicketCard(),
                ],
              ),
            ),

            const SizedBox(height: 32),
            // عنوان الصف الثاني
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '• تقارير المبيعات والإحصائيات اليومية (Daily Sales & Audit Reports):',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDailySalesReportCard(),
                  const SizedBox(width: 16),
                  _buildPaymentMethodsReportCard(),
                  const SizedBox(width: 16),
                  _buildTopSellingReportCard(),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
    }
  }

  // =========================================================================
  // 1. بطاقة فاتورة صالة (الشريط الأخضر)
  // =========================================================================
  Widget _buildDineInReceiptCard() {
    return _buildReceiptPaperWrapper(
      width: 295,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // شريط أخضر
          _buildReceiptBanner('فاتورة صالة 🛒', const Color(0xFF1B8755)),
          const SizedBox(height: 6),

          _buildReceiptChefHeader(),

          const Divider(height: 10, thickness: 0.8, color: Color(0xFFD0D7DE)),

          // بيانات الفاتورة
          _buildInfoRow('رقم الفاتورة :', '1001'),
          _buildInfoRow('التاريخ :', '2026-09-24 14:35'),
          _buildInfoRow('النوع :', 'صالة'),
          _buildInfoRow('الطاولة :', 'T-05'),
          _buildInfoRow('الموظف :', 'أحمد'),

          const SizedBox(height: 8),

          // جدول الأصناف
          _buildItemsTable(
            headers: ['#', 'الصنف', 'الكمية', 'السعر', 'المجموع'],
            rows: [
              ['1', 'مكس شاورما', '1', '6,000', '6,000'],
              ['2', 'بطاطا مقلية', '1', '3,000', '3,000'],
              ['3', 'مشروب بيبسي', '2', '1,000', '2,000'],
            ],
          ),

          const SizedBox(height: 8),

          // الحسابات
          _buildInfoRow('المجموع الفرعي :', '11,000'),
          _buildInfoRow('الخصم :', '0'),
          _buildInfoRow('ضريبة القيمة المضافة (%5) :', '550'),

          _buildDashedLine(),

          _buildGrandTotalRow('المجموع الكلي', '11,550'),

          _buildDashedLine(),

          _buildInfoRow('طريقة الدفع :', 'نقدي'),
          _buildInfoRow('المبلغ المدفوع :', '11,550'),
          _buildInfoRow('الباقي :', '0'),

          const SizedBox(height: 8),

          _buildBarcodeVisual('1001'),

          const SizedBox(height: 6),
          Text(
            'شكراً لزيارتكم',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          Text(
            'مدار - Madar',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 8.5, color: Colors.black54),
          ),

          const SizedBox(height: 4),
          _buildZigzagTear(),
        ],
      ),
      onPrint: () => _printTemplate(0, 'فاتورة صالة'),
      isPrinting: _printingIndex == 0,
      title: '1. فاتورة صالة (Dine-In)',
    );
  }

  // =========================================================================
  // 2. بطاقة فاتورة توصيل (الشريط الأحمر)
  // =========================================================================
  Widget _buildDeliveryReceiptCard() {
    return _buildReceiptPaperWrapper(
      width: 295,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // شريط أحمر
          _buildReceiptBanner('فاتورة توصيل 🛵', const Color(0xFFC62828)),
          const SizedBox(height: 6),

          _buildReceiptChefHeader(),

          const Divider(height: 10, thickness: 0.8, color: Color(0xFFD0D7DE)),

          _buildInfoRow('رقم الفاتورة :', '2001'),
          _buildInfoRow('التاريخ :', '2026-09-24 15:20'),
          _buildInfoRow('النوع :', 'توصيل'),
          _buildInfoRow('اسم العميل :', 'عمر مثنى'),
          _buildInfoRow('رقم الهاتف :', '07701234567'),
          _buildInfoRow('العنوان :', 'القائم - حي الحسين - قرب المدرسة'),
          _buildInfoRow('الموظف :', 'أحمد'),
          _buildInfoRow('وقت الطلب :', '15:20'),
          _buildInfoRow('وقت التوصيل :', '15:55'),

          const SizedBox(height: 8),

          _buildItemsTable(
            headers: ['#', 'الصنف', 'الكمية', 'السعر', 'المجموع'],
            rows: [
              ['1', 'وجبة بركر', '1', '8,000', '8,000'],
              ['2', 'بطاطا مقلية', '1', '3,000', '3,000'],
              ['3', 'مشروب بيبسي', '1', '1,000', '1,000'],
            ],
          ),

          const SizedBox(height: 8),

          _buildInfoRow('المجموع الفرعي :', '12,000'),
          _buildInfoRow('أجرة التوصيل :', '2,000'),
          _buildInfoRow('الخصم :', '1,000'),
          _buildInfoRow('ضريبة القيمة المضافة (%5) :', '650'),

          _buildDashedLine(),

          _buildGrandTotalRow('المجموع الكلي', '13,650'),

          _buildDashedLine(),

          _buildInfoRow('طريقة الدفع :', 'نقدي (عند الاستلام)'),
          _buildInfoRow('المبلغ المدفوع :', '13,650'),
          _buildInfoRow('الباقي :', '0'),

          const SizedBox(height: 8),

          _buildBarcodeVisual('2001'),

          const SizedBox(height: 6),
          Text(
            'شكراً لاختياركم مدار',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          Text(
            'مدار - Madar',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 8.5, color: Colors.black54),
          ),

          const SizedBox(height: 4),
          _buildZigzagTear(),
        ],
      ),
      onPrint: () => _printTemplate(1, 'فاتورة توصيل'),
      isPrinting: _printingIndex == 1,
      title: '2. فاتورة توصيل (Delivery)',
    );
  }

  // =========================================================================
  // 3. بطاقة فاتورة سفري (الشريط الأزرق)
  // =========================================================================
  Widget _buildTakeawayReceiptCard() {
    return _buildReceiptPaperWrapper(
      width: 295,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // شريط أزرق
          _buildReceiptBanner('فاتورة سفري 🛍️', const Color(0xFF1565C0)),
          const SizedBox(height: 6),

          _buildReceiptChefHeader(),

          const Divider(height: 10, thickness: 0.8, color: Color(0xFFD0D7DE)),

          _buildInfoRow('رقم الفاتورة :', '3001'),
          _buildInfoRow('التاريخ :', '2026-09-24 16:10'),
          _buildInfoRow('النوع :', 'سفري'),
          _buildInfoRow('اسم العميل :', 'زبون عادي'),
          _buildInfoRow('الموظف :', 'سيف'),

          const SizedBox(height: 8),

          _buildItemsTable(
            headers: ['#', 'الصنف', 'الكمية', 'السعر', 'المجموع'],
            rows: [
              ['1', 'دجاج مشوي', '1', '10,000', '10,000'],
              ['2', 'رز', '1', '3,000', '3,000'],
              ['3', 'خبز', '2', '500', '1,000'],
              ['4', 'صلصة', '1', '500', '500'],
            ],
          ),

          const SizedBox(height: 8),

          _buildInfoRow('المجموع الفرعي :', '14,500'),
          _buildInfoRow('الخصم :', '0'),
          _buildInfoRow('ضريبة القيمة المضافة (%5) :', '725'),

          _buildDashedLine(),

          _buildGrandTotalRow('المجموع الكلي', '15,225'),

          _buildDashedLine(),

          _buildInfoRow('طريقة الدفع :', 'نقدي'),
          _buildInfoRow('المبلغ المدفوع :', '15,500'),
          _buildInfoRow('الباقي :', '275'),

          const SizedBox(height: 8),

          _buildBarcodeVisual('3001'),

          const SizedBox(height: 6),
          Text(
            'نتمنى لكم وجبة شهية',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          Text(
            'مدار - Madar',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 8.5, color: Colors.black54),
          ),

          const SizedBox(height: 4),
          _buildZigzagTear(),
        ],
      ),
      onPrint: () => _printTemplate(2, 'فاتورة سفري'),
      isPrinting: _printingIndex == 2,
      title: '3. فاتورة سفري (Takeaway)',
    );
  }

  // =========================================================================
  // 4. بطاقة قسيمة طلب للمطبخ (الشريط البرتقالي)
  // =========================================================================
  Widget _buildKitchenTicketCard() {
    return _buildReceiptPaperWrapper(
      width: 295,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // شريط برتقالي
          _buildReceiptBanner('قسيمة طلب للمطبخ 🔔', const Color(0xFFF57C00)),
          const SizedBox(height: 6),

          _buildChefHatIcon(size: 38),
          Text('مدار', style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
          Text('نظام إدارة المطاعم', style: GoogleFonts.ibmPlexSansArabic(fontSize: 7.5, color: Colors.black54)),

          const SizedBox(height: 6),
          Text(
            'قسيمة طلب',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 4),

          // شارة الوجهة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.4),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '- صالة - T05 -',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),

          const SizedBox(height: 8),

          _buildInfoRow('رقم الطلب :', '1001'),
          _buildInfoRow('الوقت :', '14:35'),
          _buildInfoRow('الموظف :', 'أحمد'),
          _buildInfoRow('عدد الأصناف :', '3'),

          const SizedBox(height: 8),

          // جدول المطبخ بدون أسعار
          _buildItemsTable(
            headers: ['#', 'الصنف', 'الكمية', 'ملاحظات'],
            rows: [
              ['1', 'مكس شاورما', '1', 'بدون بصل'],
              ['2', 'بطاطا مقلية', '1', '-'],
              ['3', 'مشروب بيبسي', '2', '-'],
            ],
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: Text('ملاحظات إضافية :', style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text('-', style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, color: Colors.black54)),
          ),

          const SizedBox(height: 10),

          _buildBarcodeVisual('1001'),

          const SizedBox(height: 6),
          Text(
            'مطبخ مدار',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          Text(
            'تحضير الطلب بأسرع وقت',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 8.5, color: Colors.black54),
          ),

          const SizedBox(height: 4),
          _buildZigzagTear(),
        ],
      ),
      onPrint: () => _printTemplate(3, 'قسيمة مطبخ'),
      isPrinting: _printingIndex == 3,
      title: '4. قسيمة مطبخ (Kitchen Ticket)',
    );
  }

  // =========================================================================
  // 5. بطاقة تقرير مبيعات يومي (الشريط البنفسجي)
  // =========================================================================
  Widget _buildDailySalesReportCard() {
    return _buildReceiptPaperWrapper(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildReceiptBanner('تقرير مبيعات يومي 📊', const Color(0xFF6A1B9A)),
          const SizedBox(height: 6),

          Text(
            'تقرير المبيعات اليومي',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          Text(
            'التاريخ : 2026-09-24',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, color: Colors.black54),
          ),

          const SizedBox(height: 10),

          _buildBorderedGridTable(
            headers: ['النوع', 'عدد الفواتير', 'المجموع (د.ع)'],
            rows: [
              ['صالة', '25', '285,000'],
              ['توصيل', '18', '412,000'],
              ['سفري', '12', '165,000'],
            ],
            totalRow: ['الإجمالي', '55', '862,000'],
          ),

          const SizedBox(height: 14),
          Text(
            'مدار - Madar',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          _buildZigzagTear(),
        ],
      ),
      onPrint: () => _printTemplate(4, 'تقرير مبيعات يومي'),
      isPrinting: _printingIndex == 4,
      title: '5. تقرير مبيعات يومي (Daily Sales)',
    );
  }

  // =========================================================================
  // 6. بطاقة تقرير طرق الدفع (الشريط التركوازي)
  // =========================================================================
  Widget _buildPaymentMethodsReportCard() {
    return _buildReceiptPaperWrapper(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildReceiptBanner('تقرير طرق الدفع 💳', const Color(0xFF00897B)),
          const SizedBox(height: 6),

          Text(
            'تقرير طرق الدفع',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          Text(
            'التاريخ : 2026-09-24',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, color: Colors.black54),
          ),

          const SizedBox(height: 10),

          _buildBorderedGridTable(
            headers: ['طريقة الدفع', 'عدد العمليات', 'المجموع (د.ع)'],
            rows: [
              ['نقدي', '32', '480,000'],
              ['بطاقة', '15', '250,000'],
              ['دفع إلكتروني', '8', '132,000'],
            ],
            totalRow: ['الإجمالي', '55', '862,000'],
          ),

          const SizedBox(height: 14),
          Text(
            'مدار - Madar',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          _buildZigzagTear(),
        ],
      ),
      onPrint: () => _printTemplate(5, 'تقرير طرق الدفع'),
      isPrinting: _printingIndex == 5,
      title: '6. تقرير طرق الدفع (Payment Methods)',
    );
  }

  // =========================================================================
  // 7. بطاقة أكثر المنتجات مبيعاً (الشريط البرونزي)
  // =========================================================================
  Widget _buildTopSellingReportCard() {
    return _buildReceiptPaperWrapper(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildReceiptBanner('تقرير أكثر المنتجات مبيعاً 👑', const Color(0xFF6D4C41)),
          const SizedBox(height: 6),

          Text(
            'أكثر المنتجات مبيعاً',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          Text(
            'التاريخ : 2026-09-24',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, color: Colors.black54),
          ),

          const SizedBox(height: 10),

          _buildBorderedGridTable(
            headers: ['#', 'المنتج', 'الكمية', 'المجموع (د.ع)'],
            rows: [
              ['1', 'مكس شاورما', '45', '270,000'],
              ['2', 'بركر', '38', '304,000'],
              ['3', 'دجاج مشوي', '30', '300,000'],
              ['4', 'بطاطا مقلية', '28', '84,000'],
              ['5', 'مشروب بيبسي', '60', '60,000'],
            ],
          ),

          const SizedBox(height: 14),
          Text(
            'مدار - Madar',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          _buildZigzagTear(),
        ],
      ),
      onPrint: () => _printTemplate(6, 'أكثر المنتجات مبيعاً'),
      isPrinting: _printingIndex == 6,
      title: '7. أكثر المنتجات مبيعاً (Top Selling)',
    );
  }

  // =========================================================================
  // مكونات وعناصر التصميم المشتركة
  // =========================================================================

  Widget _buildReceiptPaperWrapper({
    required double width,
    required Widget child,
    required VoidCallback onPrint,
    required bool isPrinting,
    required String title,
  }) {
    return Column(
      children: [
        // عنوان البطاقة
        Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF282D3A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: const Color(0xFF3E4658)),
          ),
          child: Text(
            title,
            style: GoogleFonts.ibmPlexSansArabic(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // ورقة الفاتورة الحرارية
        Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),

        const SizedBox(height: 10),

        // زر الطباعة التجريبية
        SizedBox(
          width: width,
          child: ElevatedButton.icon(
            onPressed: isPrinting ? null : onPrint,
            icon: isPrinting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.print_rounded, size: 16),
            label: Text(
              isPrinting ? 'جارِ الإرسال...' : 'طباعة تجريبية 🖨️',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: PosTheme.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptBanner(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          title,
          style: GoogleFonts.ibmPlexSansArabic(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptChefHeader() {
    return Column(
      children: [
        _buildChefHatIcon(size: 34),
        Text('مدار', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
        Text('نظام إدارة المطاعم', style: GoogleFonts.ibmPlexSansArabic(fontSize: 7.5, color: Colors.black54)),
        const SizedBox(height: 2),
        Text('مطعم مدار', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
        Text('القائم - الأنبار', style: GoogleFonts.ibmPlexSansArabic(fontSize: 8, color: Colors.black87)),
        Text('0770 123 4567', style: GoogleFonts.ibmPlexSansArabic(fontSize: 8, color: Colors.black87)),
      ],
    );
  }

  Widget _buildChefHatIcon({double size = 32}) {
    return CustomPaint(
      size: Size(size, size * 0.72),
      painter: _ChefHatPainter(),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.ibmPlexSansArabic(fontSize: 8.5, color: Colors.black87)),
          Text(value, style: GoogleFonts.ibmPlexSansArabic(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildItemsTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return Table(
      border: TableBorder.all(color: const Color(0xFFD0D7DE), width: 0.6),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFE8ECEF)),
          children: headers.map((h) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
              child: Center(
                child: Text(
                  h,
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            );
          }).toList(),
        ),
        ...rows.map((row) {
          return TableRow(
            children: row.asMap().entries.map((e) {
              final idx = e.key;
              final val = e.value;
              final isItemName = idx == 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 3),
                child: Text(
                  val,
                  textAlign: isItemName ? TextAlign.right : TextAlign.center,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 8,
                    fontWeight: isItemName ? FontWeight.bold : FontWeight.normal,
                    color: Colors.black87,
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildBorderedGridTable({
    required List<String> headers,
    required List<List<String>> rows,
    List<String>? totalRow,
  }) {
    return Table(
      border: TableBorder.all(color: const Color(0xFFB0B8C4), width: 0.8),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFE8ECEF)),
          children: headers.map((h) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 2),
              child: Center(
                child: Text(
                  h,
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            );
          }).toList(),
        ),
        ...rows.map((row) {
          return TableRow(
            children: row.map((c) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                child: Center(
                  child: Text(
                    c,
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 8.5, color: Colors.black87),
                  ),
                ),
              );
            }).toList(),
          );
        }),
        if (totalRow != null)
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFE8ECEF)),
            children: totalRow.map((c) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
                child: Center(
                  child: Text(
                    c,
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildDashedLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = constraints.constrainWidth();
          const dashWidth = 4.0;
          const dashHeight = 1.0;
          final dashCount = (boxWidth / (2 * dashWidth)).floor();
          return Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return const SizedBox(
                width: dashWidth,
                height: dashHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFF888888)),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildGrandTotalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
          Text(value, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildBarcodeVisual(String code) {
    return Column(
      children: [
        Container(
          height: 32,
          width: 140,
          color: Colors.transparent,
          child: CustomPaint(
            painter: _BarcodePainter(),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          code,
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 8.5, letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildZigzagTear() {
    return SizedBox(
      height: 7,
      width: double.infinity,
      child: CustomPaint(
        painter: _ZigzagPainter(),
      ),
    );
  }
}

/// رسام الشيف هات لـ Flutter UI
class _ChefHatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final w = size.width;
    final h = size.height;

    // الحافة
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.76, w * 0.64, h * 0.24),
        const Radius.circular(2),
      ),
      paint,
    );

    // الطيات
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.30, h * 0.48), width: w * 0.36, height: h * 0.54),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.70, h * 0.48), width: w * 0.36, height: h * 0.54),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.34), width: w * 0.42, height: h * 0.60),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// رسام الباركود المحاكي للحراري
class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    const pattern = [2, 1, 3, 1, 1, 2, 4, 1, 2, 2, 1, 3, 2, 1, 1, 4, 2, 1, 3, 1, 2, 2, 1, 3, 1, 2, 4, 1, 2, 1];
    double x = 4;
    final w = size.width;
    final h = size.height;

    for (int i = 0; i < pattern.length; i++) {
      final barW = pattern[i].toDouble() * 1.3;
      if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(x, 0, barW, h), paint);
      }
      x += barW + 1.2;
      if (x > w - 4) break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// رسام قص الورق المشرشر
class _ZigzagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final path = Path();
    const step = 8.0;
    double x = 0;
    bool up = true;
    path.moveTo(0, size.height / 2);

    while (x < size.width) {
      x += step / 2;
      path.lineTo(x, up ? 0 : size.height);
      up = !up;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
