import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/delivery_execution_models.dart';

/// شارة الوقت والمسافة المتوقعة الحية (Floating Live ETA Badge)
class DeliveryEtaBadge extends StatelessWidget {
  final DeliveryRouteEntity? route;
  final DeliveryExecutionStatus status;

  const DeliveryEtaBadge({
    super.key,
    required this.route,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    if (route == null || route!.isEmpty ||
        status == DeliveryExecutionStatus.delivered ||
        status == DeliveryExecutionStatus.cancelled) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int minutes = route!.durationMinutes;
    final double km = route!.distanceKm;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_rounded, color: Color(0xFF00BFA5), size: 18),
          SizedBox(width: 6.w),
          Text(
            '$minutes دقيقة',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            width: 4.r,
            height: 4.r,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '${km.toStringAsFixed(1)} كم',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF00BFA5),
            ),
          ),
        ],
      ),
    );
  }
}
