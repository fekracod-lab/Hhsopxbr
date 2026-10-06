// شريط تحديات وحوافز اليوم للمندوب (Delivery Daily Quest Banner Widget)
// Presentation Layer — Pure UI Component

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/entities/delivery_dashboard_models.dart';

class DeliveryDailyQuestBanner extends StatelessWidget {
  final DeliveryQuestProgress questProgress;

  const DeliveryDailyQuestBanner({
    super.key,
    required this.questProgress,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'ar');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD54F)),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.military_tech_rounded, color: Color(0xFFF57F17), size: 22),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'مكافأة هدف اليوم',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF5D4037),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF57F17),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+ ${currencyFormat.format(questProgress.bonusAmount)} د.ع إضافية ',
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'وصلت ${questProgress.completedTrips} من أصل ${questProgress.targetTrips} طلبات اليوم',
                style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFF795548), fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              Text(
                '${questProgress.progressPercentage}%',
                style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFFF57F17), fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: questProgress.progress,
              minHeight: 8,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF57F17)),
            ),
          ),
        ],
      ),
    );
  }
}
