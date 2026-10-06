// بطاقة طلب التوصيل الموحدة لجميع المصادر (Delivery Unified Order Card Widget)
// Presentation Layer — Pure UI Component

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/entities/delivery_dashboard_models.dart';

class DeliveryUnifiedOrderCard extends StatelessWidget {
  final DeliveryOrderEntity order;
  final bool isAccepting;
  final VoidCallback onAccept;
  final VoidCallback onDetails;

  static const Color _primary = Color(0xFF00BFA5);
  static const Color _accent = Color(0xFF0284C7);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);

  const DeliveryUnifiedOrderCard({
    super.key,
    required this.order,
    this.isAccepting = false,
    required this.onAccept,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'ar');

    String title = 'طلب توصيل';
    String badgeText = 'توصيل';
    Color badgeColor = _primary;
    IconData icon = Icons.delivery_dining_rounded;

    switch (order.source) {
      case DeliveryOrderSource.mersal:
        title = 'طلب مرسال وشراء';
        badgeText = 'مرسال';
        badgeColor = _accent;
        icon = Icons.local_mall_rounded;
        break;
      case DeliveryOrderSource.food:
        title = 'وجبة مطعم جاهزة';
        badgeText = 'مطعم';
        badgeColor = const Color(0xFFEA580C);
        icon = Icons.restaurant_rounded;
        break;
      case DeliveryOrderSource.store:
        title = 'مسواك متجر وسوق';
        badgeText = 'متجر';
        badgeColor = const Color(0xFF7C3AED);
        icon = Icons.storefront_rounded;
        break;
      case DeliveryOrderSource.unknown:
        title = 'طلب توصيل فوري';
        badgeText = 'توصيل';
        badgeColor = _primary;
        icon = Icons.delivery_dining_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderLight, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس البطاقة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: badgeColor, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.ibmPlexSansArabic(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (order.isCustomPrice)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_note_rounded, color: _accent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'أنت تحدد السعر',
                        style: GoogleFonts.ibmPlexSansArabic(color: _accent, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Text(
                    '+ ${currencyFormat.format(order.deliveryFee)} د.ع',
                    style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFF2E7D32), fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // مسار الاستلام والتسليم
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF00C853), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'من: ${order.sourceName}',
                        style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      height: 14,
                      width: 2,
                      color: _borderLight,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFFE53935), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'إلى: ${order.dropoffName}',
                        style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // أزرار التحكم
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: isAccepting ? null : onAccept,
                  icon: isAccepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    isAccepting ? 'جاري الاستلام...' : 'قبول التوصيل',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.map_rounded, size: 17),
                  label: Text('التفاصيل', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textMain,
                    side: const BorderSide(color: _borderLight, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
