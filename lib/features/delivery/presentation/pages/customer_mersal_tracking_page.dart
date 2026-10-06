import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:dalal_alqaim/models/mersal_request.dart';
import 'package:dalal_alqaim/services/mersal_service.dart';

class CustomerMersalTrackingPage extends StatefulWidget {
  final String requestId;
  final MersalRequest? initialRequest;

  const CustomerMersalTrackingPage({
    super.key,
    required this.requestId,
    this.initialRequest,
  });

  @override
  State<CustomerMersalTrackingPage> createState() => _CustomerMersalTrackingPageState();
}

class _CustomerMersalTrackingPageState extends State<CustomerMersalTrackingPage> {
  GoogleMapController? _mapController;
  final MersalService _mersalService = MersalService();

  // Markers & Polyline
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _customerIcon;
  BitmapDescriptor? _driverIcon;

  // Stream Subscriptions
  StreamSubscription<DocumentSnapshot>? _driverSub;
  LatLng? _driverPos;
  double _driverHeading = 0.0;

  // Audio Player for voice note
  VideoPlayerController? _audioPlayer;
  bool _isPlayingAudio = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

  // Modern Theme Palette
  static const Color _primaryTeal = Color(0xFF00BFA5);
  static const Color _primaryDark = Color(0xFF004D40);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);
  static const Color _borderLight = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    if (widget.initialRequest?.voiceUrl != null) {
      _initAudio(widget.initialRequest!.voiceUrl!);
    }
  }

  Future<void> _loadCustomMarkers() async {
    try {
      _customerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
      _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    } catch (_) {}
  }

  void _initAudio(String url) {
    if (url.isEmpty) return;
    try {
      _audioPlayer = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _audioDuration = _audioPlayer!.value.duration;
            });
          }
        });

      _audioPlayer!.addListener(() {
        if (!mounted) return;
        setState(() {
          _audioPosition = _audioPlayer!.value.position;
          _isPlayingAudio = _audioPlayer!.value.isPlaying;
        });
      });
    } catch (_) {}
  }

  void _listenToDriver(String? driverId, MersalRequest request) {
    if (driverId == null || driverId.isEmpty) return;
    if (_driverSub != null) return;

    _driverSub = FirebaseFirestore.instance.collection('drivers').doc(driverId).snapshots().listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data() ?? {};
      final lat = (data['latitude'] ?? data['lat']) as num?;
      final lng = (data['longitude'] ?? data['lng']) as num?;
      final heading = (data['heading'] ?? data['bearing'] ?? 0.0) as num;

      if (lat != null && lng != null) {
        final newDriverPos = LatLng(lat.toDouble(), lng.toDouble());
        setState(() {
          _driverPos = newDriverPos;
          _driverHeading = heading.toDouble();
          _updateMapElements(request);
        });
      }
    });
  }

  void _updateMapElements(MersalRequest req) {
    final Set<Marker> newMarkers = {};
    final dropoff = LatLng(req.dropoffLat, req.dropoffLng);

    // 1. Customer Marker
    newMarkers.add(
      Marker(
        markerId: const MarkerId('customer_dropoff'),
        position: dropoff,
        icon: _customerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: const InfoWindow(title: 'مكان تسليم الغراض'),
      ),
    );

    // 2. Driver Marker (if accepted and available)
    if (_driverPos != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('driver_moped'),
          position: _driverPos!,
          rotation: _driverHeading,
          icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: InfoWindow(title: req.driverName ?? 'الكابتن'),
        ),
      );

      // Route line
      _polylines = {
        Polyline(
          polylineId: const PolylineId('driver_to_customer'),
          points: [_driverPos!, dropoff],
          color: _primaryTeal,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    }

    _markers = newMarkers;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _driverSub?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: StreamBuilder<MersalRequest?>(
          stream: _mersalService.getRequestStream(widget.requestId),
          builder: (context, snapshot) {
            final request = snapshot.data ?? widget.initialRequest;

            if (request == null) {
              return const Center(child: CircularProgressIndicator(color: _primaryTeal));
            }

            if (request.driverId != null) {
              _listenToDriver(request.driverId, request);
            }

            _updateMapElements(request);

            return Stack(
              children: [
                // 1. Full Screen Interactive Map
                _buildMap(request),

                // 2. Top Header & Back Button
                _buildTopBar(request),

                // 3. Bottom Sliding Tracking Card
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildTrackingBottomCard(request),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 1. الخريطة التفاعلية الكاملة
  // ═══════════════════════════════════════════
  Widget _buildMap(MersalRequest req) {
    final customerPos = LatLng(req.dropoffLat, req.dropoffLng);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: customerPos, zoom: 16.0),
      markers: _markers,
      polylines: _polylines,
      onMapCreated: (ctrl) {
        _mapController = ctrl;
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  // ═══════════════════════════════════════════
  // 2. الشريط العلوي
  // ═══════════════════════════════════════════
  Widget _buildTopBar(MersalRequest req) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _circleButton(
              icon: Icons.arrow_forward_ios_rounded,
              onTap: () => Navigator.pop(context),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primaryTeal.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delivery_dining_rounded, color: _primaryTeal, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'تتبع طلب مرسال',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      color: _textMain,
                    ),
                  ),
                ],
              ),
            ),
            _circleButton(
              icon: Icons.center_focus_strong_rounded,
              onTap: () {
                if (_mapController != null) {
                  final target = _driverPos ?? LatLng(req.dropoffLat, req.dropoffLng);
                  _mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, 16.5));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 3. البطاقة السفلية لتتبع الطلب ومعلومات الكابتن
  // ═══════════════════════════════════════════
  Widget _buildTrackingBottomCard(MersalRequest req) {
    final hasDriver = req.driverId != null && req.driverId!.isNotEmpty;
    final isDelivered = req.status == 'delivered' || req.status == 'completed';

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.62,
      ),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // مقبض السحب
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: _borderLight,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // المحتوى القابل للتمرير
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. بطاقة الحالة الحالية التفاعلية بالعراقية
                  _buildStatusHeader(req),
                  const SizedBox(height: 14),

                  // 2. مؤشر الخطوات التفاعلي
                  _buildStepper(req.status),
                  const SizedBox(height: 16),

                  // 3. قسم معلومات الكابتن ورقم الهاتف (إذا قبل الطلب)
                  if (hasDriver) ...[
                    _buildDriverCard(req),
                    const SizedBox(height: 14),
                  ] else ...[
                    _buildSearchingDriverCard(),
                    const SizedBox(height: 14),
                  ],

                  // 4. تفاصيل الغراض المطلوبة
                  _buildOrderDetailsCard(req),
                  const SizedBox(height: 16),

                  // 5. زر إلغاء الطلب (إذا لم يتم الشراء بعد)
                  if (!isDelivered && (req.status == 'pending' || req.status == 'accepted'))
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmCancelOrder(req),
                        icon: const Icon(Icons.cancel_outlined, color: Color(0xFFE53935), size: 18),
                        label: Text(
                          'إلغاء الطلب',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: const Color(0xFFE53935),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE53935), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 4. رأس الحالة العراقي
  // ═══════════════════════════════════════════
  Widget _buildStatusHeader(MersalRequest req) {
    String title = 'جاري البحث عن كابتن قريب';
    String desc = 'طلبك معروض هسة على كل الكباتن القريبين منك';
    Color bg = const Color(0xFFFEF3C7);
    Color fg = const Color(0xFFB45309);
    IconData icon = Icons.radar_rounded;

    switch (req.status) {
      case 'accepted':
        title = 'الكابتن قبل طلبك وطاير للمحل!';
        desc = 'الكابتن ${req.driverName ??''} استلم الطلب وبطريقه للمحل';
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        icon = Icons.two_wheeler_rounded;
        break;
      case 'arrived_at_pickup':
        title = 'الكابتن وصل للمحل وجاي يشتري';
        desc = 'الكابتن متواجد بالمحل ويجمع غراضك بعناية';
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF6D28D9);
        icon = Icons.storefront_rounded;
        break;
      case 'picked_up':
      case 'on_the_way':
        title = 'الغراض جاهزة والكابتن بطريقه إلك';
        desc = 'الكابتن استلم الغراض وبالدرب لباب بيتك';
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        icon = Icons.delivery_dining_rounded;
        break;
      case 'delivered':
      case 'completed':
        title = 'عاشت إيدك! تم تسليم الغراض بنجاح';
        desc = 'بالعافية عليك! شكراً لاستخدامك خدمة مرسال القائم';
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        icon = Icons.check_circle_rounded;
        break;
      case 'cancelled':
        title = 'تم إلغاء الطلب';
        desc = 'تم إلغاء هذا الطلب بناءً على رغبتك أو عدم التوفر';
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: fg,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    color: fg.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 5. مؤشر الخطوات
  // ═══════════════════════════════════════════
  Widget _buildStepper(String status) {
    int currentStep = 1;
    switch (status) {
      case 'pending':
        currentStep = 1;
        break;
      case 'accepted':
        currentStep = 2;
        break;
      case 'arrived_at_pickup':
        currentStep = 3;
        break;
      case 'picked_up':
      case 'on_the_way':
        currentStep = 4;
        break;
      case 'delivered':
      case 'completed':
        currentStep = 5;
        break;
    }

    final steps = ['تم الإرسال', 'قبول الطلب', 'شراء الغراض', 'بالطريق', 'تم التسليم'];

    return Row(
      children: List.generate(steps.length, (idx) {
        final stepNum = idx + 1;
        final isDone = stepNum <= currentStep;
        final isLast = idx == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isDone ? _primaryTeal : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, color: Colors.white, size: 13)
                            : Text(
                                '$stepNum',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: _textSub),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[idx],
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 9,
                        fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                        color: isDone ? _primaryDark : _textSub,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 12,
                  height: 2.5,
                  margin: const EdgeInsets.only(bottom: 14),
                  color: isDone ? _primaryTeal : const Color(0xFFE2E8F0),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════
  // 6. بطاقة معلومات الكابتن ورقم الهاتف
  // ═══════════════════════════════════════════
  Widget _buildDriverCard(MersalRequest req) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderLight, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // صورة الكابتن أو أفاتار
              CircleAvatar(
                radius: 26,
                backgroundColor: _primaryTeal.withValues(alpha: 0.15),
                backgroundImage: (req.driverImage != null && req.driverImage!.isNotEmpty)
                    ? NetworkImage(req.driverImage!)
                    : null,
                child: (req.driverImage == null || req.driverImage!.isEmpty)
                    ? const Icon(Icons.person_rounded, color: _primaryTeal, size: 30)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          req.driverName ?? 'كابتن مرسال',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'كابتن موثوق',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'دراجة توصيل سريعة • كابتن مدار',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: _textSub),
                    ),
                    if (req.price != null && req.price!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'أجرة التوصيل المتفق عليها: ${req.price} د.ع',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _primaryDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // أزرار التواصل المباشر (اتصال + واتساب)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _callPhone(req.driverPhone),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 17),
                  label: Text(
                    'اتصال هاتفي',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openWhatsApp(req.driverPhone),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 17),
                  label: Text(
                    'واتساب',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingDriverCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderLight, width: 1.2),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: _primaryTeal, strokeWidth: 2.5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جاي نبحث عن كابتن قريب ...',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: _textMain,
                  ),
                ),
                Text(
                  'أول ما يقبل كابتن طلبك راح تظهر معلوماته ورقم موبايله هان مباشرة',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: _textSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 7. تفاصيل الغراض المطلوبة
  // ═══════════════════════════════════════════
  Widget _buildOrderDetailsCard(MersalRequest req) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_bulleted_rounded, color: _primaryTeal, size: 18),
              const SizedBox(width: 8),
              Text(
                'الغراض المطلوبة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: _textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            req.requestDescription.isNotEmpty ? req.requestDescription : 'موصوفة عبر البصمة الصوتية',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12.5,
              color: _textMain,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (req.storeName != null && req.storeName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.storefront_rounded, size: 15, color: _textSub),
                const SizedBox(width: 6),
                Text(
                  'المحل / المكان: ${req.storeName}',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: _textSub),
                ),
              ],
            ),
          ],
          // مشغل البصمة الصوتية إذا كانت متوفرة
          if (req.voiceUrl != null && req.voiceUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildVoicePlayer(),
          ],
        ],
      ),
    );
  }

  Widget _buildVoicePlayer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _primaryTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlayingAudio ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: _primaryTeal,
              size: 28,
            ),
            onPressed: () {
              if (_audioPlayer == null) return;
              if (_isPlayingAudio) {
                _audioPlayer!.pause();
              } else {
                _audioPlayer!.play();
              }
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بصمتك الصوتية للكابتن',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: _primaryDark,
                  ),
                ),
                Text(
                  '${_audioPosition.inSeconds}ث / ${_audioDuration.inSeconds}ث',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: _textSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('07')) clean = '964${clean.substring(1)}';
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _confirmCancelOrder(MersalRequest req) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('إلغاء الطلب؟', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: Text(
            'هل أنت متأكد من رغبتك بإلغاء طلب مرسال؟',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('لا، تراجع', style: GoogleFonts.ibmPlexSansArabic(color: _textSub)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _mersalService.cancelRequest(req.id, reason: 'تم الإلغاء من قبل الزبون');
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
              child: Text('نعم، إلغاء', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _cardBg,
        border: Border.all(color: _borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(42),
          child: Icon(icon, color: _textMain, size: 18),
        ),
      ),
    );
  }
}
