// بطاقة الرحلة الإدارية (Ride Admin Card Widget)
// Clean Architecture — Presentation Layer: Ride Information & Management Actions

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/ride_management_models.dart';
import '../../domain/services/ride_management_calculator.dart';

class RideAdminCard extends StatelessWidget {
  final RideAdminEntity ride;
  final ValueChanged<RideAdminEntity> onAssignDriver;
  final ValueChanged<RideAdminEntity> onCancelRide;
  final ValueChanged<String> onCallPhone;
  final void Function(double lat, double lng)? onOpenNavigation;
  final bool isDark;

  const RideAdminCard({
    super.key,
    required this.ride,
    required this.onAssignDriver,
    required this.onCancelRide,
    required this.onCallPhone,
    this.onOpenNavigation,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
          color: _getStatusColor(ride.status).withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      color: isDark ? const Color(0xFF0C2428) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شريط الرأس: المعرف والحالة والأجرة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: _getStatusColor(ride.status).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          ride.status.arabicLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5.sp,
                            color: _getStatusColor(ride.status),
                          ),
                        ),
                      ),
                      if (ride.assignedByAdmin) ...[
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9333EA).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            'تعيين إداري',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 9.sp,
                              color: const Color(0xFF9333EA),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  RideManagementCalculator.formatIraqiCurrency(ride.fare),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5.sp,
                    color: const Color(0xFF00C853),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // بيانات الزبون
            Row(
              children: [
                CircleAvatar(
                  radius: 14.r,
                  backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  child: Icon(Icons.person_rounded, size: 16.r, color: const Color(0xFF0284C7)),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'الزبون: ${ride.passengerName}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (ride.passengerPhone.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.phone_rounded, color: const Color(0xFF00BFA5), size: 18.r),
                    tooltip: 'اتصال بالزبون',
                    onPressed: () => onCallPhone(ride.passengerPhone),
                  ),
              ],
            ),
            SizedBox(height: 6.h),

            // مسار الرحلة
            _buildLocationRow(
              icon: Icons.my_location_rounded,
              color: const Color(0xFF00BFA5),
              title: 'الانطلاق',
              address: ride.pickupAddress,
              location: ride.pickupLocation,
            ),
            SizedBox(height: 4.h),
            _buildLocationRow(
              icon: Icons.location_on_rounded,
              color: Colors.redAccent,
              title: 'الوجهة',
              address: ride.dropoffAddress,
              location: ride.dropoffLocation,
            ),
            SizedBox(height: 8.h),

            // بيانات الكابتن المعين (إن وجد)
            if (ride.hasDriverAssigned) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF133338) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_taxi_rounded, color: const Color(0xFF00BFA5), size: 16.r),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        'الكابتن: ${ride.driverName} (${ride.driverCar ?? "سيارة غير محددة"})',
                        style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (ride.driverPhone != null && ride.driverPhone!.isNotEmpty)
                      InkWell(
                        onTap: () => onCallPhone(ride.driverPhone!),
                        child: Text(
                          'اتصال',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: const Color(0xFF00BFA5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
            ],

            // أزرار الإجراءات الإدارية
            if (ride.isActive)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => onCancelRide(ride),
                    icon: Icon(Icons.cancel_outlined, color: Colors.red, size: 15.r),
                    label: const Text('إلغاء الرحلة', style: TextStyle(color: Colors.red)),
                  ),
                  SizedBox(width: 6.w),
                  ElevatedButton.icon(
                    onPressed: () => onAssignDriver(ride),
                    icon: Icon(Icons.person_add_alt_1_rounded, size: 15.r),
                    label: Text(
                      ride.hasDriverAssigned ? 'تغيير الكابتن' : 'تعيين كابتن',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String title,
    required String address,
    PureGeoPoint? location,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14.r),
        SizedBox(width: 6.w),
        Text(
          '$title: ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            address,
            style: TextStyle(fontSize: 10.5.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (location != null && onOpenNavigation != null)
          InkWell(
            onTap: () => onOpenNavigation!(location.latitude, location.longitude),
            child: Icon(Icons.directions_rounded, size: 16.r, color: const Color(0xFF0284C7)),
          ),
      ],
    );
  }

  Color _getStatusColor(RideStatusEnum status) {
    switch (status) {
      case RideStatusEnum.searching:
        return const Color(0xFFF59E0B);
      case RideStatusEnum.accepted:
        return const Color(0xFF0284C7);
      case RideStatusEnum.arrived:
        return const Color(0xFF9333EA);
      case RideStatusEnum.in_progress:
        return const Color(0xFF00BFA5);
      case RideStatusEnum.completed:
        return const Color(0xFF00C853);
      case RideStatusEnum.cancelled:
        return const Color(0xFFE53935);
      case RideStatusEnum.all:
      case RideStatusEnum.unknown:
        return Colors.grey;
    }
  }
}
