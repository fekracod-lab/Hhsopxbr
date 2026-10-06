import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/core/utils/map_marker_utils.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/ride_chat_screen.dart';

class RideTrackingPage extends StatefulWidget {
  final String driverId;
  final String requestId;

  const RideTrackingPage({super.key, required this.driverId, required this.requestId});

  @override
  State<RideTrackingPage> createState() => _RideTrackingPageState();
}

class _RideTrackingPageState extends State<RideTrackingPage> {
  StreamSubscription<DocumentSnapshot>? _requestSub;
  StreamSubscription<DocumentSnapshot>? _driverSub;
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _requestData;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  LatLng? _currentUserLocation;
  bool _isRatingShown = false;

  @override
  void initState() {
    super.initState();
    _loadIcon();
    _getUserLocation();
    debugPrint(' RideTrackingPage: driverId=${widget.driverId}, requestId=${widget.requestId}');
    _driverSub = FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .snapshots()
        .listen((snap) {
          debugPrint(' RideTrackingPage: Driver snapshot exists=${snap.exists}, data=${snap.data()?.keys}');
          if (!snap.exists) return;
          setState(() {
            _driverData = snap.data();
            _updateDriverMarker();
          });
        });

    _requestSub = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((snap) {
          debugPrint(' [RideTrackingPage] Request Snapshot: exists=${snap.exists}, data=${snap.data()}');
          if (!snap.exists) return;
          final data = snap.data();
          if (data == null) return;
          setState(() {
            _requestData = data;
          });

          // if trip completed, show rating
          final status = (data['status'] ?? '').toString();
          if (status == 'completed' && !_isRatingShown) {
            _isRatingShown = true;
            _showRatingDialog();
          }
        });
  }

  Future<void> _loadIcon() async {
    _carIcon = await MapMarkerUtils.createTealCarMarker(scale: 1.2);
    _pickupIcon = await MapMarkerUtils.createPickupMarker(label: 'موقع الزبون');
    _dropoffIcon = await MapMarkerUtils.createDestinationMarker(label: 'موقع الوجهة');
    if (mounted) _updateDriverMarker();
  }

  void _updateDriverMarker() {
    final List<Marker> updatedMarkers = [];

    // 1. Driver marker
    if (_driverData != null) {
      final lat = (_driverData!['currentLat'] as num?)?.toDouble()
               ?? (_driverData!['lat'] as num?)?.toDouble();
      final lng = (_driverData!['currentLng'] as num?)?.toDouble()
               ?? (_driverData!['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        updatedMarkers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: LatLng(lat, lng),
            icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
            rotation: (_driverData?['heading'] as num?)?.toDouble() ?? 0,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            infoWindow: const InfoWindow(title: 'الكابتن'),
          ),
        );
      }
    }

    // 2. Pickup marker
    if (_requestData != null) {
      final pLat = (_requestData!['pickupLat'] as num?)?.toDouble();
      final pLng = (_requestData!['pickupLng'] as num?)?.toDouble();
      if (pLat != null && pLng != null && pLat != 0) {
        updatedMarkers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: LatLng(pLat, pLng),
            icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'موقع الزبون'),
          ),
        );
      }

      // 3. Dropoff marker
      final dLat = (_requestData!['dropoffLat'] as num?)?.toDouble();
      final dLng = (_requestData!['dropoffLng'] as num?)?.toDouble();
      if (dLat != null && dLng != null && dLat != 0) {
        updatedMarkers.add(
          Marker(
            markerId: const MarkerId('dropoff'),
            position: LatLng(dLat, dLng),
            icon: _dropoffIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'موقع الوجهة'),
          ),
        );
      }
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(updatedMarkers);
    });

    if (_mapController != null && updatedMarkers.isNotEmpty) {
      final driverMarker = updatedMarkers.firstWhere((m) => m.markerId.value == 'driver', orElse: () => updatedMarkers.first);
      _mapController!.animateCamera(CameraUpdate.newLatLng(driverMarker.position));
    }
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
        if (mounted) {
          setState(() {
            _currentUserLocation = LatLng(pos.latitude, pos.longitude);
          });
        }
      }
    } catch (e) {
      debugPrint(' RideTrackingPage: Error getting user location: $e');
    }
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _requestSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _cancelByUser() async {
    final reqRef = FirebaseFirestore.instance.collection('ride_requests').doc(widget.requestId);
    await reqRef.update({'status': 'cancelled_by_user', 'updatedAt': FieldValue.serverTimestamp()});
    if (_driverData != null) {
      final driverRef = FirebaseFirestore.instance.collection('drivers').doc(widget.driverId);
      await driverRef.update({
        'available': true,
        'currentRideRequestId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showRatingDialog() {
    if (!mounted) return;

    int currentRating = 5;
    final TextEditingController commentController = TextEditingController();
    Set<String> selectedTags = {};

    final positiveTags = ['سيارة نظيفة ومرتبة', 'سياقة هادئة وآمنة', 'كابتن خلوق ومحترم', 'وصل بالوقت المضبوط', 'ريحة طيبة وتبريد'];
    final negativeTags = ['ما شغل التبريد', 'السيارة وصخة', 'سياقة سريعة ومتهورة', 'تأخر الكابتن هواية', 'أسلوب مو لائق'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setState) {
            final tagsToShow = currentRating == 5 ? positiveTags : negativeTags;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'وصلت بالسلامة عيوني!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'شلون كانت رحلتك ويا الكابتن؟',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        iconSize: 45,
                        icon: Icon(
                          index < currentRating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() {
                            // Clear tags if switching between positive (5) and negative (<=4)
                            bool wasFive = currentRating == 5;
                            bool isNowFive = (index + 1) == 5;
                            if (wasFive != isNowFive) {
                              selectedTags.clear();
                            }
                            currentRating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  
                  // TAGS SECTION
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: tagsToShow.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : Colors.teal,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                          });
                        },
                        selectedColor: Colors.teal,
                        checkmarkColor: Colors.white,
                        backgroundColor: Colors.teal.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20), 
                          side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      hintText: 'اكتب تعليقك (اختياري)',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.teal, width: 2),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance.collection('ride_requests').doc(widget.requestId).update({
                            'rating': currentRating,
                            'ratingTags': selectedTags.toList(),
                            'ratingComment': commentController.text,
                          });
                          
                          final nav = Navigator.of(context);
                          if (bottomSheetContext.mounted) {
                            Navigator.pop(bottomSheetContext);
                          }
                          if (mounted) {
                            nav.pop();
                          }
                        } catch (e) {
                          debugPrint('Error saving rating: $e');
                          final nav = Navigator.of(context);
                          if (bottomSheetContext.mounted) {
                            Navigator.pop(bottomSheetContext);
                          }
                          if (mounted) {
                            nav.pop();
                          }
                        }
                      },
                      child: const Text('إرسال التقييم', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      Navigator.pop(context);
                    },
                    child: const Text('تخطي والعودة للرئيسية', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final driverName = _requestData?['driverName'] ?? _driverData?['fullName'] ?? _driverData?['name'] ?? 'كابتن (جاري التحميل...)';
    // Captain app stores car as 'driverCar' in the request
    final car = _requestData?['driverCar'] ?? 
                ((_driverData?['carType'] != null) ? '${_driverData!['carType']} ${_driverData!['carModel'] ?? ''}' : (_driverData?['car'] ?? '...'));
    
    // Plate and Color from request or driver data
    final carPlate = _requestData?['driverCarNumber'] ?? _driverData?['carNumber'] ?? _driverData?['carPlate'] ?? 'غير محدد';
    final carColor = _requestData?['driverCarColor'] ?? _driverData?['carColor'] ?? 'غير محدد';
    
    final driverPhone = _requestData?['driverPhone'] ?? _driverData?['phone'];
    final driverImage = _requestData?['driverImage'] ?? _driverData?['photoUrl'] ?? _driverData?['imageUrl'] ?? _driverData?['image'];
    final price = _requestData?['price'] ?? '0';
    final status = _requestData?['status'] ?? 'accepted';
    
    // Status Logic - handle both 'in_progress' and 'started'
    String statusText = 'الكابتن بالطريق إلك';
    Color statusColor = Colors.blueAccent;
    if (status == 'arrived') {
      statusText = 'الكابتن وصل يَمك';
      statusColor = Colors.greenAccent;
    } else if (status == 'in_progress' || status == 'started') {
      statusText = 'الرحلة مبلشة وتوصل بالسلامة';
      statusColor = Colors.orangeAccent;
    }

    // Determine initial camera target
    final LatLng cameraTarget;
    if (_markers.isNotEmpty) {
      cameraTarget = _markers.first.position;
    } else if (_currentUserLocation != null) {
      cameraTarget = _currentUserLocation!;
    } else {
      cameraTarget = const LatLng(34.45, 41.0); // Default fallback (Al-Qa'im area)
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            // MAP - always show, use user location as fallback
            GoogleMap(
              initialCameraPosition: CameraPosition(target: cameraTarget, zoom: 16, tilt: 0, bearing: 0),
              mapType: MapType.normal,
              buildingsEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              onMapCreated: (c) => _mapController = c,
              markers: _markers,
              myLocationEnabled: _currentUserLocation != null,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
            ),

            // Loading indicator when driver data not yet available
            if (_driverData == null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('جاي نحمل بيانات الكابتن...', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),

            // BOTTOM DRIVER PANEL
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2124).withValues(alpha: 0.85),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 20),
                        
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Driver Info
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.teal, Colors.tealAccent])),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: const Color(0xFF1E2124),
                                backgroundImage: (driverImage != null && driverImage.toString().isNotEmpty) 
                                    ? NetworkImage(driverImage.toString()) 
                                    : null,
                                child: (driverImage == null || driverImage.toString().isEmpty) 
                                    ? const Icon(Icons.person_rounded, color: Colors.teal, size: 30)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(driverName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Row(
                                    children: [
                                      Text(car, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                      const SizedBox(width: 8),
                                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      Text(carColor, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text(carPlate, style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Chat Button
                            GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => RideChatScreen(
                                  rideId: widget.requestId,
                                  peerName: driverName,
                                  peerId: widget.driverId,
                                  peerImage: driverImage,
                                  peerPhone: driverPhone,
                                )));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.teal.withValues(alpha: 0.5)),
                                ),
                                child: const Icon(Icons.chat_bubble_rounded, color: Colors.teal, size: 22),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Call Button
                            GestureDetector(
                              onTap: () => _makeCall(driverPhone),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
                                ),
                                child: const Icon(Icons.phone_rounded, color: Colors.blueAccent, size: 22),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 10),

                        // Price & Safety Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('التكلفة التقريبية', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                Text('$price د.ع', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            
                            // SOS Button
                            ElevatedButton.icon(
                              onPressed: () {
                                // Implement SOS logic
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري الاتصال بالطوارئ...')));
                              },
                              icon: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                              label: const Text('أمان', style: TextStyle(color: Colors.white, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(color: Colors.redAccent, width: 0.5),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        
                        // Cancel Button (Only if not in progress)
                        if (status != 'in_progress' && status != 'completed')
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _cancelByUser,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('إلغاء الرحلة', style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
