import 'package:flutter/material.dart';
import '../../domain/entities/driver_dashboard_models.dart';

/// شريط إحصائيات وبونص الكابتن اليومي السريع
class DriverQuickStatsBar extends StatelessWidget {
  final DriverStatsEntity stats;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const DriverQuickStatsBar({
    super.key,
    required this.stats,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleExpand,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'هدف البونص (${stats.todayCompletedTrips}/${stats.dailyTargetTrips})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${stats.todayEarningsTotal.toStringAsFixed(0)} د.ع',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF10B981)),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stats.bonusProgressPercentage,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
