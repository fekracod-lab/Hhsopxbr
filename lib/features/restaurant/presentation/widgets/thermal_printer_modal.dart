import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class ThermalPrinterModal extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String orderId;

  const ThermalPrinterModal({
    super.key,
    required this.orderData,
    required this.orderId,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> orderData,
    required String orderId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ThermalPrinterModal(orderData: orderData, orderId: orderId),
    );
  }

  @override
  State<ThermalPrinterModal> createState() => _ThermalPrinterModalState();
}

class _ThermalPrinterModalState extends State<ThermalPrinterModal> {
  bool _isSearching = true;
  String _docType = 'وصل الزبون';
  String _printerType = 'Bluetooth';
  static const String _selectedPrinter = 'طابعة المطبخ Sunmi-T2 (افتراضي)';

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? app_colors.darkCard : Colors.white;
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;
    final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;

    final itemsList = (widget.orderData['items'] as List<dynamic>?) ?? [];
    final totalPrice = widget.orderData['total'] ??
        widget.orderData['totalPrice'] ??
        widget.orderData['grandTotal'] ??
        0;
    final buyerName = widget.orderData['customerName'] ??
        widget.orderData['buyerName'] ??
        'زبون مدار المميز';
    final buyerPhone = widget.orderData['customerPhone'] ??
        widget.orderData['buyerPhone'] ??
        '';
    final deliveryAddress = widget.orderData['deliveryAddress'] ??
        widget.orderData['address'] ??
        'استلام من المطعم سفري';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.primaryColor).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: app_colors.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.print_rounded,
                  color: app_colors.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طابعة المطبخ والوصولات',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'اطبع وصل المطبخ أو وصل الزبون والكابتن فوراً',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // Configuration Controls
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        dropdownColor: cardBg,
                        initialValue: _printerType,
                        decoration: InputDecoration(
                          labelText: 'نوع الاتصال',
                          labelStyle: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            color: textSecondary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: textSecondary.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: textSecondary.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        items: ['Bluetooth', 'Wi-Fi / LAN', 'Sunmi Direct']
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 12,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _printerType = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        dropdownColor: cardBg,
                        initialValue: _docType,
                        decoration: InputDecoration(
                          labelText: 'نوع الوصل',
                          labelStyle: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            color: textSecondary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: textSecondary.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: textSecondary.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        items: ['وصل الزبون', 'تذكرة المطبخ', 'وصل الكابتن / الدلفري']
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 12,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _docType = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Printer Status Card
                if (_isSearching)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: app_colors.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: app_colors.primaryColor,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'جاري البحث عن طابعات بلوتوث وشبكة نشطة قريبة...',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11.5,
                              color: app_colors.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'متصل بالطابعة: $_selectedPrinter',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11.5,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Receipt Simulation View
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F2B2E) : const Color(0xFFF8FBFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          '--- معـاينة الإيـصال الحراري ---',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'رقم الطلب: #${widget.orderId.length > 6 ? widget.orderId.substring(widget.orderId.length - 6).toUpperCase() : widget.orderId}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            _docType,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: app_colors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Text(
                        'الزبون: $buyerName',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      if (buyerPhone.toString().isNotEmpty)
                        Text(
                          'الهاتف: $buyerPhone',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            color: textSecondary,
                          ),
                        ),
                      Text(
                        'العنوان: $deliveryAddress',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          color: textSecondary,
                        ),
                      ),
                      const Divider(height: 16),
                      Text(
                        'الأطباق والوجبات:',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...itemsList.map((item) {
                        final iMap = item is Map<String, dynamic>
                            ? item
                            : <String, dynamic>{};
                        final name = iMap['title'] ??
                            iMap['name'] ??
                            iMap['mealName'] ??
                            'وجبة';
                        final qty = iMap['quantity'] ?? iMap['qty'] ?? 1;
                        final price = iMap['price'] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text(
                                '${qty}x ',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: app_colors.primaryColor,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  name.toString(),
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 12,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '$price د.ع',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المجموع الإجمالي:',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            '$totalPrice د.ع',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: app_colors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Print Action Button
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'دزينا أمر الطباعة للطابعة $_selectedPrinter بنجاح',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: app_colors.primaryColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
            },
            icon: const Icon(Icons.print_rounded, color: Colors.white, size: 20),
            label: Text(
              'طباعة الوصل هسة',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: app_colors.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
