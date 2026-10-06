import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/delivery_execution_models.dart';

/// بطاقة معلومات الكابتن للزبون (Customer Driver Card)
class CustomerDriverCard extends StatelessWidget {
  final DeliveryDriverInfo? driver;
  final VoidCallback? onChatTap;

  const CustomerDriverCard({
    super.key,
    required this.driver,
    this.onChatTap,
  });

  Future<void> _makePhoneCall(String phone) async {
    if (phone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(launchUri);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (driver == null) {
      return Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'جاري البحث عن أقرب كابتن توصيل متاح...',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.sp,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                backgroundImage: driver!.imageUrl.isNotEmpty
                    ? NetworkImage(driver!.imageUrl)
                    : null,
                child: driver!.imageUrl.isEmpty
                    ? Icon(Icons.two_wheeler_rounded, color: const Color(0xFF00BFA5), size: 24.sp)
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver!.name,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: Colors.amber, size: 14.sp),
                        SizedBox(width: 4.w),
                        Text(
                          driver!.rating.toStringAsFixed(1),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '• ${driver!.vehicleType}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.sp,
                            color: isDark ? Colors.white60 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                  icon: Icon(Icons.phone_rounded, size: 18.sp),
                  label: Text(
                    'اتصال بالكابتن',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => _makePhoneCall(driver!.phone),
                ),
              ),
              if (onChatTap != null) ...[
                SizedBox(width: 10.w),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF0284C7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded),
                  onPressed: onChatTap,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
