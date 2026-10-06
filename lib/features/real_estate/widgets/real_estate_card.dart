import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../services/real_estate_service.dart';

class RealEstateCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleSold;

  const RealEstateCard({
    super.key,
    required this.data,
    required this.docId,
    required this.isDark,
    this.onTap,
    this.onDelete,
    this.onToggleSold,
  });

  @override
  Widget build(BuildContext context) {
    final service = RealEstateService();
    final isOwner = service.currentUser != null && data['createdBy'] == service.currentUser!.uid;
    final isSold = data['sold'] == true;
    final type = data['type'] ?? 'للبيع';
    final category = data['category'] ?? 'بيت';
    final title = data['title'] ?? 'عقار معروض للبيع/الإيجار';
    final price = data['price']?.toString() ?? 'اتفاقي';
    final currency = data['currency'] == 'USD' ? '\$' : 'د.ع';
    final area = data['area']?.toString() ?? '';
    final location = data['location']?.toString() ?? '';
    final city = data['city']?.toString() ?? 'القائم';
    final gov = data['governorate']?.toString() ?? '';
    final locText = (gov.isNotEmpty && gov != city && !city.contains(gov))
        ? (location.isNotEmpty ? '$location • $city ($gov)' : '$city ($gov)')
        : (location.isNotEmpty ? '$location • $city' : city);
    final phone = data['phone']?.toString() ?? '';
    final imageUrl = (data['images'] is List && (data['images'] as List).isNotEmpty)
        ? (data['images'] as List).first
        : (data['imageUrl'] ?? '');
    final imagesCount = (data['images'] is List) ? (data['images'] as List).length : 0;
    final bedrooms = data['bedrooms'] ?? 0;
    final bathrooms = data['bathrooms'] ?? 0;
    final streetWidth = data['streetWidth']?.toString() ?? '';
    final views = data['views'] ?? 0;
    final likesCount = data['likesCount'] ?? 0;
    final ownerName = data['ownerName'] ?? 'معلن مدار';

    final isForSale = type == 'للبيع';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C2428) : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isSold
              ? Colors.red.withValues(alpha: 0.4)
              : (isDark ? Colors.white12 : Colors.grey.shade200),
          width: isSold ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            service.incrementViews(docId);
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(22.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Property Image with Overlay Badges ──
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
                    child: Container(
                      height: 175.h,
                      width: double.infinity,
                      color: isDark ? const Color(0xFF13363A) : Colors.grey.shade100,
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),

                  // Gradient Shade
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top Left: Sold Status or Type Badge
                  Positioned(
                    top: 12.h,
                    left: 12.w,
                    child: Row(
                      children: [
                        if (isSold)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4.w),
                                Text(
                                  isForSale ? 'تم البيع' : 'تم التأجير',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5.sp,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isForSale
                                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                    : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: (isForSale ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(
                              isForSale ? 'للبيع' : 'للإيجار',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.sp,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Top Right: Images Count Badge
                  if (imagesCount > 1)
                    Positioned(
                      top: 12.h,
                      right: 12.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.photo_library_rounded, color: Colors.white, size: 13),
                            SizedBox(width: 4.w),
                            Text(
                              '$imagesCount صور',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom Overlay: Price Pill
                  Positioned(
                    bottom: 10.h,
                    left: 12.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: app_colors.primaryColor, width: 1.2),
                      ),
                      child: Text(
                        '$price $currency',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                          color: const Color(0xFF34D399),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Overlay: Views counter
                  Positioned(
                    bottom: 12.h,
                    right: 12.w,
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_rounded, color: Colors.white70, size: 14),
                        SizedBox(width: 4.w),
                        Text(
                          '$views مشاهدة',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── 2. Property Info & Title ──
              Padding(
                padding: EdgeInsets.all(14.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Pill
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: app_colors.primaryColor, size: 15),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            '$locText ',
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                        // Likes
                        GestureDetector(
                          onTap: () => service.toggleLike(docId),
                          child: Row(
                            children: [
                              const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 16),
                              SizedBox(width: 3.w),
                              Text(
                                '$likesCount',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),

                    // Property Title
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: isDark ? Colors.white : const Color(0xFF0C2428),
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // Specs Badges Row (Area, Bedrooms, Bathrooms, Street)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (area.isNotEmpty)
                            _buildSpecChip(' $area م²', isDark),
                          if (bedrooms > 0)
                            _buildSpecChip(' $bedrooms غرف', isDark),
                          if (bathrooms > 0)
                            _buildSpecChip(' $bathrooms حمام', isDark),
                          if (streetWidth.isNotEmpty)
                            _buildSpecChip('شارع $streetWidthم', isDark),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),

                    Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 1),
                    SizedBox(height: 10.h),

                    // ── 3. Footer: Owner Info & Direct Contact Buttons ──
                    Row(
                      children: [
                        // Owner
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'صاحب العقار / المعلن:',
                                style: TextStyle(
                                  fontSize: 9.5.sp,
                                  color: isDark ? Colors.white38 : Colors.grey,
                                ),
                              ),
                              Text(
                                ownerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5.sp,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Contact Buttons
                        if (phone.isNotEmpty) ...[
                          // WhatsApp Button
                          GestureDetector(
                            onTap: () => service.contactWhatsApp(phone, title),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: const Color(0xFF25D366), width: 1),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 15),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'واتساب',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF25D366),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),

                          // Call Button
                          GestureDetector(
                            onTap: () => service.makePhoneCall(phone),
                            child: Container(
                              padding: EdgeInsets.all(7.r),
                              decoration: BoxDecoration(
                                color: app_colors.primaryColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.phone_rounded, color: app_colors.primaryColor, size: 16),
                            ),
                          ),
                        ],

                        // Owner Controls (Toggle Sold & Delete)
                        if (isOwner) ...[
                          SizedBox(width: 4.w),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 18),
                            color: isDark ? const Color(0xFF0D282D) : Colors.white,
                            onSelected: (val) {
                              if (val == 'sold') onToggleSold?.call();
                              if (val == 'delete') onDelete?.call();
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'sold',
                                child: Text(
                                  isSold ? 'إلغاء حالة المباع' : 'تحديد كـ "مباع / مؤجر"',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'حذف الإعلان',
                                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecChip(String text, bool isDark) {
    return Container(
      margin: EdgeInsets.only(left: 6.w),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13363A) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5.sp,
          fontWeight: FontWeight.bold,
          color: app_colors.primaryColor,
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work_rounded, size: 48.r, color: app_colors.primaryColor.withValues(alpha: 0.3)),
          SizedBox(height: 4.h),
          Text(
            'عقارات مدار - القائم',
            style: TextStyle(
              fontSize: 11.sp,
              color: app_colors.primaryColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
