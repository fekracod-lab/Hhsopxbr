import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// شريط تصنيفات المطابخ الفاخر (Luxury Visual Cuisine Categories Bar)
class RestaurantCuisineCategoriesBar extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;
  final bool isDark;

  const RestaurantCuisineCategoriesBar({
    super.key,
    required this.selectedCategory,
    required this.onSelectCategory,
    required this.isDark,
  });

  static const List<CuisineCategoryItem> categories = [
    CuisineCategoryItem(
      id: 'الكل',
      label: 'الكل',
      icon: '',
      iconData: Icons.restaurant_menu_rounded,
      imageFileName: 'all.png',
      color: Color(0xFF00BFA5),
    ),
    CuisineCategoryItem(
      id: 'برغر وسندويشات',
      label: 'برغر وسندويش',
      icon: '',
      iconData: Icons.lunch_dining_rounded,
      imageFileName: 'burger.png',
      color: Color(0xFFFF9800),
    ),
    CuisineCategoryItem(
      id: 'مشويات وكباب',
      label: 'مشاوي وكباب',
      icon: '',
      iconData: Icons.outdoor_grill_rounded,
      imageFileName: 'kebab.png',
      altImageFileName: 'grill.png',
      color: Color(0xFFE53935),
    ),
    CuisineCategoryItem(
      id: 'بيتزا ومعجنات',
      label: 'بيتزا وفطائر',
      icon: '',
      iconData: Icons.local_pizza_rounded,
      imageFileName: 'pizza.png',
      color: Color(0xFFFF7043),
    ),
    CuisineCategoryItem(
      id: 'دجاج ومقرمشات',
      label: 'دجاج كرسبي',
      icon: '',
      iconData: Icons.fastfood_rounded,
      imageFileName: 'chicken.png',
      color: Color(0xFFF59E0B),
    ),
    CuisineCategoryItem(
      id: 'عصائر ومشروبات',
      label: 'عصائر ومشروبات',
      icon: '',
      iconData: Icons.local_bar_rounded,
      imageFileName: 'drinks.png',
      color: Color(0xFF00ACC1),
    ),
    CuisineCategoryItem(
      id: 'حلويات وكافيهات',
      label: 'حلويات وكافيه',
      icon: '',
      iconData: Icons.cake_rounded,
      imageFileName: 'sweets.png',
      color: Color(0xFFEC407A),
    ),
    CuisineCategoryItem(
      id: 'مأكولات شرقية',
      label: 'مأكولات شرقية',
      icon: '',
      iconData: Icons.ramen_dining_rounded,
      imageFileName: 'oriental.png',
      color: Color(0xFF8D6E63),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 16.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'حدد وجبتك',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if (selectedCategory.isNotEmpty && selectedCategory != 'الكل')
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSelectCategory('الكل');
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'عرض الكل',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF00BFA5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 108.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final item = categories[index];
              final isSelected = selectedCategory == item.id ||
                  (item.id == 'الكل' && selectedCategory.isEmpty);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelectCategory(item.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: 78.w,
                  margin: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF0D3330) : const Color(0xFFE6F8F5))
                        : (isDark ? const Color(0xFF131F22) : Colors.white),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00BFA5)
                          : (isDark ? const Color(0xFF1D3236) : const Color(0xFFE2EBE9)),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00BFA5).withValues(alpha: 0.32),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── 1. Big Visual Food Graphic Pod ──
                      Container(
                        width: 54.r,
                        height: 54.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF00BFA5).withValues(alpha: 0.18)
                              : (isDark ? const Color(0xFF1A2B2F) : const Color(0xFFF1F6F5)),
                        ),
                        child: Center(
                          child: ClipOval(
                            child: _buildFoodImage(item),
                          ),
                        ),
                      ),
                      SizedBox(height: 6.h),

                      // ── 2. Category Title ──
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10.5.sp,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? (isDark ? const Color(0xFF5EEAD4) : const Color(0xFF00897B))
                              : (isDark ? const Color(0xFFE0F2F1) : const Color(0xFF334155)),
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFoodImage(CuisineCategoryItem item) {
    // 1. Try 'imges/restaurants/<name>.png'
    return Image.asset(
      'imges/restaurants/${item.imageFileName}',
      width: 50.r,
      height: 50.r,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) {
        // 2. Try 'imges/<name>.png'
        return Image.asset(
          'imges/${item.imageFileName}',
          width: 50.r,
          height: 50.r,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) {
            // 3. Try alt filename if available
            if (item.altImageFileName != null) {
              return Image.asset(
                'imges/restaurants/${item.altImageFileName!}',
                width: 50.r,
                height: 50.r,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) {
                  return Image.asset(
                    'imges/${item.altImageFileName!}',
                    width: 50.r,
                    height: 50.r,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => _fallbackDoubleExtension(item),
                  );
                },
              );
            }
            return _fallbackDoubleExtension(item);
          },
        );
      },
    );
  }

  Widget _fallbackDoubleExtension(CuisineCategoryItem item) {
    return Image.asset(
      'imges/restaurants/${item.imageFileName}.png',
      width: 50.r,
      height: 50.r,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) {
        return Image.asset(
          'imges/${item.imageFileName}.png',
          width: 50.r,
          height: 50.r,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) {
            // Final fallback to icon
            return Center(
              child: Icon(
                item.iconData ?? Icons.restaurant_rounded,
                size: 26.sp,
                color: item.color,
              ),
            );
          },
        );
      },
    );
  }
}

class CuisineCategoryItem {
  final String id;
  final String label;
  final String icon;
  final IconData? iconData;
  final String imageFileName;
  final String? altImageFileName;
  final Color color;

  const CuisineCategoryItem({
    required this.id,
    required this.label,
    this.icon = '',
    this.iconData,
    required this.imageFileName,
    this.altImageFileName,
    required this.color,
  });
}
