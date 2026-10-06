// تبويب الرحلات الحية وإدارة الطلبات (Ride Active Trips Tab Widget)
// Clean Architecture — Presentation Layer: Trips List, Filtering & Search

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/ride_management_models.dart';
import 'ride_admin_card.dart';

class RideActiveTripsTab extends StatelessWidget {
  final List<RideAdminEntity> rides;
  final String selectedFilter;
  final String searchQuery;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<RideAdminEntity> onAssignDriver;
  final ValueChanged<RideAdminEntity> onCancelRide;
  final ValueChanged<String> onCallPhone;
  final void Function(double lat, double lng)? onOpenNavigation;
  final bool isDark;

  const RideActiveTripsTab({
    super.key,
    required this.rides,
    required this.selectedFilter,
    required this.searchQuery,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onAssignDriver,
    required this.onCancelRide,
    required this.onCallPhone,
    this.onOpenNavigation,
    this.isDark = false,
  });

  static const List<Map<String, String>> _filterOptions = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'searching', 'label': 'بانتظار كابتن'},
    {'key': 'accepted', 'label': 'تم القبول'},
    {'key': 'arrived', 'label': 'وصل الكابتن'},
    {'key': 'in_progress', 'label': 'في الطريق'},
    {'key': 'completed', 'label': 'مكتملة'},
    {'key': 'cancelled', 'label': 'ملغاة'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // حقل البحث
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          color: isDark ? const Color(0xFF0C2428) : Colors.white,
          child: TextField(
            onChanged: onSearchChanged,
            style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم، الهاتف، المنطلق، الوجهة، أو المعرف...',
              hintStyle: TextStyle(fontSize: 11.sp, color: Colors.grey),
              prefixIcon: Icon(Icons.search_rounded, color: const Color(0xFF00BFA5), size: 20.r),
              filled: true,
              fillColor: isDark ? const Color(0xFF133338) : const Color(0xFFF1F5F9),
              contentPadding: EdgeInsets.symmetric(vertical: 8.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // شريط فلاتر الحالات
        Container(
          height: 44.h,
          color: isDark ? const Color(0xFF0C2428) : Colors.white,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: _filterOptions.length,
            separatorBuilder: (_, __) => SizedBox(width: 6.w),
            itemBuilder: (ctx, idx) {
              final opt = _filterOptions[idx];
              final isSelected = selectedFilter == opt['key'];
              return ChoiceChip(
                label: Text(
                  opt['label']!,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 10.5.sp,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF00BFA5),
                backgroundColor: isDark ? const Color(0xFF133338) : const Color(0xFFF1F5F9),
                onSelected: (_) => onFilterChanged(opt['key']!),
              );
            },
          ),
        ),
        SizedBox(height: 4.h),

        // قائمة الرحلات
        Expanded(
          child: rides.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 48.r, color: Colors.grey),
                      SizedBox(height: 8.h),
                      Text(
                        'ماكو رحلات حالياً مطابقة للبحث أو التصفية الحالية',
                        style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  itemCount: rides.length,
                  itemBuilder: (ctx, idx) {
                    final ride = rides[idx];
                    return RideAdminCard(
                      ride: ride,
                      onAssignDriver: onAssignDriver,
                      onCancelRide: onCancelRide,
                      onCallPhone: onCallPhone,
                      onOpenNavigation: onOpenNavigation,
                      isDark: isDark,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
