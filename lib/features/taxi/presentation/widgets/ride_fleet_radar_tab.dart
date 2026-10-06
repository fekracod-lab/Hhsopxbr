// تبويب رادار الأسطول والخرائط الحية (Ride Fleet Radar Tab Widget)
// Clean Architecture — Presentation Layer: Map, Markers & Live Dispatching

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/entities/ride_management_models.dart';
import '../../domain/services/ride_management_calculator.dart';

class RideFleetRadarTab extends StatelessWidget {
  final List<TaxiDriverAdminEntity> drivers;
  final List<RideAdminEntity> activeRides;
  final TaxiDriverAdminEntity? selectedDriver;
  final RideAdminEntity? selectedRide;
  final ValueChanged<TaxiDriverAdminEntity> onDriverSelected;
  final ValueChanged<RideAdminEntity> onRideSelected;
  final VoidCallback onClearSelection;
  final ValueChanged<RideAdminEntity> onAssignDriver;
  final ValueChanged<RideAdminEntity> onCancelRide;
  final ValueChanged<String> onCallPhone;
  final bool isDark;

  static const LatLng _iraqCenter = LatLng(34.3414, 41.0805); // Al-Qaim / Anbar

  const RideFleetRadarTab({
    super.key,
    required this.drivers,
    required this.activeRides,
    this.selectedDriver,
    this.selectedRide,
    required this.onDriverSelected,
    required this.onRideSelected,
    required this.onClearSelection,
    required this.onAssignDriver,
    required this.onCancelRide,
    required this.onCallPhone,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};

    // 1. علامات الكباتن
    for (final driver in drivers) {
      if (driver.location != null) {
        markers.add(
          Marker(
            markerId: MarkerId('driver_${driver.id}'),
            position: LatLng(driver.location!.latitude, driver.location!.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              driver.isOnline ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: driver.name,
              snippet: '${driver.carModel} • ${driver.isOnline ? "متصل" : "غير متصل"}',
            ),
            onTap: () => onDriverSelected(driver),
          ),
        );
      }
    }

    // 2. علامات الرحلات النشطة
    for (final ride in activeRides) {
      if (ride.pickupLocation != null) {
        markers.add(
          Marker(
            markerId: MarkerId('ride_pickup_${ride.id}'),
            position: LatLng(ride.pickupLocation!.latitude, ride.pickupLocation!.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
            infoWindow: InfoWindow(
              title: 'طلب: ${ride.passengerName}',
              snippet: ride.pickupAddress,
            ),
            onTap: () => onRideSelected(ride),
          ),
        );
      }
    }

    return Stack(
      children: [
        // الخريطة التفاعلية
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _iraqCenter,
            zoom: 13.0,
          ),
          markers: markers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onTap: (_) => onClearSelection(),
        ),

        // شريط إحصائي عائم
        Positioned(
          top: 12.h,
          left: 12.w,
          right: 12.w,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF0C2428) : Colors.white).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C853),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      '${drivers.where((d) => d.isOnline).length} كابتن بالخدمة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.sp,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${activeRides.length} طلب نشط بالرادار',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.sp,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
        ),

        // بطاقة الكابتن المحدد
        if (selectedDriver != null)
          Positioned(
            bottom: 16.h,
            left: 12.w,
            right: 12.w,
            child: _buildSelectedDriverCard(selectedDriver!),
          ),

        // بطاقة الرحلة المحددة
        if (selectedRide != null)
          Positioned(
            bottom: 16.h,
            left: 12.w,
            right: 12.w,
            child: _buildSelectedRideCard(selectedRide!),
          ),
      ],
    );
  }

  Widget _buildSelectedDriverCard(TaxiDriverAdminEntity driver) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      color: isDark ? const Color(0xFF0C2428) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18.r,
                      backgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.15),
                      child: Icon(Icons.person, color: const Color(0xFF00BFA5), size: 20.r),
                    ),
                    SizedBox(width: 8.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${driver.carModel} • ${driver.carNumber}',
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClearSelection,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المديونية: ${RideManagementCalculator.formatIraqiCurrency(driver.appDebt)}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: driver.isBlockedByDebt ? Colors.red : const Color(0xFF0284C7),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => onCallPhone(driver.phone),
                  icon: Icon(Icons.phone, size: 14.r),
                  label: const Text('اتصال بالكابتن', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildSelectedRideCard(RideAdminEntity ride) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      color: isDark ? const Color(0xFF0C2428) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16.r,
                      backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      child: Icon(Icons.local_taxi, color: const Color(0xFF0284C7), size: 18.r),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'طلب رحلة: ${ride.passengerName}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClearSelection,
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              'من: ${ride.pickupAddress} ←  إلى: ${ride.dropoffAddress}',
              style: TextStyle(fontSize: 10.5.sp, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الأجرة: ${RideManagementCalculator.formatIraqiCurrency(ride.fare)}',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF00C853),
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => onCancelRide(ride),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('إلغاء', style: TextStyle()),
                    ),
                    SizedBox(width: 6.w),
                    ElevatedButton(
                      onPressed: () => onAssignDriver(ride),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), foregroundColor: Colors.white),
                      child: const Text('تعيين كابتن', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
