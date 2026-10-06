import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dalal_alqaim/services/google_maps_service.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/core/maps/google_maps_initializer.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng _center = const LatLng(33.3152, 44.3661); // Initial camera overview
  String _address = "جاري تحديد العنوان...";
  bool _loading = true;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await GoogleMapsInitializer.ensureInitialized();
      _determinePosition();
    });
  }

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        if (mounted) {
          final target = LatLng(position.latitude, position.longitude);
          setState(() {
            _center = target;
            _loading = false;
          });
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.5));
          _updateAddress(target);
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateAddress(LatLng pos) async {
    final addr = await GoogleMapsService.instance.reverseGeocode(pos);
    if (mounted) {
      setState(() => _address = addr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حدد موقع التوصيل', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? app_colors.darkBackground : Colors.white,
        foregroundColor: isDark ? app_colors.darkText : app_colors.textColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (!_loading)
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _center, zoom: 15),
              onMapCreated: (controller) => _mapController = controller,
              onCameraMove: (pos) => _center = pos.target,
              onCameraIdle: () => _updateAddress(_center),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
            ),
          
          // Central Pin Icon (Standard Map Picker UX)
          Center(
            child: Container(
              margin: EdgeInsets.only(bottom: 35.h),
              child: Icon(Icons.location_on_rounded, color: app_colors.primaryColor, size: 48.sp),
            ),
          ),

          // Bottom Confirmation Panel
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20.h,
            left: 20.w,
            right: 20.w,
            child: Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: isDark ? app_colors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: app_colors.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.map_rounded, color: app_colors.primaryColor, size: 18.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('العنوان المختار', style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                            Text(
                              _address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    height: 54.h,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, {'address': _address, 'location': _center}),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: app_colors.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        elevation: 0,
                      ),
                      child: const Text('تأكيد اختيار الموقع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // My Location Button
          Positioned(
            bottom: 200.h,
            right: 20.w,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: isDark ? app_colors.darkCard : Colors.white,
              elevation: 4,
              onPressed: () async {
                LocationPermission permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                }
                if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
                  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
                  );
                }
              },
              child: const Icon(Icons.my_location, color: app_colors.primaryColor),
            ),
          ),

          if (_loading) 
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: app_colors.primaryColor)),
            ),
        ],
      ),
    );
  }
}
