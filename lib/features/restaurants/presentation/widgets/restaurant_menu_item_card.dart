import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/iraqi_currency_formatter.dart';
import '../../domain/entities/restaurant_details_models.dart';

const Color _primary = Color(0xFF00BFA5);

/// بطاقة عرض الوجبة الأفقية بتصميم حديث وخط IBM مع السعر بالأرقام العربية والتفقيط
class RestaurantMenuItemCard extends StatelessWidget {
  final MenuItemDetailsEntity item;
  final int quantity;
  final bool isDark;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onCustomize;

  const RestaurantMenuItemCard({
    super.key,
    required this.item,
    required this.quantity,
    required this.isDark,
    required this.onAdd,
    required this.onRemove,
    required this.onCustomize,
  });

  @override
  Widget build(BuildContext context) {
    final double price = item.price;
    final String name = item.name.isNotEmpty ? item.name : 'وجبة';
    final String imageUrl = item.imageUrl;

    final String arabicPriceDigits = IraqiCurrencyFormatter.format(price);
    final String arabicPriceWritten = IraqiCurrencyFormatter.formatWritten(price);

    return GestureDetector(
      onTap: onCustomize,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D20) : Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isDark ? const Color(0xFF1F3538) : const Color(0xFFE2EBE9),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Meal Details Info ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      item.description.isNotEmpty
                          ? item.description
                          : 'اضغط لتخصيص الحجم والإضافات الشهية...',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10.5.sp,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 6.h),

                    // Written price
                    Text(
                      ' $arabicPriceWritten',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF00897B),
                      ),
                    ),

                    SizedBox(height: 8.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          arabicPriceDigits,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w900,
                            color: _primary,
                          ),
                        ),
                        if (quantity > 0)
                          _buildQtyControl()
                        else
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onCustomize();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                              decoration: BoxDecoration(
                                color: _primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: _primary.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune_rounded, size: 13.sp, color: _primary),
                                  SizedBox(width: 4.w),
                                  Text(
                                    "تخصيص",
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10.5.sp,
                                      fontWeight: FontWeight.w800,
                                      color: _primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── 2. Meal Image ──
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(17.r),
                bottomLeft: Radius.circular(17.r),
              ),
              child: SizedBox(
                width: 105.w,
                height: 115.h,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                      )
                    : _buildPlaceholder(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyControl() {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: _primary, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onRemove();
            },
            icon: const Icon(Icons.remove, size: 14, color: Colors.redAccent),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.h),
          ),
          Text(
            IraqiCurrencyFormatter.format(quantity, includeSymbol: false),
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w800,
              fontSize: 11.5.sp,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onAdd();
            },
            icon: const Icon(Icons.add, size: 14, color: _primary),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.h),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1A2B2E) : const Color(0xFFE0F2F1),
      child: Center(
        child: Icon(
          Icons.fastfood_rounded,
          size: 32.sp,
          color: isDark ? Colors.white24 : _primary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
