import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/models/parcel_delivery_request.dart';
import 'package:dalal_alqaim/services/parcel_delivery_service.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class ParcelTrackingPage extends StatefulWidget {
  final String requestId;

  const ParcelTrackingPage({super.key, required this.requestId});

  @override
  State<ParcelTrackingPage> createState() => _ParcelTrackingPageState();
}

class _ParcelTrackingPageState extends State<ParcelTrackingPage> {
  final ParcelDeliveryService _parcelService = ParcelDeliveryService();
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: app_colors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'تتبع الشحنة',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<ParcelDeliveryRequest?>(
        stream: _parcelService.getRequestStream(widget.requestId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: app_colors.primaryColor));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('الطلب غير موجود', style: TextStyle(color: Colors.white)),
            );
          }

          final request = snapshot.data!;
          return Stack(children: [_buildMap(request), _buildInformationOverlay(request)]);
        },
      ),
    );
  }

  Widget _buildMap(ParcelDeliveryRequest request) {
    final pickup = LatLng(request.pickupLat, request.pickupLng);
    final dropoff = LatLng(request.dropoffLat, request.dropoffLng);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: pickup, zoom: 14.0),
      onMapCreated: (controller) => _mapController = controller,
      polylines: {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [pickup, dropoff],
          width: 4,
          color: app_colors.primaryColor.withValues(alpha: 0.4),
          patterns: [PatternItem.dash(10), PatternItem.gap(10)],
        ),
      },
      markers: {
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildInformationOverlay(ParcelDeliveryRequest request) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        decoration: BoxDecoration(
          color: app_colors.darkSurface.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusLine(request.status),
            const SizedBox(height: 25),
            _buildDriverInfo(request),
            const SizedBox(height: 20),
            _buildRequestSummary(request),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLine(String currentStatus) {
    final statuses = ['pending', 'accepted', 'picked_up', 'delivered'];
    final currentIndex = statuses.indexOf(currentStatus);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(statuses.length, (index) {
        final isActive = index <= currentIndex;
        final isCompleted = index < currentIndex;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isActive ? app_colors.primaryColor : Colors.white10,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? app_colors.primaryColor : Colors.white24,
                    width: 2,
                  ),
                ),
                child: Center(
                  child:
                      isCompleted
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                ),
              ),
              if (index < statuses.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color:
                        isActive && (index < currentIndex)
                            ? app_colors.primaryColor
                            : Colors.white10,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDriverInfo(ParcelDeliveryRequest request) {
    if (request.driverId == null || request.driverId!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Lottie.network(
              'https://assets10.lottiefiles.com/packages/lf20_9w8vuniz.json',
              height: 40,
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Text(
                'بانتظار قبول طلبك من أحد المندوبين...',
                style: TextStyle(fontSize: 13, color: app_colors.darkSubText),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: app_colors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: app_colors.primaryColor.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: app_colors.primaryColor),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.driverName ?? 'كابتن مدار',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  request.vehicleType,
                  style: const TextStyle(
                    fontSize: 12,
                    color: app_colors.darkSubText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => launchUrl(Uri.parse('tel:${request.driverPhone}')),
            icon: const Icon(Icons.call, color: Colors.greenAccent),
            style: IconButton.styleFrom(backgroundColor: Colors.greenAccent.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSummary(ParcelDeliveryRequest request) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('المبلغ', '${request.price.toInt()} د.ع'),
          _summaryItem('المسافة', '${request.distance.toStringAsFixed(1)} كم'),
          _summaryItem('الحالة', _getStatusArabic(request.status)),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: app_colors.darkSubText),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _getStatusArabic(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'accepted':
        return 'تم القبول';
      case 'picked_up':
        return 'تم الاستلام';
      case 'delivered':
        return 'تم التوصيل';
      default:
        return 'نشط';
    }
  }
}
