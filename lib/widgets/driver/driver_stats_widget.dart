import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';

class DriverStatsWidget extends StatelessWidget {
  final double todayEarnings;
  final int todayTrips;
  final bool isDark;

  const DriverStatsWidget({
    super.key,
    required this.todayEarnings,
    required this.todayTrips,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF113033) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.account_balance_wallet_rounded,
              value: NumberFormat('#,###').format(todayEarnings),
              unit: 'د.ع',
              label: 'أرباح اليوم',
              color: const Color(0xFF00E676),
              isDark: isDark,
            ),
          ),
          Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.grey[200]),
          Expanded(
            child: _buildStatItem(
              icon: Icons.local_taxi_rounded,
              value: '$todayTrips',
              unit: 'رحلة',
              label: 'رحلات اليوم',
              color: AppTheme.primaryColor,
              isDark: isDark,
            ),
          ),
          Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.grey[200]),
          Expanded(
            child: _buildStatItem(
              icon: Icons.access_time_filled_rounded,
              value: '--',
              unit: 'ساعة',
              label: 'وقت العمل',
              color: const Color(0xFF29B6F6),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: isDark ? Colors.white : AppTheme.textColor,
                ),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: unit,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white54 : AppTheme.subTextColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : AppTheme.subTextColor,
          ),
        ),
      ],
    );
  }
}
