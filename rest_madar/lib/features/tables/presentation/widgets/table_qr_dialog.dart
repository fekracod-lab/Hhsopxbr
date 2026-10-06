import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/thermal_printer_service.dart';
import '../pages/table_digital_menu_page.dart';

/// نافذة توليد رمز QR ورابط المنيو الإلكتروني للطاولة وطباعة الستيكر الحراري
class TableQrDialog extends StatefulWidget {
  final String tableNumber;

  const TableQrDialog({super.key, required this.tableNumber});

  static Future<void> show(BuildContext context, String tableNumber) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TableQrDialog(tableNumber: tableNumber),
    );
  }

  @override
  State<TableQrDialog> createState() => _TableQrDialogState();
}

class _TableQrDialogState extends State<TableQrDialog> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _restaurantName = 'مطعم مدار';
  bool _isPrintingSticker = false;

  String get _tableMenuUrl =>
      'https://madar-iq.web.app/menu?restaurantId=$_uid&table=${widget.tableNumber}';

  String get _qrImageUrl =>
      'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(_tableMenuUrl)}';

  @override
  void initState() {
    super.initState();
    _fetchRestaurantName();
  }

  Future<void> _fetchRestaurantName() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _restaurantName = data?['restaurantName'] ?? data?['fullName'] ?? 'مطعم مدار';
        });
      }
    } catch (_) {}
  }

  Future<void> _printSticker() async {
    setState(() => _isPrintingSticker = true);
    HapticFeedback.mediumImpact();

    try {
      final success = await ThermalPrinterService.printTableQrSticker(
        tableNumber: widget.tableNumber,
        restaurantName: _restaurantName,
        qrUrl: _tableMenuUrl,
      );

      if (mounted) {
        setState(() => _isPrintingSticker = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'تم إرسال ستيكر الطاولة ${widget.tableNumber} إلى الطابعة الحرارية بنجاح! 🖨️'
                  : 'فشلت الطباعة - تأكد من اتصال الطابعة أو تعريفها في ويندوز',
            ),
            backgroundColor: success ? PosTheme.success : PosTheme.danger,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPrintingSticker = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الطباعة: $e'), backgroundColor: PosTheme.danger),
        );
      }
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _tableMenuUrl));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رابط منيو الطاولة إلى الحافظة! 📋'),
        backgroundColor: PosTheme.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TableDigitalMenuPage(
          restaurantId: _uid,
          tableNumber: widget.tableNumber,
          restaurantName: _restaurantName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: PosTheme.surfaceDark,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: PosTheme.borderDark, width: 1.2),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width.clamp(300.0, 500.0),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الرأس
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PosTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: PosTheme.accent, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'منيو طاولة رقم ${widget.tableNumber}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: PosTheme.textLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'امسح الرمز أو انسخ الرابط لطلب الطعام من الطاولة مباشرة',
                        style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: PosTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: PosTheme.borderDark, height: 1),
              const SizedBox(height: 20),

              // رمز QR في المنتصف
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.network(
                    _qrImageUrl,
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 180,
                      height: 180,
                      child: Center(
                        child: Icon(Icons.qr_code_rounded, size: 80, color: Colors.black54),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // رابط الطاولة المباشر
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: PosTheme.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PosTheme.borderDark),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, color: PosTheme.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _tableMenuUrl,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: PosTheme.textMuted,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: PosTheme.accent, size: 18),
                      tooltip: 'نسخ الرابط',
                      onPressed: _copyLink,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // الأزرار الرئيسية
              Row(
                children: [
                  // زر طباعة ملصق الطاولة بالحرارية
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isPrintingSticker ? null : _printSticker,
                      icon: _isPrintingSticker
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.print_rounded, size: 18),
                      label: Text(
                        _isPrintingSticker ? 'جاري الطباعة...' : 'طباعة ستيكر حراري 🖨️',
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PosTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // زر معاينة المنيو كما يراه الزبون
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openPreview,
                      icon: const Icon(Icons.phone_android_rounded, size: 18),
                      label: Text(
                        'معاينة المنيو 📱',
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PosTheme.accent,
                        side: const BorderSide(color: PosTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
