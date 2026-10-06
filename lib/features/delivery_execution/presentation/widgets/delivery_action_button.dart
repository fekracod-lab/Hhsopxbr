import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/delivery_execution_models.dart';
import '../../domain/services/delivery_status_machine.dart';

/// زر الإجراء الأساسي للكابتن أثناء القيادة (Primary Driver Action Button)
class DeliveryActionButton extends StatelessWidget {
  final DeliveryExecutionStatus status;
  final bool isProcessing;
  final VoidCallback onAction;

  const DeliveryActionButton({
    super.key,
    required this.status,
    required this.isProcessing,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (status == DeliveryExecutionStatus.delivered ||
        status == DeliveryExecutionStatus.cancelled) {
      return const SizedBox.shrink();
    }

    final String label = DeliveryStatusMachine.getDriverActionButtonLabel(status);
    final Color buttonColor = DeliveryStatusMachine.getStatusColor(status);

    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
        ),
        onPressed: isProcessing
            ? null
            : () {
                HapticFeedback.heavyImpact();
                onAction();
              },
        child: isProcessing
            ? SizedBox(
                width: 24.r,
                height: 24.r,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }
}
