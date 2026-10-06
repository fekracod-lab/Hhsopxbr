import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/restaurant_models.dart';

const Color _primary = Color(0xFF26A69A);
const Color _accent = Color(0xFF00796B);
const Color _darkCard = Color(0xFF113033);
const Color _darkText = Color(0xFFE0F2F1);
const Color _textColor = Color(0xFF1A1A1A);

/// شريط تتبع الطلب النشط المباشر للعميل (Live Active Order Tracker Widget)
class RestaurantActiveOrderTracker extends StatelessWidget {
  final ActiveOrderEntity? activeOrder;
  final bool isDark;
  final VoidCallback onTrackOrderTap;

  const RestaurantActiveOrderTracker({
    super.key,
    required this.activeOrder,
    required this.isDark,
    required this.onTrackOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    if (activeOrder == null) return const SizedBox.shrink();

    final status = activeOrder!.status;
    final restaurantName = activeOrder!.restaurantName ?? 'المطعم';

    int activeStep = 0;
    String statusText = 'جاي ننتظر المطعم';
    IconData statusIcon = Icons.receipt_long_rounded;

    if (status == 'accepted') {
      activeStep = 1;
      statusText = 'جاي يجهزون أكلك';
      statusIcon = Icons.soup_kitchen_rounded;
    } else if (status == 'delivering' || status == 'on_the_way' || status == 'picked_up') {
      activeStep = 2;
      statusText = 'ويا الكابتن وبالطريق إلك';
      statusIcon = Icons.delivery_dining_rounded;
    }

    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 8.h),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: _primary.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              color: _primary.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: _primary, size: 20.r),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurantName,
                          style: TextStyle(
                            fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? _darkText : _textColor,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: _accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onTrackOrderTap();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'تتبع الطلب',
                      style: TextStyle(
                        fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
              child: Row(
                children: [
                  _buildStep(0, activeStep, 'تثبيت الطلب', Icons.check_circle_rounded, isDark),
                  _buildStepConnector(0, activeStep),
                  _buildStep(1, activeStep, 'تحضير الأكل', Icons.soup_kitchen_rounded, isDark),
                  _buildStepConnector(1, activeStep),
                  _buildStep(2, activeStep, 'بالطريق إلك', Icons.delivery_dining_rounded, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int step, int activeStep, String label, IconData icon, bool isDark) {
    final isDone = activeStep >= step;
    final isActive = activeStep == step;
    final color = isDone ? _primary : (isDark ? Colors.white24 : Colors.grey[300]!);

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: isDone ? _primary.withValues(alpha: 0.15) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: isActive ? 2.5 : 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isDone ? _primary : (isDark ? Colors.white30 : Colors.grey[400]!),
              size: 18.r,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
              fontSize: 9.5.sp,
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
              color: isDone
                  ? (isDark ? _darkText : _textColor)
                  : (isDark ? Colors.white.withValues(alpha: 0.35) : Colors.grey[400]!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step, int activeStep) {
    final isDone = activeStep > step;
    return Container(
      width: 25.w,
      height: 2.h,
      margin: EdgeInsets.only(bottom: 20.h),
      color: isDone ? _primary : Colors.grey[300],
    );
  }
}
