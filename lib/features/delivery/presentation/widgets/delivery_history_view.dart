// سجل الطلبات المسلمة والمكتملة للمندوب (Delivery History View Widget)
// Presentation Layer — Pure UI Component

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/entities/delivery_dashboard_models.dart';

class DeliveryHistoryView extends StatelessWidget {
  final List<DeliveryOrderEntity> historyOrders;
  final ValueChanged<DeliveryOrderEntity>? onOrderTap;

  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);
  static const Color _primary = Color(0xFF00BFA5);

  const DeliveryHistoryView({
    super.key,
    required this.historyOrders,
    this.onOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    if (historyOrders.isEmpty) {
      return _buildEmptyState();
    }

    final currencyFormat = NumberFormat('#,###', 'ar');
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: historyOrders.length,
      itemBuilder: (context, index) {
        final order = historyOrders[index];
        final completedDate = order.completedAt ?? order.createdAt;

        String sourceText = 'توصيل';
        Color sourceColor = _primary;

        switch (order.source) {
          case DeliveryOrderSource.mersal:
            sourceText = 'مرسال';
            sourceColor = const Color(0xFF0284C7);
            break;
          case DeliveryOrderSource.food:
            sourceText = 'مطعم';
            sourceColor = const Color(0xFFEA580C);
            break;
          case DeliveryOrderSource.store:
            sourceText = 'متجر';
            sourceColor = const Color(0xFF7C3AED);
            break;
          case DeliveryOrderSource.unknown:
            sourceText = 'طلب';
            sourceColor = _primary;
            break;
        }

        return InkWell(
          onTap: onOrderTap != null ? () => onOrderTap!(order) : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderLight, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sourceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00C853), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: sourceColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sourceText,
                              style: GoogleFonts.ibmPlexSansArabic(color: sourceColor, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          Text(
                            '+ ${currencyFormat.format(order.deliveryFee)} د.ع',
                            style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFF2E7D32), fontWeight: FontWeight.w900, fontSize: 13.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'إلى: ${order.dropoffName}',
                        style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (completedDate != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          dateFormat.format(completedDate),
                          style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 52, color: _textSub),
            ),
            const SizedBox(height: 18),
            Text(
              'لا يوجد سجل طلبات مكتملة بعد',
              style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'جميع طلباتك المسلمة بنجاح ستؤرشف هنا مع توثيق الأرباح والتواريخ بدقة.',
              style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
