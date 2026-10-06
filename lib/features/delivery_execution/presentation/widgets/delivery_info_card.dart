import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/delivery_execution_models.dart';

/// بطاقة معلومات الطلب والمتجر (Delivery Info Card)
class DeliveryInfoCard extends StatelessWidget {
  final DeliveryExecutionEntity delivery;

  const DeliveryInfoCard({super.key, required this.delivery});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat('#,###', 'ar_IQ');

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
          // 1. عنوان المتجر / نقطة الاستلام
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  delivery.source == OrderDeliverySource.restaurant
                      ? Icons.restaurant_rounded
                      : (delivery.source == OrderDeliverySource.store
                          ? Icons.storefront_rounded
                          : Icons.local_shipping_rounded),
                  color: const Color(0xFF00BFA5),
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.merchantName.isNotEmpty ? delivery.merchantName : 'نقطة الاستلام',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      delivery.pickupPoint.address.isNotEmpty
                          ? delivery.pickupPoint.address
                          : 'الموقع محدد على الخريطة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

          if (delivery.items.isNotEmpty) ...[
            SizedBox(height: 14.h),
            const Divider(color: Colors.white10),
            SizedBox(height: 8.h),
            Text(
              'محتويات الطلب (${delivery.items.length}):',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            SizedBox(height: 8.h),
            ...delivery.items.map((item) => Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.quantity}x ${item.name}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.sp,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      Text(
                        '${currencyFormat.format(item.total)} د.ع',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          SizedBox(height: 12.h),
          const Divider(color: Colors.white10),
          SizedBox(height: 8.h),

          // 2. الحسابات المالية
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'أجرة التوصيل:',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.sp,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
              Text(
                '${currencyFormat.format(delivery.deliveryFee)} د.ع',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00BFA5),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'المجموع الكلي المطلوب:',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Text(
                '${currencyFormat.format(delivery.grandTotal)} د.ع',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFFB300),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Icon(
                delivery.isPaid ? Icons.check_circle_rounded : Icons.payments_rounded,
                size: 14.sp,
                color: delivery.isPaid ? Colors.green : Colors.orangeAccent,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  delivery.isPaid ? 'مدفوع إلكترونياً' : 'الدفع عند الاستلام (نقد)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: delivery.isPaid ? Colors.green : Colors.orangeAccent,
                  ),
                ),
              ),
            ],
          ),

          if (delivery.notes.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'ملاحظات الزبون: ${delivery.notes}',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.sp,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
