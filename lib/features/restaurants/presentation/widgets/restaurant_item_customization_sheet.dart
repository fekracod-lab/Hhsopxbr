import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/iraqi_currency_formatter.dart';
import '../../domain/services/restaurant_details_calculator.dart';

const Color _primaryColor = Color(0xFF00BFA5);
const Color _darkBackground = Color(0xFF0F1719);
const Color _darkSurface = Color(0xFF142023);
const Color _darkCard = Color(0xFF1B2B2F);

/// نافذة تخصيص الوجبة (الأحجام، الإضافات، الملاحظات، والكمية) بالأرقام العربية والتفقيط
class RestaurantItemCustomizationSheet extends StatefulWidget {
  final String id;
  final String name;
  final double basePrice;
  final String? imageUrl;
  final bool isDark;
  final Function(double finalPrice, String size, String options, String notes, int qty) onAdd;

  const RestaurantItemCustomizationSheet({
    super.key,
    required this.id,
    required this.name,
    required this.basePrice,
    this.imageUrl,
    required this.isDark,
    required this.onAdd,
  });

  @override
  State<RestaurantItemCustomizationSheet> createState() => _RestaurantItemCustomizationSheetState();
}

class _RestaurantItemCustomizationSheetState extends State<RestaurantItemCustomizationSheet> {
  int _selectedSizeIndex = 0;
  final List<Map<String, dynamic>> _sizes = [
    {'name': 'عادي (وسط)', 'extra': 0.0},
    {'name': 'كبير', 'extra': 1500.0},
    {'name': 'عائلي', 'extra': 3500.0},
  ];

  final List<Map<String, dynamic>> _availableAddons = [
    {'name': 'جبن إضافي ذائب', 'price': 1000.0, 'icon': Icons.lunch_dining_rounded},
    {'name': 'صوص خاص (مدار)', 'price': 500.0, 'icon': Icons.water_drop_rounded},
    {'name': 'مشروب غازي بارد', 'price': 750.0, 'icon': Icons.local_drink_rounded},
    {'name': 'مقبلات وبطاطس', 'price': 1500.0, 'icon': Icons.restaurant_rounded},
  ];

  final Set<String> _selectedAddons = {};
  final TextEditingController _notesController = TextEditingController();
  int _quantity = 1;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _unitPrice {
    final extra = _sizes[_selectedSizeIndex]['extra'] as double;
    final addonPrices = _availableAddons
        .where((a) => _selectedAddons.contains(a['name']))
        .map((a) => a['price'] as double)
        .toList();

    return RestaurantDetailsCalculator.calculateItemPrice(
      basePrice: widget.basePrice,
      sizeExtra: extra,
      addonPrices: addonPrices,
    );
  }

  double get _totalPrice {
    return RestaurantDetailsCalculator.calculateTotalPrice(
      unitPrice: _unitPrice,
      quantity: _quantity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final name = widget.name.isNotEmpty ? widget.name : 'وجبة شهية';
    final imageUrl = widget.imageUrl;

    final String arabicBasePrice = IraqiCurrencyFormatter.format(widget.basePrice);
    final String arabicBaseWritten = IraqiCurrencyFormatter.formatWritten(widget.basePrice);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? _darkBackground : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
              width: 44.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meal Header Card
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16.r),
                        child: Container(
                          width: 76.r,
                          height: 76.r,
                          color: isDark ? _darkSurface : const Color(0xFFE2EBE9),
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(imageUrl, fit: BoxFit.cover)
                              : const Icon(Icons.fastfood, size: 36, color: _primaryColor),
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              arabicBasePrice,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w900,
                                color: _primaryColor,
                              ),
                            ),
                            Text(
                              '($arabicBaseWritten)',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF00897B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Section 1: Choose Size
                  Text(
                    'اختر الحجم',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: List.generate(_sizes.length, (idx) {
                      final size = _sizes[idx];
                      final isSelected = _selectedSizeIndex == idx;
                      final extra = size['extra'] as double;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedSizeIndex = idx);
                          },
                          child: Container(
                            margin: EdgeInsets.only(left: idx == _sizes.length - 1 ? 0 : 8.w),
                            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 6.w),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _primaryColor.withValues(alpha: 0.14)
                                  : (isDark ? _darkSurface : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: isSelected ? _primaryColor : (isDark ? Colors.white10 : const Color(0xFFE2EBE9)),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  size['name'],
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5.sp,
                                    color: isSelected
                                        ? _primaryColor
                                        : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                  ),
                                ),
                                if (extra > 0) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    '+${IraqiCurrencyFormatter.format(extra)}',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 9.5.sp,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? _primaryColor : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 20.h),

                  // Section 2: Add-ons
                  Text(
                    'إضافات اختيارية',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  ..._availableAddons.map((addon) {
                    final isChecked = _selectedAddons.contains(addon['name']);
                    final price = addon['price'] as double;
                    final arabicAddonPrice = IraqiCurrencyFormatter.format(price);
                    final arabicAddonWritten = IraqiCurrencyFormatter.formatWritten(price);

                    return Container(
                      margin: EdgeInsets.only(bottom: 8.h),
                      decoration: BoxDecoration(
                        color: isDark ? _darkSurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: isChecked ? _primaryColor : (isDark ? Colors.white10 : const Color(0xFFE2EBE9)),
                          width: isChecked ? 1.5 : 1,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isChecked,
                        activeColor: _primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                        title: Row(
                          children: [
                            Icon(addon['icon'] as IconData, size: 18.sp, color: isChecked ? _primaryColor : Colors.grey),
                            SizedBox(width: 8.w),
                            Text(
                              addon['name'] as String,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '+$arabicAddonPrice ($arabicAddonWritten)',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 10.sp,
                            color: isChecked ? _primaryColor : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (val == true) {
                              _selectedAddons.add(addon['name']);
                            } else {
                              _selectedAddons.remove(addon['name']);
                            }
                          });
                        },
                      ),
                    );
                  }),
                  SizedBox(height: 16.h),

                  // Section 3: Special Notes
                  Text(
                    'ملاحظات خاصة للشيف (اختياري)',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.sp,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: 'مثال: بدون بصل، صوص إضافي، حار جداً...',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.sp,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: isDark ? _darkSurface : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),

          // Bottom Action Bar (Quantity + Add Button)
          Container(
            padding: EdgeInsets.fromLTRB(
              18.w,
              12.h,
              18.w,
              MediaQuery.of(context).padding.bottom + 12.h,
            ),
            decoration: BoxDecoration(
              color: isDark ? _darkCard : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 15,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Quantity selector
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? _darkSurface : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _quantity > 1
                            ? () {
                                HapticFeedback.lightImpact();
                                setState(() => _quantity--);
                              }
                            : null,
                        icon: const Icon(Icons.remove, size: 18),
                        color: _quantity > 1 ? Colors.redAccent : Colors.grey,
                      ),
                      Text(
                        IraqiCurrencyFormatter.format(_quantity, includeSymbol: false),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.sp,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _quantity++);
                        },
                        icon: const Icon(Icons.add, size: 18, color: _primaryColor),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 14.w),

                // Submit Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      final sizeName = _sizes[_selectedSizeIndex]['name'] as String;
                      final optionsStr = _selectedAddons.join('،');
                      final notesStr = _notesController.text.trim();

                      widget.onAdd(_unitPrice, sizeName, optionsStr, notesStr, _quantity);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      elevation: 0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'إضافة للسلة (${IraqiCurrencyFormatter.format(_totalPrice)})',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.sp,
                          ),
                        ),
                        Text(
                          '(${IraqiCurrencyFormatter.formatWritten(_totalPrice)})',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.w600,
                            fontSize: 9.5.sp,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
