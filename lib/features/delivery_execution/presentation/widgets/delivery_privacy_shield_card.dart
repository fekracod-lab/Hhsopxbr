import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/delivery_execution_models.dart';

/// بطاقة حماية خصوصية بيانات العميل (Customer Privacy Shield Card)
class DeliveryPrivacyShieldCard extends StatelessWidget {
  final DeliveryExecutionEntity delivery;

  const DeliveryPrivacyShieldCard({super.key, required this.delivery});

  Future<void> _makePhoneCall(String phone) async {
    if (phone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(launchUri);
    } catch (_) {}
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final url = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    try {
      final bool launched = await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
      if (!launched) {
        final webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      final webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMasked = delivery.isCustomerMasked;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isMasked
              ? Colors.amber.withValues(alpha: 0.3)
              : const Color(0xFF00BFA5).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: isMasked
                      ? Colors.amber.withValues(alpha: 0.15)
                      : const Color(0xFF00BFA5).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMasked ? Icons.lock_rounded : Icons.person_pin_circle_rounded,
                  color: isMasked ? Colors.amber : const Color(0xFF00BFA5),
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMasked ? 'بيانات الزبون (محمية ومقيدة )' : 'معلومات تسليم الزبون',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      isMasked
                          ? 'يتم كشف الاسم ورقم الهاتف تلقائياً فور استلام الشحنة من المحل'
                          : delivery.customerName,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.sp,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (!isMasked) ...[
            SizedBox(height: 14.h),
            const Divider(color: Colors.white10),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 16.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    delivery.dropoffPoint.address.isNotEmpty
                        ? delivery.dropoffPoint.address
                        : 'موقع الزبون محدد على الخريطة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.sp,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
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
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                    ),
                    icon: Icon(Icons.phone_rounded, size: 18.sp),
                    label: Text(
                      'اتصال بالزبون',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _makePhoneCall(delivery.customerPhone),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00BFA5)),
                      foregroundColor: const Color(0xFF00BFA5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                    ),
                    icon: Icon(Icons.navigation_rounded, size: 18.sp),
                    label: Text(
                      'توجيه الخريطة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _launchMaps(
                      delivery.dropoffPoint.latitude,
                      delivery.dropoffPoint.longitude,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
