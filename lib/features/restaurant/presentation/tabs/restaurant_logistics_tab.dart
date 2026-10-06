import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class RestaurantLogisticsTab extends StatefulWidget {
  final String restaurantId;

  const RestaurantLogisticsTab({
    super.key,
    required this.restaurantId,
  });

  @override
  State<RestaurantLogisticsTab> createState() => _RestaurantLogisticsTabState();
}

class _RestaurantLogisticsTabState extends State<RestaurantLogisticsTab> {
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;

  // Default fallback location (Al-Qaim / Baghdad)
  LatLng _restaurantLocation = const LatLng(34.3411, 41.0805);

  @override
  void initState() {
    super.initState();
    _fetchRestaurantLocation();
  }

  Future<void> _fetchRestaurantLocation() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        double? lat = (data['latitude'] ?? data['lat'])?.toDouble();
        double? lng = (data['longitude'] ?? data['lng'])?.toDouble();

        if (lat != null && lng != null && lat != 0 && lng != 0) {
          if (mounted) {
            setState(() {
              _restaurantLocation = LatLng(lat, lng);
            });
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(_restaurantLocation, 13),
            );
          }
        }
      }
    } catch (_) {}
  }

  Color _parseZoneColor(dynamic colorValue) {
    if (colorValue is int) return Color(colorValue);
    if (colorValue is String) {
      if (colorValue == 'green') return const Color(0xFF00E676);
      if (colorValue == 'gold' || colorValue == 'amber') return app_colors.goldAccent;
      if (colorValue == 'orange') return const Color(0xFFFF7043);
      if (colorValue == 'blue') return Colors.blueAccent;
      if (colorValue == 'purple') return Colors.purpleAccent;
      if (colorValue == 'teal') return app_colors.primaryColor;
    }
    return app_colors.primaryColor;
  }

  void _showAddZoneMapModal() {
    String shapeType = 'circle'; // 'circle' or 'box'
    double radiusKm = 3.0; // Radius in KM
    double boxSizeKm = 4.0; // Box side length in KM
    LatLng zoneCenter = _restaurantLocation;

    final nameCtrl = TextEditingController(text: 'نطاق التوصيل القريب');
    final priceCtrl = TextEditingController(text: '2000');
    final timeCtrl = TextEditingController(text: '25');
    Color selectedColor = app_colors.primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? app_colors.darkCard : Colors.white;
        final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;
        final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;

        final availableColors = [
          {'name': 'فيروزي', 'color': app_colors.primaryColor},
          {'name': 'ذهبي', 'color': app_colors.goldAccent},
          {'name': 'أخضر', 'color': const Color(0xFF00E676)},
          {'name': 'برتقالي', 'color': const Color(0xFFFF7043)},
          {'name': 'أزرق', 'color': Colors.blueAccent},
          {'name': 'بنفسجي', 'color': Colors.purpleAccent},
        ];

        return StatefulBuilder(
          builder: (builderCtx, setModalState) {
            // Build dynamic circles or polygons for preview on modal map
            final previewCircles = <Circle>{
              if (shapeType == 'circle')
                Circle(
                  circleId: const CircleId('preview_zone_circle'),
                  center: zoneCenter,
                  radius: radiusKm * 1000,
                  fillColor: selectedColor.withValues(alpha: 0.22),
                  strokeColor: selectedColor,
                  strokeWidth: 2,
                ),
            };

            final previewPolygons = <Polygon>{
              if (shapeType == 'box')
                Polygon(
                  polygonId: const PolygonId('preview_zone_box'),
                  points: _generateSquarePoints(zoneCenter, boxSizeKm),
                  fillColor: selectedColor.withValues(alpha: 0.22),
                  strokeColor: selectedColor,
                  strokeWidth: 2,
                ),
            };

            final previewMarkers = <Marker>{
              Marker(
                markerId: const MarkerId('restaurant_center_marker'),
                position: zoneCenter,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                infoWindow: const InfoWindow(title: 'مركز المنطقة / المطعم'),
              ),
            };

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.92,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(
                    color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle Bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: app_colors.primaryColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.map_rounded, color: app_colors.primaryColor, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تحديد منطقة وأسعار التوصيل',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.5,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  'ارسم دائرة أو مربع على الخريطة وحدد سعر التوصيل لهالنطاق',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(builderCtx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 12),

                    // Modal Scrollable Content
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // 1. Shape Switcher (Circle Radius vs Box Area)
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(() => shapeType = 'circle'),
                                  borderRadius: BorderRadius.circular(14),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: shapeType == 'circle'
                                          ? app_colors.primaryColor
                                          : (isDark ? Colors.black26 : const Color(0xFFF0F5F4)),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: shapeType == 'circle' ? app_colors.primaryColor : Colors.transparent,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.radio_button_checked_rounded,
                                          color: shapeType == 'circle' ? Colors.white : textSecondary,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'نطاق دائري ⭕ (نصف قطر)',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: shapeType == 'circle' ? Colors.white : textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(() => shapeType = 'box'),
                                  borderRadius: BorderRadius.circular(14),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: shapeType == 'box'
                                          ? app_colors.primaryColor
                                          : (isDark ? Colors.black26 : const Color(0xFFF0F5F4)),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: shapeType == 'box' ? app_colors.primaryColor : Colors.transparent,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.crop_square_rounded,
                                          color: shapeType == 'box' ? Colors.white : textSecondary,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'مربع ومنطقة مخصصة',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: shapeType == 'box' ? Colors.white : textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 2. Interactive Map Preview Widget
                          Container(
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.7),
                                width: 1.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                children: [
                                  GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: zoneCenter,
                                      zoom: 12.5,
                                    ),
                                    circles: previewCircles,
                                    polygons: previewPolygons,
                                    markers: previewMarkers,
                                    mapType: _mapType,
                                    myLocationButtonEnabled: false,
                                    zoomControlsEnabled: false,
                                    onTap: (latLng) {
                                      HapticFeedback.selectionClick();
                                      setModalState(() {
                                        zoneCenter = latLng;
                                      });
                                    },
                                  ),
                                  // Prompt overlay badge
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'اضغط على أي نقطة بالخريطة لنقل مركز المنطقة',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 10.5,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 3. Distance / Area Slider
                          if (shapeType == 'circle') ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'نصف قطر الدائرة (المسافة):',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: app_colors.primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${radiusKm.toStringAsFixed(1)} كم ⭕',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: app_colors.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: radiusKm,
                              min: 0.5,
                              max: 25.0,
                              divisions: 49,
                              activeColor: app_colors.primaryColor,
                              onChanged: (val) {
                                setModalState(() => radiusKm = val);
                              },
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'حجم المربع التقديري:',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: app_colors.primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${boxSizeKm.toStringAsFixed(1)} كم ',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: app_colors.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: boxSizeKm,
                              min: 1.0,
                              max: 20.0,
                              divisions: 38,
                              activeColor: app_colors.primaryColor,
                              onChanged: (val) {
                                setModalState(() => boxSizeKm = val);
                              },
                            ),
                          ],
                          const SizedBox(height: 10),

                          // 4. Name, Price, and Estimated Time
                          TextField(
                            controller: nameCtrl,
                            style: GoogleFonts.ibmPlexSansArabic(color: textPrimary, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'اسم المنطقة / الحي',
                              hintText: 'مثال: القائم المركز، حي اليرموك، الكرابلة',
                              labelStyle: GoogleFonts.ibmPlexSansArabic(color: textSecondary, fontSize: 12),
                              prefixIcon: const Icon(Icons.location_city_rounded, color: app_colors.primaryColor, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: priceCtrl,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.ibmPlexSansArabic(color: textPrimary, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'سعر التوصيل (د.ع)',
                                    hintText: 'مثال: 2500',
                                    labelStyle: GoogleFonts.ibmPlexSansArabic(color: textSecondary, fontSize: 11.5),
                                    prefixIcon: const Icon(Icons.payments_rounded, color: app_colors.primaryColor, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: timeCtrl,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.ibmPlexSansArabic(color: textPrimary, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'وقت التوصيل (دقيقة)',
                                    hintText: 'مثال: 30',
                                    labelStyle: GoogleFonts.ibmPlexSansArabic(color: textSecondary, fontSize: 11.5),
                                    prefixIcon: const Icon(Icons.timer_rounded, color: app_colors.goldAccent, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 5. Zone Color Selector
                          Text(
                            'لون تمييز المنطقة على الخريطة',
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: availableColors.map((c) {
                              final col = c['color'] as Color;
                              final isSel = selectedColor.toARGB32() == col.toARGB32();
                              return InkWell(
                                onTap: () => setModalState(() => selectedColor = col),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: col.withValues(alpha: isSel ? 0.25 : 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSel ? col : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        c['name'] as String,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11,
                                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // 6. Save Zone Button
                          ElevatedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final name = nameCtrl.text.trim();
                              final price = int.tryParse(priceCtrl.text.trim()) ?? 2000;
                              final timeMinutes = int.tryParse(timeCtrl.text.trim()) ?? 30;

                              if (name.isEmpty) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('اكتب اسم المنطقة أولاً', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              final zoneData = <String, dynamic>{
                                'regionName': name,
                                'name': name,
                                'deliveryPrice': price,
                                'estimatedTime': '$timeMinutes دقيقة',
                                'shapeType': shapeType,
                                'radiusKm': radiusKm,
                                'boxSizeKm': boxSizeKm,
                                'centerLat': zoneCenter.latitude,
                                'centerLng': zoneCenter.longitude,
                                'colorValue': selectedColor.toARGB32(),
                                'createdAt': FieldValue.serverTimestamp(),
                              };

                              await FirebaseFirestore.instance
                                  .collection('restaurants')
                                  .doc(widget.restaurantId)
                                  .collection('delivery_zones')
                                  .add(zoneData);

                              if (builderCtx.mounted) Navigator.pop(builderCtx);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم حفظ منطقة "$name" بالخريطة بنجاح وعاشت إيدك!',
                                    style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            label: Text(
                              'حفظ وتثبيت المنطقة بالخريطة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: app_colors.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<LatLng> _generateSquarePoints(LatLng center, double sideKm) {
    const latKm = 1.0 / 111.0;
    final lngKm = 1.0 / (111.0 * 0.82);
    final half = sideKm / 2.0;

    return [
      LatLng(center.latitude + half * latKm, center.longitude - half * lngKm),
      LatLng(center.latitude + half * latKm, center.longitude + half * lngKm),
      LatLng(center.latitude - half * latKm, center.longitude + half * lngKm),
      LatLng(center.latitude - half * latKm, center.longitude - half * lngKm),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? app_colors.darkCard : Colors.white;
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;
    final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;
    final currencyFormatter = NumberFormat('#,###', 'ar_IQ');

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.restaurantId).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final isDeliveryActive = userData['isDeliveryActive'] ?? true;
        final defaultDeliveryPrice = userData['defaultDeliveryPrice'] ?? 1500;
        final minFreeDelivery = userData['minFreeDelivery'] ?? 25000;
        final avgDeliveryTime = userData['avgDeliveryTime'] ?? '30 دقيقة';

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('restaurants')
              .doc(widget.restaurantId)
              .collection('delivery_zones')
              .snapshots(),
          builder: (context, zonesSnap) {
            final zoneDocs = zonesSnap.data?.docs ?? [];

            // Generate map circles, polygons, and markers for all saved delivery zones
            final activeCircles = <Circle>{};
            final activePolygons = <Polygon>{};
            final activeMarkers = <Marker>{
              Marker(
                markerId: const MarkerId('restaurant_main_location'),
                position: _restaurantLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                infoWindow: const InfoWindow(title: 'موقع مطعمك'),
              ),
            };

            for (var doc in zoneDocs) {
              final z = doc.data() as Map<String, dynamic>;
              final zName = (z['regionName'] ?? z['name'] ?? 'منطقة').toString();
              final zPrice = z['deliveryPrice'] ?? 2000;
              final shape = z['shapeType'] ?? 'circle';
              final lat = (z['centerLat'] as num?)?.toDouble() ?? _restaurantLocation.latitude;
              final lng = (z['centerLng'] as num?)?.toDouble() ?? _restaurantLocation.longitude;
              final center = LatLng(lat, lng);
              final color = _parseZoneColor(z['colorValue']);

              if (shape == 'circle') {
                final radKm = (z['radiusKm'] as num?)?.toDouble() ?? 3.0;
                activeCircles.add(
                  Circle(
                    circleId: CircleId('zone_circle_${doc.id}'),
                    center: center,
                    radius: radKm * 1000,
                    fillColor: color.withValues(alpha: 0.18),
                    strokeColor: color,
                    strokeWidth: 2,
                  ),
                );
              } else {
                final boxKm = (z['boxSizeKm'] as num?)?.toDouble() ?? 4.0;
                activePolygons.add(
                  Polygon(
                    polygonId: PolygonId('zone_poly_${doc.id}'),
                    points: _generateSquarePoints(center, boxKm),
                    fillColor: color.withValues(alpha: 0.18),
                    strokeColor: color,
                    strokeWidth: 2,
                  ),
                );
              }

              activeMarkers.add(
                Marker(
                  markerId: MarkerId('marker_${doc.id}'),
                  position: center,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                  infoWindow: InfoWindow(
                    title: '$zName (${currencyFormatter.format(zPrice)} د.ع)',
                    snippet: 'وقت التوصيل: ${z['estimatedTime'] ?? '30 دقيقة'}',
                  ),
                ),
              );
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 10),

                  // 1. Delivery Master Toggle Card
                  _buildMasterToggleCard(isDeliveryActive),
                  const SizedBox(height: 14),

                  // 2. Interactive Delivery Map Card
                  _buildMainDeliveryMapCard(
                    activeCircles,
                    activePolygons,
                    activeMarkers,
                    zoneDocs.length,
                    cardBg,
                    textPrimary,
                    textSecondary,
                    isDark,
                  ),
                  const SizedBox(height: 16),

                  // 3. General Logistics Quick Metrics
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          title: 'السعر الافتراضي',
                          value: '${currencyFormatter.format(defaultDeliveryPrice)} د.ع',
                          icon: Icons.payments_rounded,
                          color: app_colors.primaryColor,
                          cardBg: cardBg,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInfoCard(
                          title: 'الطلب المجاني',
                          value: '${currencyFormatter.format(minFreeDelivery)} د.ع',
                          icon: Icons.card_giftcard_rounded,
                          color: app_colors.goldAccent,
                          cardBg: cardBg,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInfoCard(
                          title: 'معدل الوقت',
                          value: avgDeliveryTime,
                          icon: Icons.timer_rounded,
                          color: Colors.blueAccent,
                          cardBg: cardBg,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. Configured Delivery Zones List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.share_location_rounded, color: app_colors.primaryColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'المناطق المحددة على الخريطة (${zoneDocs.length})',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddZoneMapModal,
                        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 16),
                        label: Text(
                          'حدد منطقة بالخريطة',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: app_colors.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 5. Configured Zones List
                  if (zoneDocs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.map_outlined, size: 40, color: app_colors.primaryColor.withValues(alpha: 0.4)),
                            const SizedBox(height: 10),
                            Text(
                              'ماكو مناطق توصيل محددة على الخريطة حالياً',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'اضغط على زر (حدد منطقة بالخريطة) فوق وحدد دوائر أو مربعات لكل حي وسعره!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...zoneDocs.map((doc) {
                      final z = doc.data() as Map<String, dynamic>;
                      final zName = (z['regionName'] ?? z['name'] ?? 'منطقة مخصصة').toString();
                      final zPrice = (z['deliveryPrice'] ?? 2000) as int;
                      final zTime = (z['estimatedTime'] ?? '30 دقيقة').toString();
                      final shape = z['shapeType'] ?? 'circle';
                      final color = _parseZoneColor(z['colorValue']);
                      final radKm = z['radiusKm'];
                      final boxKm = z['boxSizeKm'];

                      final shapeDesc = shape == 'circle'
                          ? 'دائرة قطرها ${(radKm != null ? (radKm as num).toStringAsFixed(1) : "3")} كم ⭕'
                          : 'مربع حجمه ${(boxKm != null ? (boxKm as num).toStringAsFixed(1) : "4")} كم';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: color.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                shape == 'circle' ? Icons.radio_button_checked_rounded : Icons.crop_square_rounded,
                                color: color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    zName,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$shapeDesc • $zTime ',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10.5,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${currencyFormatter.format(zPrice)} د.ع',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: app_colors.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              tooltip: 'حذف المنطقة',
                              onPressed: () => _showDeleteZoneDialog(doc.id, zName),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMasterToggleCard(bool isDeliveryActive) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00796B), app_colors.primaryColor],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: app_colors.primaryColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.motorcycle_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'خدمة التوصيل والدليفري',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    color: Colors.white,
                  ),
                ),
                Text(
                  isDeliveryActive ? 'مفتوح ويستقبل طلبيات الكباتن حالياً' : 'معطل مؤقتاً',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.white38,
              value: isDeliveryActive,
              onChanged: (val) async {
                HapticFeedback.mediumImpact();
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.restaurantId)
                    .update({'isDeliveryActive': val});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDeliveryMapCard(
    Set<Circle> activeCircles,
    Set<Polygon> activePolygons,
    Set<Marker> activeMarkers,
    int zonesCount,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.explore_rounded, color: app_colors.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'خريطة ونطاقات التوصيل الحية',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _mapType == MapType.normal ? Icons.satellite_alt_rounded : Icons.map_rounded,
                      size: 20,
                      color: app_colors.primaryColor,
                    ),
                    tooltip: 'تبديل نمط الخريطة',
                    onPressed: () {
                      setState(() {
                        _mapType = _mapType == MapType.normal ? MapType.hybrid : MapType.normal;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location_rounded, size: 20, color: app_colors.primaryColor),
                    tooltip: 'التركيز على موقع المطعم',
                    onPressed: () {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(_restaurantLocation, 13),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Map Container
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.15)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _restaurantLocation,
                  zoom: 12.5,
                ),
                onMapCreated: (c) => _mapController = c,
                circles: activeCircles,
                polygons: activePolygons,
                markers: activeMarkers,
                mapType: _mapType,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10.5,
              color: textSecondary,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showDeleteZoneDialog(String docId, String zoneName) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? app_colors.darkCard : Colors.white;
        final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                'حذف منطقة التوصيل',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'متأكد تريد تحذف نطاق "$zoneName" من الخريطة؟',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'لا، رجوع',
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance
                    .collection('restaurants')
                    .doc(widget.restaurantId)
                    .collection('delivery_zones')
                    .doc(docId)
                    .delete();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم حذف المنطقة من الخريطة بنجاح',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'اي، احذفها',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
