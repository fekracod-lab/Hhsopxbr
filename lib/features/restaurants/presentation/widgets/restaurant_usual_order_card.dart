import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../pages/restaurant_details_page.dart';
import '../../domain/entities/restaurant_models.dart';

const Color _primary = Color(0xFF26A69A);
const Color _accent = Color(0xFF00796B);
const Color _darkCard = Color(0xFF113033);
const Color _darkSurface = Color(0xFF193B3E);
const Color _darkText = Color(0xFFE0F2F1);
const Color _textColor = Color(0xFF1A1A1A);
const Color _darkSubText = Color(0xFF80CBC4);
const Color _subText = Color(0xFF616161);

/// بطاقة الطلب المعتاد المخصصة (Usual Order Personalized Card)
class RestaurantUsualOrderCard extends StatelessWidget {
  final String userName;
  final ActiveOrderEntity? lastOrder;
  final bool isDark;

  const RestaurantUsualOrderCard({
    super.key,
    required this.userName,
    required this.lastOrder,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (lastOrder == null) {
      return const SizedBox.shrink();
    }

    final displayName = userName.isNotEmpty ? userName : 'يا غالي';

    final restaurantName = lastOrder!.restaurantName ?? 'مطعم مدار';
    final restaurantId = lastOrder!.id;

    String itemName = 'وجبة مدار المتميزة';
    String itemImageUrl = '';
    double price = lastOrder!.totalPrice;

    final itemsList = lastOrder!.rawData['items'] as List?;
    if (itemsList != null && itemsList.isNotEmpty) {
      final firstItem = itemsList.first as Map<String, dynamic>;
      itemName = firstItem['name']?.toString() ?? 'وجبة شهية';
      itemImageUrl = firstItem['imageUrl']?.toString() ?? '';
      price = ((firstItem['price'] ?? 0.0) as num).toDouble();
    }

    final priceStr =
        '${price.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 4.w, bottom: 8.h),
            child: Text(
              '$displayName، مشتهي وجبتك المفضلة؟ ',
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? _darkText : _textColor,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? _darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: isDark
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1.0,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32.r,
                      height: 32.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? _darkSurface : const Color(0xFFF0F4F8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.storefront_rounded,
                          color: _primary,
                          size: 16.r,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      restaurantName,
                      style: TextStyle(
                        fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? _darkText : _textColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 11.r,
                      color: isDark ? _darkSubText : _subText,
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: itemImageUrl.isNotEmpty
                          ? Image.network(
                              itemImageUrl,
                              width: 58.r,
                              height: 58.r,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 58.r,
                                height: 58.r,
                                color: isDark ? _darkSurface : Colors.grey[100],
                                child: const Icon(Icons.fastfood_rounded, color: Colors.grey),
                              ),
                            )
                          : Container(
                              width: 58.r,
                              height: 58.r,
                              color: isDark ? _darkSurface : Colors.grey[100],
                              child: const Icon(Icons.fastfood_rounded, color: Colors.grey),
                            ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? _darkText : _textColor,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            priceStr,
                            style: TextStyle(
                              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w900,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        if (restaurantId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RestaurantDetailsPage(
                                restaurantId: restaurantId,
                                restaurantName: restaurantName,
                                imageUrl: '',
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تدلل عيوني! طلبك من $restaurantName جاهز'),
                              backgroundColor: _accent,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5E00),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        'اطلبها هسة',
                        style: TextStyle(
                          fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
