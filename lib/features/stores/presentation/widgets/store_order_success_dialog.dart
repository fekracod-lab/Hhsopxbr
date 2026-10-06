import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';
import '../../../../utils/theme_constants.dart';

/// نافذة تأكيد ونجاح الطلب (Store Order Success Dialog)
class StoreOrderSuccessDialog extends StatefulWidget {
  final String orderId;
  final String storeName;
  final VoidCallback onWhatsAppTap;
  final VoidCallback onMyOrdersTap;
  final VoidCallback onBackToStoreTap;

  const StoreOrderSuccessDialog({
    super.key,
    required this.orderId,
    required this.storeName,
    required this.onWhatsAppTap,
    required this.onMyOrdersTap,
    required this.onBackToStoreTap,
  });

  @override
  State<StoreOrderSuccessDialog> createState() =>
      _StoreOrderSuccessDialogState();
}

class _StoreOrderSuccessDialogState extends State<StoreOrderSuccessDialog> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.center,
      children: [
        AlertDialog(
          backgroundColor:
              isDark ? const Color(0xFF1E1E26) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
          contentPadding: EdgeInsets.zero,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 180.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(30.r)),
                      ),
                      child: Lottie.network(
                        'https://lottie.host/808b8b30-e37c-4a30-8a29-082260ff1f17/O0j4i0i0i0.json',
                        repeat: false,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 80.r,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -15,
                      child: Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(Icons.celebration_rounded,
                            color: Colors.orange, size: 30.sp),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 40.h, 24.w, 24.h),
                  child: Column(
                    children: [
                      Text(
                        'تم إرسال طلبك بنجاح!',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20.sp,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          'رقم الطلب: #${widget.orderId}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        'لقد تم تسجيل طلبك في نظام ${widget.storeName.isNotEmpty ? widget.storeName :'المتجر'}. سنقوم بإشعارك عند تحديث حالة الطلب.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 32.h),

                      // Primary Action: WhatsApp
                      SizedBox(
                        width: double.infinity,
                        height: 56.h,
                        child: ElevatedButton.icon(
                          onPressed: widget.onWhatsAppTap,
                          icon: const Icon(Icons.send_rounded,
                              color: Colors.white),
                          label: const Text(
                            'تأكيد عبر واتساب',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Secondary Action: Go to My Orders
                      SizedBox(
                        width: double.infinity,
                        height: 56.h,
                        child: OutlinedButton.icon(
                          onPressed: widget.onMyOrdersTap,
                          icon: Icon(Icons.shopping_bag_outlined,
                              color: AppTheme.primaryColor),
                          label: Text(
                            'متابعة في طلباتي',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20.h),
                      TextButton(
                        onPressed: widget.onBackToStoreTap,
                        child: const Text(
                          'العودة للمتجر',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple,
          ],
        ),
      ],
    );
  }
}
