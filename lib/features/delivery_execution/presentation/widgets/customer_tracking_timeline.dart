import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/delivery_execution_models.dart';
import '../../domain/services/delivery_status_machine.dart';

/// خط زمني حي لتتبع حالة الطلب للزبون (Customer Tracking Timeline)
class CustomerTrackingTimeline extends StatelessWidget {
  final DeliveryExecutionStatus status;

  const CustomerTrackingTimeline({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int currentStep = DeliveryStatusMachine.getStepIndex(status);

    final steps = [
      {'title': 'تم استلام الطلب', 'subtitle': 'تم إرسال الطلب للمحل/المطعم'},
      {'title': 'المندوب قبل الطلب', 'subtitle': 'الكابتن في الطريق لنقطة الاستلام'},
      {'title': 'تم تجهيز واستلام الطلب', 'subtitle': 'الكابتن استلم شحنتك وجاي لعندك'},
      {'title': 'المندوب قريب منك', 'subtitle': 'يرجى الاستعداد للاستلام والتواجد'},
      {'title': 'تم التسليم بنجاح', 'subtitle': 'عافيات! نتمنى لك تجربة ممتعة'},
    ];

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مراحل توصيل الطلب:',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 12.h),
          ...List.generate(steps.length, (index) {
            final isDone = index <= currentStep && status != DeliveryExecutionStatus.cancelled;
            final isCurrent = index == currentStep && status != DeliveryExecutionStatus.cancelled;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 20.r,
                      height: 20.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? const Color(0xFF00BFA5) : Colors.transparent,
                        border: Border.all(
                          color: isDone ? const Color(0xFF00BFA5) : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? Icon(Icons.check, size: 12.sp, color: Colors.white)
                          : null,
                    ),
                    if (index < steps.length - 1)
                      Container(
                        width: 2.w,
                        height: 28.h,
                        color: index < currentStep ? const Color(0xFF00BFA5) : Colors.grey.shade300,
                      ),
                  ],
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: index < steps.length - 1 ? 12.h : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[index]['title'] as String,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.sp,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                            color: isDone
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                        Text(
                          steps[index]['subtitle'] as String,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 10.sp,
                            color: isDone
                                ? (isDark ? Colors.white60 : Colors.black54)
                                : (isDark ? Colors.white24 : Colors.black26),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
