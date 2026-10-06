// شريط مؤشرات الأداء الحية للعمليات (Ride Management KPI Bar Widget)
// Clean Architecture — Presentation Layer: Operational Metrics Display

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/ride_management_models.dart';

class RideManagementKpiBar extends StatelessWidget {
  final RideManagementKpiMetrics metrics;
  final bool isDark;

  const RideManagementKpiBar({
    super.key,
    required this.metrics,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF0C2428) : const Color(0xFFF1F5F9),
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
      child: Row(
        children: [
          _buildMetricTile(
            label: 'كباتن متصلون',
            value: '${metrics.onlineDriversCount}',
            icon: Icons.local_taxi_rounded,
            color: const Color(0xFF00C853),
          ),
          SizedBox(width: 8.w),
          _buildMetricTile(
            label: 'رحلات جارية',
            value: '${metrics.activeTripsCount}',
            icon: Icons.alt_route_rounded,
            color: const Color(0xFF0284C7),
          ),
          SizedBox(width: 8.w),
          _buildMetricTile(
            label: 'بانتظار كابتن',
            value: '${metrics.searchingTripsCount}',
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFF59E0B),
          ),
          SizedBox(width: 8.w),
          _buildMetricTile(
            label: 'مكتملة اليوم',
            value: '${metrics.todayCompletedTripsCount}',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 6.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF133338) : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 13.r),
                SizedBox(width: 4.w),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.sp,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5.sp,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
