// قائمة وعرض المهام النشطة قيد التوصيل (Delivery Active Tasks View Widget)
// Presentation Layer — Pure UI Component

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/entities/delivery_dashboard_models.dart';

class DeliveryActiveTasksView extends StatelessWidget {
  final List<DeliveryOrderEntity> activeTasks;
  final ValueChanged<DeliveryOrderEntity> onOpenTaskDetails;

  static const Color _primary = Color(0xFF00BFA5);
  static const Color _accent = Color(0xFF0284C7);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);

  const DeliveryActiveTasksView({
    super.key,
    required this.activeTasks,
    required this.onOpenTaskDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (activeTasks.isEmpty) {
      return _buildEmptyState();
    }

    final currencyFormat = NumberFormat('#,###', 'ar');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: activeTasks.length,
      itemBuilder: (context, index) {
        final task = activeTasks[index];
        Color badgeColor = _primary;
        String badgeText = 'توصيل نشط';

        switch (task.source) {
          case DeliveryOrderSource.mersal:
            badgeColor = _accent;
            badgeText = 'مرسال';
            break;
          case DeliveryOrderSource.food:
            badgeColor = const Color(0xFFEA580C);
            badgeText = 'مطعم';
            break;
          case DeliveryOrderSource.store:
            badgeColor = const Color(0xFF7C3AED);
            badgeText = 'متجر';
            break;
          case DeliveryOrderSource.unknown:
            badgeColor = _primary;
            badgeText = 'طلب نشط';
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.ibmPlexSansArabic(color: badgeColor, fontWeight: FontWeight.w900, fontSize: 11.5),
                    ),
                  ),
                  Text(
                    '+ ${currencyFormat.format(task.deliveryFee)} د.ع',
                    style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFF2E7D32), fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF00C853), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'من: ${task.sourceName}',
                      style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFFE53935), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'إلى: ${task.dropoffName}',
                      style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onOpenTaskDetails(task),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: Text('متابعة وإكمال التوصيل', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, fontSize: 13.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: badgeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
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
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delivery_dining_rounded, size: 52, color: _primary),
            ),
            const SizedBox(height: 18),
            Text(
              'لا توجد مهام نشطة حالياً',
              style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'عند قبولك لأي طلب من الرادار، سيظهر هنا مع مسار التوجيه المباشر لتسليمه للزبون.',
              style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
