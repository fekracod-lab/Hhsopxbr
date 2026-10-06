// تبويب الإحصائيات وسجل الرحلات المكتملة (Ride History & Analytics Tab Widget)
// Clean Architecture — Presentation Layer: Financial Metrics & Trip Archive

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import '../../domain/entities/ride_management_models.dart';
import '../../domain/services/ride_management_calculator.dart';

class RideHistoryAnalyticsTab extends StatelessWidget {
  final List<RideAdminEntity> historyRides;
  final RideHistoryAnalyticsMetrics analytics;
  final ValueChanged<String> onCallPhone;
  final bool isDark;

  const RideHistoryAnalyticsTab({
    super.key,
    required this.historyRides,
    required this.analytics,
    required this.onCallPhone,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // شبكة المؤشرات المالية
          Row(
            children: [
              _buildStatCard(
                title: 'إجمالي الدخل (GMV)',
                value: RideManagementCalculator.formatIraqiCurrency(analytics.totalGmv),
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF00BFA5),
              ),
              SizedBox(width: 8.w),
              _buildStatCard(
                title: 'عمولة المنصة (10%)',
                value: RideManagementCalculator.formatIraqiCurrency(analytics.totalPlatformCommission),
                icon: Icons.pie_chart_rounded,
                color: const Color(0xFF0284C7),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _buildStatCard(
                title: 'الرحلات المكتملة',
                value: '${analytics.totalCompletedRides}',
                icon: Icons.task_alt_rounded,
                color: const Color(0xFF00C853),
              ),
              SizedBox(width: 8.w),
              _buildStatCard(
                title: 'متوسط الأجرة',
                value: RideManagementCalculator.formatIraqiCurrency(analytics.averageFare),
                icon: Icons.trending_up_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // أرشيف الرحلات المكتملة
          Text(
            'سجل آخر 100 رحلة مكتملة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.sp,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),

          if (historyRides.isEmpty)
            Container(
              padding: EdgeInsets.all(24.w),
              alignment: Alignment.center,
              child: Text(
                'ماكو رحلات حالياً مكتملة مسجلة بالأرشيف',
                style: TextStyle(color: Colors.grey, fontSize: 12.sp),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: historyRides.length,
              itemBuilder: (ctx, idx) {
                final ride = historyRides[idx];
                final dateStr = ride.completedAt != null
                    ? intl.DateFormat('yyyy/MM/dd - hh:mm a').format(ride.completedAt!)
                    : 'تاريخ غير محدد';

                return Card(
                  margin: EdgeInsets.only(bottom: 8.h),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  color: isDark ? const Color(0xFF0C2428) : Colors.white,
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF00C853).withValues(alpha: 0.15),
                      child: Icon(Icons.check_rounded, color: const Color(0xFF00C853), size: 18.r),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ride.passengerName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          RideManagementCalculator.formatIraqiCurrency(ride.fare),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                            color: const Color(0xFF00C853),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 2.h),
                        Text(
                          ' ${ride.pickupAddress} ← ${ride.dropoffAddress}',
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'الكابتن: ${ride.driverName ?? "غير محدد"} • $dateStr',
                          style: TextStyle(fontSize: 9.5.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0C2428) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                Icon(icon, color: color, size: 16.r),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13.sp,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
