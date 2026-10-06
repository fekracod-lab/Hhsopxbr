import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/delivery_execution_models.dart';
import '../../domain/services/delivery_status_machine.dart';

/// ودجة متابعة خطوات التوصيل (Delivery Status Stepper Widget)
class DeliveryStatusStepper extends StatelessWidget {
  final DeliveryExecutionStatus status;

  const DeliveryStatusStepper({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int activeStep = DeliveryStatusMachine.getStepIndex(status);

    final steps = [
      {'label': 'الطلب', 'icon': Icons.receipt_rounded},
      {'label': 'قبول', 'icon': Icons.two_wheeler_rounded},
      {'label': 'استلام', 'icon': Icons.inventory_2_rounded},
      {'label': 'بالطريق', 'icon': Icons.directions_bike_rounded},
      {'label': 'تسليم', 'icon': Icons.check_circle_rounded},
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final lineIndex = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2.h,
                margin: EdgeInsets.only(bottom: 16.h, left: 2.w, right: 2.w),
                color: lineIndex < activeStep
                    ? const Color(0xFF00BFA5)
                    : (isDark ? Colors.white12 : Colors.black12),
              ),
            );
          }

          final index = i ~/ 2;
          final isCompleted = index < activeStep;
          final isCurrent = index == activeStep;
          final Color stepColor = isCompleted || isCurrent
              ? const Color(0xFF00BFA5)
              : (isDark ? Colors.white24 : Colors.black26);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28.r,
                height: 28.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? const Color(0xFF00BFA5)
                      : (isCompleted
                          ? const Color(0xFF00BFA5).withValues(alpha: 0.15)
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
                  border: Border.all(
                    color: stepColor,
                    width: isCurrent ? 2.0 : 1.2,
                  ),
                ),
                child: Icon(
                  steps[index]['icon'] as IconData,
                  size: 14.sp,
                  color: isCurrent ? Colors.white : stepColor,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                steps[index]['label'] as String,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 10.sp,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
