import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../../services/complaints_service.dart';
import '../../widgets/complaint_marker_helper.dart';
import '../../widgets/complaint_card.dart';
import '../../widgets/complaint_details_sheet.dart';
import '../../widgets/complaint_add_sheet.dart';
import '../../widgets/skozme_civic_assistant_card.dart';

class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({super.key});

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final ComplaintsService _service = ComplaintsService();
  GoogleMapController? _mapController;

  LatLng _currentCenter = const LatLng(33.3152, 44.3661); // Baghdad / Iraq center
  String _selectedCategory = 'الكل';
  String _selectedGovernorate = 'كل العراق';
  String _searchQuery = '';
  Map<String, dynamic>? _selectedComplaintData;
  String? _selectedComplaintId;
  bool _isAdmin = false;
  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _isLocating = false;

  final List<String> _categories = [
    'الكل',
    'حفرة وتخسف بالشارع',
    'ماء فايض وكسر بوري',
    'وايرات كهرباء ومحولات',
    'انسداد مجاري وفتحات',
    'تراكم نفايات وأوساخ',
    'إنارة شوارع طافية',
    'تم الحل',
  ];

  static const List<String> _iraqGovernorates = [
    'كل العراق',
    'بغداد',
    'الأنبار',
    'البصرة',
    'أربيل',
    'نينوى (الموصل)',
    'كركوك',
    'كربلاء المقدسة',
    'النجف الأشرف',
    'بابل (الحلة)',
    'ديالى',
    'صلاح الدين',
    'واسط',
    'ميسان',
    'ذي قار',
    'المثنى',
    'الديوانية',
    'دهوك',
    'السليمانية',
  ];

  static const Map<String, LatLng> _governorateCenters = {
    'كل العراق': LatLng(33.3152, 44.3661),
    'بغداد': LatLng(33.3152, 44.3661),
    'الأنبار': LatLng(33.4200, 43.3000),
    'البصرة': LatLng(30.5081, 47.7835),
    'أربيل': LatLng(36.1911, 44.0092),
    'نينوى (الموصل)': LatLng(36.3400, 43.1300),
    'كركوك': LatLng(35.4681, 44.3922),
    'كربلاء المقدسة': LatLng(32.6160, 44.0249),
    'النجف الأشرف': LatLng(31.9996, 44.3266),
    'بابل (الحلة)': LatLng(32.4880, 44.4310),
    'ديالى': LatLng(33.7483, 44.6496),
    'صلاح الدين': LatLng(34.6062, 43.6793),
    'واسط': LatLng(32.5126, 45.8197),
    'ميسان': LatLng(31.8443, 47.1432),
    'ذي قار': LatLng(31.0579, 46.2573),
    'المثنى': LatLng(31.3242, 45.2808),
    'الديوانية': LatLng(31.9929, 44.9250),
    'دهوك': LatLng(36.8679, 42.9902),
    'السليمانية': LatLng(35.5669, 45.4167),
  };

  static String _normalize(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase()
        .trim();
  }

  Future<void> _prepareMarkers(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    bool needsSetState = false;
    for (var doc in docs) {
      final data = doc.data();
      final cat = data['category']?.toString() ?? 'أخرى';
      final status = data['status']?.toString() ?? 'pending';
      final key = '$cat-$status';

      if (!_markerIcons.containsKey(key)) {
        final icon = await ComplaintMarkerHelper.createCustomSquareMarker(category: cat, status: status);
        _markerIcons[key] = icon;
        needsSetState = true;
      }
    }
    if (needsSetState && mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
    _locateUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _checkAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['role'] == 'admin' || data['role'] == 'complaints_admin' || data['isAdmin'] == true) {
            setState(() => _isAdmin = true);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _locateUser({bool showFeedback = false}) async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'خدمة الموقع (GPS) غير مفعلة.. يرجى تفعيلها من إعدادات جهازك',
                style: TextStyle(),
              ),
              backgroundColor: Colors.orange.shade800,
              action: SnackBarAction(
                label: 'الإعدادات',
                textColor: Colors.white,
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'إذن الموقع مرفوض.. يرجى السماح به من إعدادات التطبيق',
                style: TextStyle(),
              ),
              backgroundColor: Colors.red.shade700,
              action: SnackBarAction(
                label: 'الإعدادات',
                textColor: Colors.white,
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // 1. Fast warm-up using last known position
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted) {
          final target = LatLng(lastPos.latitude, lastPos.longitude);
          setState(() => _currentCenter = target);
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.0));
        }

        // 2. Accurate live GPS fix
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 15),
        );

        final target = LatLng(position.latitude, position.longitude);
        if (mounted) {
          setState(() => _currentCenter = target);
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.5));
          if (showFeedback) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تحديد موقعك الحالي بدقة عالية ', style: TextStyle()),
                backgroundColor: Color(0xFF10B981),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر جلب الموقع بدقة: $e', style: const TextStyle()),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _onGovernorateSelected(String gov) {
    setState(() {
      _selectedGovernorate = gov;
    });

    final target = _governorateCenters[gov] ?? const LatLng(33.3152, 44.3661);
    final zoom = (gov == 'كل العراق') ? 6.5 : 11.5;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF07181A) : const Color(0xFFF6F8FB),
        appBar: _buildAppBar(isDark),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            // Tab 0: خريطة عين مدار الحية (Interactive Map View)
            _buildInteractiveMapView(isDark),

            // Tab 1: قائمة البلاغات (List Feed View)
            _buildComplaintsFeedView(isDark),

            // Tab 2: بلاغاتي وإشعاراتي (My Reports View)
            _buildMyReportsView(isDark),

            // Tab 3: سكوزمي البلدي (Skozme Civic AI Assistant)
            _buildSkozmeCivicTab(isDark),
          ],
        ),

        // ── القائمة السفلية المرتبة (Bottom Navigation Bar) ──
        bottomNavigationBar: _buildBottomNavigationBar(isDark),

        // ── زر إضافة بلاغ مصمم بفخامة (Floating Action Button) ──
        floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
            ? _buildAddComplaintFloatingButton(isDark)
            : null,
      ),
    );
  }

  // ── زر إضافة بلاغ الفاخر ──
  Widget _buildAddComplaintFloatingButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddComplaintSheet(isDark),
          borderRadius: BorderRadius.circular(28.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 20),
                ),
                SizedBox(width: 8.w),
                Text(
                  'سجّل بلاغ بالشارع',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Top App Bar ──
  PreferredSizeWidget _buildAppBar(bool isDark) {
    String title = 'عين مدار - بلاغات العراق 🇮🇶';
    String subtitle = 'خريطة البلاغات الحية ومتابعة شكاوى الشوارع والخدمات';

    if (_currentIndex == 1) {
      title = 'قائمة البلاغات والشكاوى';
      subtitle = 'تصفح كافة بلاغات الحفر، المجاري، والكهرباء بالعراق';
    } else if (_currentIndex == 2) {
      title = 'بلاغاتي ومتابعة حالتها';
      subtitle = 'متابعة البلاغات التي قمت برفعها وتحديثات البلدية';
    } else if (_currentIndex == 3) {
      title = 'سكوزمي - المستشار البلدي';
      subtitle = 'توجيه البلاغ للدوائر المختصة ونصائح التوثيق';
    }

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0C2428) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDark ? Colors.white : const Color(0xFF0A2828),
          size: 19.r,
        ),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5.sp,
                    color: isDark ? Colors.white : const Color(0xFF0A2828),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                decoration: BoxDecoration(
                  color: app_colors.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  _selectedGovernorate == 'كل العراق' ? '🇮🇶 كل العراق' : _selectedGovernorate,
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.bold,
                    color: app_colors.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5.sp,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
      actions: [
        if (_currentIndex == 0)
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: app_colors.primaryColor),
            tooltip: 'موقعي الحالي',
            onPressed: () => _locateUser(showFeedback: true),
          ),
        if (_currentIndex == 0 || _currentIndex == 1)
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: app_colors.primaryColor),
            tooltip: 'تسجيل بلاغ جديد',
            onPressed: () => _showAddComplaintSheet(isDark),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          height: 1,
        ),
      ),
    );
  }

  // ── Bottom Navigation Bar (خريطة، قائمة، بلاغاتي، سكوزمي) ──
  Widget _buildBottomNavigationBar(bool isDark) {
    final items = [
      {'icon': Icons.map_outlined, 'activeIcon': Icons.map_rounded, 'label': 'الخريطة'},
      {'icon': Icons.format_list_bulleted_rounded, 'activeIcon': Icons.format_list_bulleted_rounded, 'label': 'البلاغات'},
      {'icon': Icons.person_pin_circle_outlined, 'activeIcon': Icons.person_pin_circle_rounded, 'label': 'بلاغاتي'},
      {'icon': Icons.smart_toy_outlined, 'activeIcon': Icons.smart_toy_rounded, 'label': 'سكوزمي'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A2024) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 60.h,
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          child: Row(
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isSelected = _currentIndex == idx;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _currentIndex = idx);
                  },
                  borderRadius: BorderRadius.circular(14.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? app_colors.primaryColor.withValues(alpha: isDark ? 0.2 : 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected ? item['activeIcon'] as IconData : item['icon'] as IconData,
                          size: 20.sp,
                          color: isSelected ? app_colors.primaryColor : (isDark ? Colors.white54 : Colors.grey.shade500),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? app_colors.primaryColor : (isDark ? Colors.white60 : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Location & Governorate Filter Bar ──
  Widget _buildGovernorateFilterBar(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _iraqGovernorates.map((gov) {
          final isSelected = _selectedGovernorate == gov;
          return Padding(
            padding: EdgeInsets.only(left: 6.w),
            child: FilterChip(
              label: Text(gov == 'كل العراق' ? '🇮🇶 كل العراق' : gov),
              selected: isSelected,
              onSelected: (_) => _onGovernorateSelected(gov),
              selectedColor: const Color(0xFF10B981),
              backgroundColor: isDark ? const Color(0xFF10282C) : Colors.white,
              labelStyle: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Category Chips Filter ──
  Widget _buildCategoryChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          final emoji = ComplaintMarkerHelper.getCategoryEmoji(cat);
          return Padding(
            padding: EdgeInsets.only(left: 6.w),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cat != 'الكل') ...[
                    Icon(
                      ComplaintMarkerHelper.getCategoryIcon(cat, ''),
                      size: 13.sp,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    SizedBox(width: 4.w),
                  ],
                  Text(cat),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategory = cat),
              selectedColor: app_colors.primaryColor,
              backgroundColor: isDark ? const Color(0xFF10282C) : Colors.white,
              labelStyle: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
              side: BorderSide(
                color: isSelected ? app_colors.primaryColor : (isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Tab 0: Interactive Google Map View (خريطة عين مدار) ──
  Widget _buildInteractiveMapView(bool isDark) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('complaints').snapshots(),
      builder: (context, snapshot) {
        var docs = snapshot.data?.docs ?? [];

        // 1. Filter Category
        if (_selectedCategory == 'تم الحل') {
          docs = docs.where((d) => d.data()['status'] == 'resolved').toList();
        } else if (_selectedCategory != 'الكل') {
          docs = docs.where((d) => d.data()['category'] == _selectedCategory).toList();
        }

        // 2. Filter Governorate on Map if specific governorate selected
        if (_selectedGovernorate != 'كل العراق') {
          final govClean = _selectedGovernorate
              .replaceAll(' (الموصل)', '')
              .replaceAll(' (الحلة)', '')
              .replaceAll('المقدسة', '')
              .replaceAll('الأشرف', '');
          final govQuery = _normalize(govClean);

          docs = docs.where((d) {
            final data = d.data();
            final gov = _normalize((data['governorate'] ?? '').toString());
            final city = _normalize((data['city'] ?? '').toString());
            final loc = _normalize((data['locationName'] ?? '').toString());
            final desc = _normalize((data['description'] ?? '').toString());
            return gov.contains(govQuery) || city.contains(govQuery) || loc.contains(govQuery) || desc.contains(govQuery);
          }).toList();
        }

        _prepareMarkers(docs);

        // Build Google Map Markers with custom square badge icons
        Set<Marker> markers = {};
        for (var doc in docs) {
          final data = doc.data();
          final docId = doc.id;
          final lat = (data['latitude'] is num) ? (data['latitude'] as num).toDouble() : null;
          final lng = (data['longitude'] is num) ? (data['longitude'] as num).toDouble() : null;

          if (lat != null && lng != null) {
            final cat = data['category']?.toString() ?? 'أخرى';
            final status = data['status']?.toString() ?? 'pending';
            final key = '$cat-$status';
            final title = data['title']?.toString() ?? 'بلاغ';
            final locationName = data['locationName']?.toString() ?? data['city']?.toString() ?? '';

            final icon = _markerIcons[key] ?? BitmapDescriptor.defaultMarker;

            markers.add(
              Marker(
                markerId: MarkerId(docId),
                position: LatLng(lat, lng),
                icon: icon,
                infoWindow: InfoWindow(
                  title: '$title ',
                  snippet: locationName.isNotEmpty ? locationName : 'اضغط للمعاينة الكاملة',
                  onTap: () {
                    setState(() {
                      _selectedComplaintData = data;
                      _selectedComplaintId = docId;
                    });
                  },
                ),
                onTap: () {
                  setState(() {
                    _selectedComplaintData = data;
                    _selectedComplaintId = docId;
                  });
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLng(LatLng(lat, lng)),
                  );
                },
              ),
            );
          }
        }

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentCenter,
                zoom: 13.5,
              ),
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                _locateUser();
              },
              markers: markers,
              onTap: (_) {
                setState(() {
                  _selectedComplaintData = null;
                  _selectedComplaintId = null;
                });
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
            ),

            // ── Floating Governorate & Category Filters at Top of Map ──
            Positioned(
              top: 10.h,
              left: 10.w,
              right: 10.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGovernorateFilterBar(isDark),
                  SizedBox(height: 6.h),
                  _buildCategoryChips(isDark),
                ],
              ),
            ),

            // ── Floating Live GPS My Location Button ──
            Positioned(
              bottom: _selectedComplaintData != null ? 180.h : 20.h,
              left: 16.w,
              child: GestureDetector(
                onTap: () => _locateUser(showFeedback: true),
                child: Container(
                  width: 48.r,
                  height: 48.r,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0C2428) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: app_colors.primaryColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: app_colors.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLocating
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: app_colors.primaryColor,
                          ),
                        )
                      : const Icon(
                          Icons.my_location_rounded,
                          color: app_colors.primaryColor,
                          size: 24,
                        ),
                ),
              ),
            ),

            // ── Bottom Floating Selected Issue Preview Card ──
            if (_selectedComplaintData != null && _selectedComplaintId != null)
              Positioned(
                bottom: 20.h,
                left: 14.w,
                right: 14.w,
                child: _buildBottomMapPreviewCard(
                  data: _selectedComplaintData!,
                  docId: _selectedComplaintId!,
                  isDark: isDark,
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteFromMap(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0C2428) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8.w),
            const Text(
              'حذف هذا البلاغ؟',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'متأكد تريد تحذف هذا البلاغ نهائياً من الخريطة؟',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text('نعم، احذف', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteComplaint(docId);
        if (!mounted) return;
        setState(() {
          _selectedComplaintData = null;
          _selectedComplaintId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف البلاغ بنجاح', style: TextStyle()),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الحذف: $e', style: const TextStyle()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── Bottom Floating Issue Card for Map ──
  Widget _buildBottomMapPreviewCard({
    required Map<String, dynamic> data,
    required String docId,
    required bool isDark,
  }) {
    final title = data['title']?.toString() ?? 'بلاغ بالشارع';
    final category = data['category']?.toString() ?? 'أخرى';
    final status = data['status']?.toString() ?? 'pending';
    final locationName = data['locationName']?.toString() ?? '';
    final cityName = data['city']?.toString() ?? '';
    final governorate = data['governorate']?.toString() ?? 'الأنبار';
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final upvotesCount = data['upvotesCount'] ?? 0;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId != null && data['userId'] == currentUserId;

    final catColor = ComplaintMarkerHelper.getCategoryColor(category, status);
    final catEmoji = ComplaintMarkerHelper.getCategoryEmoji(category);
    final statusLabel = ComplaintMarkerHelper.getStatusLabel(status);
    final statusColor = ComplaintMarkerHelper.getStatusColor(status);

    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C2428) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: catColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      ComplaintMarkerHelper.getCategoryIcon(category, status),
                      size: 13.sp,
                      color: catColor,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      category,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5.sp,
                        color: catColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10.sp,
                    color: statusColor,
                  ),
                ),
              ),
              if (isOwner || _isAdmin) ...[
                SizedBox(width: 4.w),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  tooltip: 'حذف البلاغ',
                  onPressed: () => _confirmDeleteFromMap(docId),
                ),
              ],
              SizedBox(width: 4.w),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedComplaintData = null;
                    _selectedComplaintId = null;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 6.h),

          Row(
            children: [
              if (imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: Image.network(
                    imageUrl,
                    width: 55.r,
                    height: 55.r,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 10.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                        color: isDark ? Colors.white : const Color(0xFF0C2428),
                      ),
                    ),
                    Text(
                      locationName.isNotEmpty
                          ? '$locationName • ${cityName.isNotEmpty ? cityName : governorate} '
                          : '${cityName.isNotEmpty ? cityName : governorate} ',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          Row(
            children: [
              // Upvote Button
              InkWell(
                onTap: () => _service.toggleUpvote(docId),
                borderRadius: BorderRadius.circular(10.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: app_colors.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.thumb_up_rounded, size: 13, color: app_colors.primaryColor),
                      SizedBox(width: 4.w),
                      Text(
                        'أؤيد ($upvotesCount)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5.sp,
                          color: app_colors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ComplaintDetailsSheet(
                      data: data,
                      docId: docId,
                      isDark: isDark,
                      isAdmin: _isAdmin,
                    ),
                  );
                },
                icon: const Icon(Icons.read_more_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'تفاصيل وتحديثات',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: app_colors.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Feed List View (قائمة البلاغات المنظمة) ──
  Widget _buildComplaintsFeedView(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 80.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          Container(
            height: 46.h,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D282D) : Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              cursorColor: app_colors.primaryColor,
              style: TextStyle(fontSize: 12.5.sp, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'ابحث عن حفرة، ماء فايض، مجاري، حي الجمعية، المنصور...',
                hintStyle: TextStyle(fontSize: 11.5.sp, color: isDark ? Colors.white54 : Colors.black45),
                prefixIcon: const Icon(Icons.search_rounded, color: app_colors.primaryColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
          SizedBox(height: 10.h),

          // ── فلتر المحافظات بالعراق 🇮🇶 ──
          _buildGovernorateFilterBar(isDark),
          SizedBox(height: 8.h),

          // ── فلتر التصنيفات ──
          _buildCategoryChips(isDark),
          SizedBox(height: 12.h),

          // Feed Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedGovernorate == 'كل العراق'
                    ? 'أحدث البلاغات في كل العراق 🇮🇶'
                    : 'بلاغات $_selectedGovernorate',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5.sp,
                  color: isDark ? Colors.white : const Color(0xFF0A2828),
                ),
              ),
              Text(
                'توثيق ومتابعة حية',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Complaints Stream
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _service.getComplaintsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: app_colors.primaryColor),
                  ),
                );
              }

              var docs = snapshot.data?.docs ?? [];

              // 1. Filter Category
              if (_selectedCategory == 'تم الحل') {
                docs = docs.where((d) => d.data()['status'] == 'resolved').toList();
              } else if (_selectedCategory != 'الكل') {
                docs = docs.where((d) => d.data()['category'] == _selectedCategory).toList();
              }

              // 2. Filter Governorate
              if (_selectedGovernorate != 'كل العراق') {
                final govClean = _selectedGovernorate
                    .replaceAll(' (الموصل)', '')
                    .replaceAll(' (الحلة)', '')
                    .replaceAll('المقدسة', '')
                    .replaceAll('الأشرف', '');
                final govQuery = _normalize(govClean);

                docs = docs.where((d) {
                  final data = d.data();
                  final gov = _normalize((data['governorate'] ?? '').toString());
                  final city = _normalize((data['city'] ?? '').toString());
                  final loc = _normalize((data['locationName'] ?? '').toString());
                  final desc = _normalize((data['description'] ?? '').toString());
                  final title = _normalize((data['title'] ?? '').toString());
                  return gov.contains(govQuery) || city.contains(govQuery) || loc.contains(govQuery) || desc.contains(govQuery) || title.contains(govQuery);
                }).toList();
              }

              // 3. Filter Search Query
              if (_searchQuery.isNotEmpty) {
                final q = _normalize(_searchQuery);
                docs = docs.where((d) {
                  final data = d.data();
                  final title = _normalize((data['title'] ?? '').toString());
                  final desc = _normalize((data['description'] ?? '').toString());
                  final loc = _normalize((data['locationName'] ?? '').toString());
                  final city = _normalize((data['city'] ?? '').toString());
                  final gov = _normalize((data['governorate'] ?? '').toString());
                  return title.contains(q) || desc.contains(q) || loc.contains(q) || city.contains(q) || gov.contains(q);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.r),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 54.r, color: const Color(0xFF10B981)),
                        SizedBox(height: 12.h),
                        Text(
                          'ماكو بلاغات مسجلة مطابقة للبحث أو المحافظة',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5.sp, color: isDark ? Colors.white : Colors.black87),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'جرب تختار (كل العراق) أو وثّق مشكلة جديدة بالشارع',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.sp, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  return ComplaintCard(
                    data: data,
                    docId: doc.id,
                    isDark: isDark,
                    isAdmin: _isAdmin,
                    onDelete: () => setState(() {}),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => ComplaintDetailsSheet(
                          data: data,
                          docId: doc.id,
                          isDark: isDark,
                          isAdmin: _isAdmin,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Tab 2: بلاغاتي (My Reports View) ──
  Widget _buildMyReportsView(bool isDark) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person_rounded, size: 64.r, color: app_colors.primaryColor),
              SizedBox(height: 16.h),
              Text(
                'سجل دخولك أولاً يا غالي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: isDark ? Colors.white : Colors.black87),
              ),
              SizedBox(height: 8.h),
              Text(
                'حتى تكدر تشوف بلاغاتك وتتابع معالجتها من قبل الدوائر والبلدية',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white60 : Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.getMyComplaintsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: app_colors.primaryColor));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.r),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in_outlined, size: 64.r, color: app_colors.primaryColor.withValues(alpha: 0.5)),
                  SizedBox(height: 16.h),
                  Text(
                    'ما عندك أي بلاغ مسجل حالياً',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp, color: isDark ? Colors.white : Colors.black87),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'إذا شفت حفرة أو ماء فايض أو كهرباء مكسورة، صورها وسجل بلاغك هسة!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5.sp, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton.icon(
                    onPressed: () => _showAddComplaintSheet(isDark),
                    icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
                    label: const Text('تسجيل بلاغ جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 80.h),
          itemCount: docs.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return ComplaintCard(
              data: data,
              docId: doc.id,
              isDark: isDark,
              isAdmin: _isAdmin,
              onDelete: () => setState(() {}),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ComplaintDetailsSheet(
                    data: data,
                    docId: doc.id,
                    isDark: isDark,
                    isAdmin: _isAdmin,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Tab 3: سكوزمي البلدي ──
  Widget _buildSkozmeCivicTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 80.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkozmeCivicAssistantCard(
            isDark: isDark,
            onQuickSelectCategory: (c) => setState(() {
              _selectedCategory = c;
              _currentIndex = 1; // Switch to list feed
            }),
          ),
          SizedBox(height: 16.h),
          Text(
            'أرقام الطوارئ والشكاوى الخدمية بالعراق',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.5.sp,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 10.h),
          _buildCivicHotline('البلدية والخدمات العامة', '151', isDark),
          SizedBox(height: 6.h),
          _buildCivicHotline('طوارئ الكهرباء والصيانة', '159', isDark),
          SizedBox(height: 6.h),
          _buildCivicHotline('طوارئ الماء والمجاري', '155', isDark),
          SizedBox(height: 6.h),
          _buildCivicHotline('الدفاع المدني والإطفاء', '115', isDark),
        ],
      ),
    );
  }

  Widget _buildCivicHotline(String title, String phone, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10282C) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: app_colors.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              phone,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
                color: app_colors.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Sheet: Add Complaint ──
  void _showAddComplaintSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComplaintAddSheet(
        isDark: isDark,
        initialPosition: _currentCenter,
      ),
    );
  }
}
