import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LiveOrdersMapPage extends StatefulWidget {
  const LiveOrdersMapPage({super.key});

  @override
  State<LiveOrdersMapPage> createState() => _LiveOrdersMapPageState();
}

class _LiveOrdersMapPageState extends State<LiveOrdersMapPage> {
  final Set<Marker> _markers = {};
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  GoogleMapController? _mapController;

  // إحداثيات مدينة القائم
  static const LatLng _kAlQaimCenter = LatLng(34.3418, 41.0775);

  StreamSubscription? _mersalSub;
  StreamSubscription? _foodSub;
  StreamSubscription? _storeSub;

  final Map<String, Marker> _mersalMarkers = {};
  final Map<String, Marker> _foodMarkers = {};
  final Map<String, Marker> _storeMarkers = {};

  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _primaryLight = Color(0xFF00BFA5);

  @override
  void initState() {
    super.initState();
    _listenToActiveDeliveryOrders();
  }

  @override
  void dispose() {
    _mersalSub?.cancel();
    _foodSub?.cancel();
    _storeSub?.cancel();
    super.dispose();
  }

  void _listenToActiveDeliveryOrders() {
    final uid = _uid;
    if (uid == null) return;

    // 1. طلبات مرسال النشطة
    _mersalSub = FirebaseFirestore.instance
        .collection('mersal_requests')
        .where('driverId', isEqualTo: uid)
        .where('status', whereIn: ['accepted', 'on_the_way', 'picked_up'])
        .snapshots()
        .listen((snapshot) {
      _mersalMarkers.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = (data['dropoffLat'] as num?)?.toDouble() ?? (data['destinationLat'] as num?)?.toDouble();
        final lng = (data['dropoffLng'] as num?)?.toDouble() ?? (data['destinationLng'] as num?)?.toDouble();

        if (lat != null && lng != null && lat != 0) {
          _mersalMarkers[doc.id] = Marker(
            markerId: MarkerId('mersal_${doc.id}'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: 'مرسال #${doc.id.substring(0, doc.id.length > 5 ? 5 : doc.id.length)}',
              snippet: data['userName'] ?? data['customerName'] ?? 'زبون مرسال',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          );
        }
      }
      _updateAllMarkers();
    });

    // 2. طلبات المطاعم النشطة
    _foodSub = FirebaseFirestore.instance
        .collection('restaurant_orders')
        .where('deliveryBoyId', isEqualTo: uid)
        .where('status', whereIn: ['accepted', 'preparing', 'ready', 'on_the_way'])
        .snapshots()
        .listen((snapshot) {
      _foodMarkers.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = (data['userLat'] as num?)?.toDouble() ?? (data['deliveryLat'] as num?)?.toDouble();
        final lng = (data['userLng'] as num?)?.toDouble() ?? (data['deliveryLng'] as num?)?.toDouble();

        if (lat != null && lng != null && lat != 0) {
          _foodMarkers[doc.id] = Marker(
            markerId: MarkerId('food_${doc.id}'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: 'وجبة طعام #${doc.id.substring(0, doc.id.length > 5 ? 5 : doc.id.length)}',
              snippet: data['restaurantName'] ?? 'مطعم',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          );
        }
      }
      _updateAllMarkers();
    });

    // 3. طلبات المتاجر النشطة
    _storeSub = FirebaseFirestore.instance
        .collection('store_orders')
        .where('deliveryBoyId', isEqualTo: uid)
        .where('status', whereIn: ['accepted', 'preparing', 'ready', 'on_the_way'])
        .snapshots()
        .listen((snapshot) {
      _storeMarkers.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = (data['userLat'] as num?)?.toDouble() ?? (data['deliveryLat'] as num?)?.toDouble();
        final lng = (data['userLng'] as num?)?.toDouble() ?? (data['deliveryLng'] as num?)?.toDouble();

        if (lat != null && lng != null && lat != 0) {
          _storeMarkers[doc.id] = Marker(
            markerId: MarkerId('store_${doc.id}'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: 'طلب متجر #${doc.id.substring(0, doc.id.length > 5 ? 5 : doc.id.length)}',
              snippet: data['storeName'] ?? 'متجر القائم',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          );
        }
      }
      _updateAllMarkers();
    });
  }

  void _updateAllMarkers() {
    if (!mounted) return;
    setState(() {
      _markers.clear();
      _markers.addAll(_mersalMarkers.values);
      _markers.addAll(_foodMarkers.values);
      _markers.addAll(_storeMarkers.values);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'خريطة وجهات التوصيل',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _textMain),
          ),
        centerTitle: true,
        backgroundColor: _cardLight,
        foregroundColor: _textMain,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: _primaryLight),
            tooltip: 'موقعي بالقائم',
            onPressed: () {
              _mapController?.animateCamera(
                CameraUpdate.newCameraPosition(
                  const CameraPosition(target: _kAlQaimCenter, zoom: 14.5),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _kAlQaimCenter,
              zoom: 13.5,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
          ),
          if (_markers.isEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.delivery_dining_rounded, color: _primaryLight, size: 26),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ماكو طلبات توصيل نشطة هسة على الخريطة \nأول ما تاخذ طلب راح ينزل عنوان الزبون هنا تلقائياً.',
                        style: TextStyle(color: _textMain, fontSize: 12.5, fontWeight: FontWeight.bold, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
}
