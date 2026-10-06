import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class RestaurantMetricsBar extends StatelessWidget {
  final int pendingCount;
  final int preparingCount;
  final int readyCount;
  final double todayRevenue;
  final double rating;

  const RestaurantMetricsBar({
    super.key,
    required this.pendingCount,
    required this.preparingCount,
    required this.readyCount,
    required this.todayRevenue,
    this.rating = 5.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormatter = NumberFormat('#,###', 'ar_IQ');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // 1. New Pending Orders
          _buildMetricCard(
            context: context,
            title: 'طلبيات جديدة',
            value: pendingCount.toString(),
            icon: Icons.notifications_active_rounded,
            color: const Color(0xFFFFB830), // Gold / Amber
            isDark: isDark,
            isPulsing: pendingCount > 0,
          ),
          const SizedBox(width: 10),

          // 2. Kitchen In Preparation
          _buildMetricCard(
            context: context,
            title: 'جاي نجهّز',
            value: preparingCount.toString(),
            icon: Icons.soup_kitchen_rounded,
            color: const Color(0xFFFF7043), // Coral / Orange
            isDark: isDark,
          ),
          const SizedBox(width: 10),

          // 3. Ready for Driver
          _buildMetricCard(
            context: context,
            title: 'مكمّل للكابتن',
            value: readyCount.toString(),
            icon: Icons.takeout_dining_rounded,
            color: app_colors.primaryColor, // Teal
            isDark: isDark,
          ),
          const SizedBox(width: 10),

          // 4. Today's Revenue
          _buildMetricCard(
            context: context,
            title: 'وارد اليوم',
            value: '${currencyFormatter.format(todayRevenue.toInt())} د.ع',
            icon: Icons.payments_rounded,
            color: const Color(0xFF00E676), // Vibrant Green
            isDark: isDark,
          ),
          const SizedBox(width: 10),

          // 5. Store Rating
          _buildMetricCard(
            context: context,
            title: 'تقييم الزبائن',
            value: rating.toStringAsFixed(1),
            icon: Icons.star_rounded,
            color: app_colors.goldAccent,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isPulsing = false,
  }) {
    final cardBg = isDark ? app_colors.darkCard : Colors.white;
    final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: isDark ? 0.75 : 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPulsing
              ? color.withValues(alpha: 0.6)
              : (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
          width: isPulsing ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isPulsing ? 0.18 : 0.04),
            blurRadius: isPulsing ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
