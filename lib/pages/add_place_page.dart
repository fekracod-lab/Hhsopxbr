import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:dalal_alqaim/core/location_permission_helper.dart'; // Added helper import

class AddPlacePage extends StatefulWidget {
  final String? editId;
  final Map<String, dynamic>? initialData;

  const AddPlacePage({super.key, this.editId, this.initialData});

  @override
  State<AddPlacePage> createState() => _AddPlacePageState();
}

class _AddPlacePageState extends State<AddPlacePage> {
  // وحدات التحكم بالنصوص
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _googleCoordsController = TextEditingController();

  GoogleMapController? _mapController;

  // المتغيرات
  String _selectedType = 'mosque';
  LatLng? _selectedLocation;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isLoadingLocation = false;
  bool _isSatelliteMode = false;

  bool _isLoadingGovernorates = true;

  // المحافظات
  List<Map<String, dynamic>> _governorates = [];
  String? _selectedGovernorateId;
  String? _selectedGovernorateName;

  // المناطق
  List<Map<String, dynamic>> _regions = [];
  String? _selectedRegionId;
  String? _selectedRegionName;
  bool _isLoadingRegions = false;

  // ============================================================================
  // الألوان والتصميم
  // ============================================================================
  static const Color primaryColor = Color(0xFF00897B); // لون أغمق قليلاً للمسة احترافية
  static const Color accentColor = Color(0xFF26A69A);

  // الوضع الداكن والفاتح
  static const Color lightBg = Color(0xFFF5F7FA);
  static const Color darkBg = Color(0xFF101D25);
  static const Color lightCard = Colors.white;
  static const Color darkCard = Color(0xFF232D36);

  // ============================================================================
  // قائمة أنواع الأماكن
  // ============================================================================
  final List<Map<String, dynamic>> placeTypes = [
    {'key': 'mosque', 'label': 'مسجد / جامع', 'icon': Icons.mosque},
    {'key': 'restaurant', 'label': 'مطعم', 'icon': Icons.restaurant},
    {'key': 'cafe', 'label': 'مقهى', 'icon': Icons.local_cafe},
    {'key': 'hospital', 'label': 'مستشفى', 'icon': Icons.local_hospital},
    {'key': 'pharmacy', 'label': 'صيدلية', 'icon': Icons.local_pharmacy},
    {'key': 'school', 'label': 'مدرسة', 'icon': Icons.school},
    {'key': 'university', 'label': 'جامعة / كلية', 'icon': Icons.account_balance},
    {'key': 'market', 'label': 'سوق / مول', 'icon': Icons.shopping_cart},
    {'key': 'supermarket', 'label': 'سوبر ماركت', 'icon': Icons.local_grocery_store},
    {'key': 'park', 'label': 'حديقة / متنزه', 'icon': Icons.park},
    {'key': 'gym', 'label': 'نادي رياضي', 'icon': Icons.fitness_center},
    {'key': 'hotel', 'label': 'فندق', 'icon': Icons.hotel},
    {'key': 'bank', 'label': 'بنك / صراف', 'icon': Icons.attach_money},
    {'key': 'gas_station', 'label': 'محطة وقود', 'icon': Icons.local_gas_station},
    {'key': 'mechanic', 'label': 'تصليح سيارات', 'icon': Icons.car_repair},
    {'key': 'parking', 'label': 'موقف سيارات', 'icon': Icons.local_parking},
    {'key': 'police', 'label': 'مركز شرطة', 'icon': Icons.local_police},
    {'key': 'government', 'label': 'دائرة حكومية', 'icon': Icons.location_city},
    {'key': 'stadium', 'label': 'ملعب', 'icon': Icons.sports_soccer},
  ];

  @override
  void initState() {
    super.initState();
    // تحميل البيانات الأولية في حال التعديل
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _selectedType = widget.initialData!['type'] ?? 'mosque';
      final lat = (widget.initialData!['lat'] as num?)?.toDouble() ?? 33.3152;
      final lng = (widget.initialData!['lng'] as num?)?.toDouble() ?? 44.3661;
      _selectedLocation = LatLng(lat, lng);
    } else {
      // موقع افتراضي (العراق)
      _selectedLocation = const LatLng(33.3152, 44.3661);
    }

    _fetchGovernorates();

    // تحديث النصوص بناءً على الموقع
    _updateControllersFromLocation();

    // تحريك الخريطة بعد بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedLocation != null) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedLocation!));
      }
    });
  }

  Future<void> _fetchGovernorates() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('governorates')
              .where('isActive', isEqualTo: true)
              .orderBy('name')
              .get();

      final list = snap.docs.map((d) => {'id': d.id, 'name': d.data()['name'] ?? ''}).toList();

      setState(() {
        _governorates = list;
        _isLoadingGovernorates = false;

        // تعيين القيمة الأولية عند التعديل
        if (widget.initialData != null && widget.initialData!['governorateId'] != null) {
          _selectedGovernorateId = widget.initialData!['governorateId'];
          _selectedGovernorateName = widget.initialData!['governorateName'];
          _fetchRegions(_selectedGovernorateId!, isInitial: true);
        }
      });
    } catch (e) {
      debugPrint('Error fetching governorates: $e');
      if (mounted) {
        setState(() => _isLoadingGovernorates = false);
      }
    }
  }

  Future<void> _fetchRegions(String govId, {bool isInitial = false}) async {
    if (!isInitial) {
      setState(() {
        _isLoadingRegions = true;
        _regions = [];
        _selectedRegionId = null;
        _selectedRegionName = null;
      });
    } else {
      setState(() => _isLoadingRegions = true);
    }

    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('governorates')
              .doc(govId)
              .collection('regions')
              .where('isActive', isEqualTo: true)
              .orderBy('name')
              .get();

      final list = snap.docs.map((d) => {'id': d.id, 'name': d.data()['name'] ?? ''}).toList();

      setState(() {
        _regions = list;
        _isLoadingRegions = false;

        // تعيين القيمة الأولية عند التعديل
        if (isInitial && widget.initialData != null && widget.initialData!['regionId'] != null) {
          _selectedRegionId = widget.initialData!['regionId'];
          _selectedRegionName = widget.initialData!['regionName'];
        }
      });
    } catch (e) {
      debugPrint('Error fetching regions: $e');
      if (mounted) {
        setState(() => _isLoadingRegions = false);
      }
    }
  }

  // دالة مركزية لتحديث النصوص من المتغير _selectedLocation
  void _updateControllersFromLocation() {
    if (_selectedLocation != null) {
      _latController.text = _selectedLocation!.latitude.toStringAsFixed(6);
      _lngController.text = _selectedLocation!.longitude.toStringAsFixed(6);
    }
  }

  // ---------------------------------------------------------------------------
  // منطق استخراج الإحداثيات (Core Logic) - تم تصحيح الأولويات
  // ---------------------------------------------------------------------------
  void _parseAndSetCoordinates() {
    String text = _googleCoordsController.text.trim();
    if (text.isEmpty) return;

    double? lat;
    double? lng;

    // 1. الأولوية القصوى: البحث عن نمط 3dlat!4dlng (إحداثيات الدبوس الدقيقة)
    // هذا النمط هو الأدق لأنه يشير للمكان المحدد تحديداً وليس مركز الكاميرا
    final dRegex = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');
    final dMatch = dRegex.firstMatch(text);
    if (dMatch != null) {
      lat = double.tryParse(dMatch.group(1)!);
      lng = double.tryParse(dMatch.group(2)!);
    }

    // 2. البحث عن نمط ?q=lat,lng أو &query=lat,lng (نقطة البحث)
    if (lat == null) {
      final qRegex = RegExp(r'[?&](?:q|query|ll)=(-?\d+\.\d+),(-?\d+\.\d+)');
      final qMatch = qRegex.firstMatch(text);
      if (qMatch != null) {
        lat = double.tryParse(qMatch.group(1)!);
        lng = double.tryParse(qMatch.group(2)!);
      }
    }

    // 3. البحث عن نمط @lat,lng (مركز الكاميرا/الشاشة)
    // نجعل هذا الخيار الأخير لأنه الأقل دقة (يعطيك منتصف الشاشة وقت النسخ)
    if (lat == null) {
      final atRegex = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
      final atMatch = atRegex.firstMatch(text);

      if (atMatch != null) {
        lat = double.tryParse(atMatch.group(1)!);
        lng = double.tryParse(atMatch.group(2)!);
      }
    }

    // 4. النص المباشر (lat, lng) أو (lat lng)
    if (lat == null) {
      // إزالة أي شيء ليس رقماً أو نقطة أو فاصلة أو سالب
      String clean = text.replaceAll(RegExp(r'[^\d\.\,\-\s]'), '');
      // استبدال الفواصل بمسافات
      clean = clean.replaceAll(',', ' ');
      // تحويل مسافات متعددة لمسافة واحدة
      clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

      final parts = clean.split(' ');
      if (parts.length >= 2) {
        lat = double.tryParse(parts[0]);
        lng = double.tryParse(parts[1]);
      }
    }

    // التنفيذ في حال النجاح
    if (lat != null && lng != null) {
      setState(() {
        _selectedLocation = LatLng(lat!, lng!);
        // هام جداً: تحديث حقول النصوص التي يقرأ منها زر الحفظ
        _updateControllersFromLocation();
      });

      // تحريك الخريطة
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation!, 17));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد الموقع بدقة'),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('لم يتم العثور على إحداثيات صالحة. حاول نسخ إحداثيات الدبوس.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _googleCoordsController.text = data.text!;
      _parseAndSetCoordinates(); // استدعاء مباشر للتحليل
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحافظة فارغة!')));
    }
  }

  // ---------------------------------------------------------------------------
  // تحديد الموقع الحالي (GPS)
  // ---------------------------------------------------------------------------
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool hasPermission = await LocationPermissionHelper.requestLocationPermissionWithDisclosure(
        context,
      );

      if (!hasPermission) throw 'تم رفض الإذن';

      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      setState(() {
        _selectedLocation = LatLng(pos.latitude, pos.longitude);
        _updateControllersFromLocation(); // تحديث النصوص
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation!, 16));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  // ---------------------------------------------------------------------------
  // حفظ البيانات
  // ---------------------------------------------------------------------------
  Future<void> _savePlace() async {
    // قراءة القيم من المتحكمات (لضمان أنها آخر ما كتبه المستخدم أو استخرجه النظام)
    double? lat = double.tryParse(_latController.text);
    double? lng = double.tryParse(_lngController.text);

    if (_nameController.text.isEmpty || lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال الاسم وتحديد الموقع'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final placeData = {
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'icon': _selectedType,
        'lat': lat,
        'lng': lng,
        'governorateId': _selectedGovernorateId,
        'governorateName': _selectedGovernorateName,
        'regionId': _selectedRegionId,
        'regionName': _selectedRegionName,
        'published': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (widget.editId != null) {
        await FirebaseFirestore.instance.collection('places').doc(widget.editId).update(placeData);
      } else {
        // منع التكرار بالاسم
        final check =
            await FirebaseFirestore.instance
                .collection('places')
                .where('name', isEqualTo: _nameController.text.trim())
                .get();

        if (check.docs.isNotEmpty) {
          throw 'هذا المكان موجود مسبقاً!';
        }
        await FirebaseFirestore.instance.collection('places').add(placeData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('انحفظت التغييرات!'), backgroundColor: primaryColor),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // حذف المكان
  Future<void> _deletePlace() async {
    if (widget.editId == null) return;
    bool confirm =
        await showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('حذف المكان'),
                content: const Text('لا يمكن التراجع عن هذا الإجراء.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('حذف', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isDeleting = true);
    try {
      await FirebaseFirestore.instance.collection('places').doc(widget.editId).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // واجهة المستخدم (UI Build)
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? darkBg : lightBg;
    final cardCol = isDark ? darkCard : lightCard;
    final txtCol = isDark ? Colors.white : Colors.black87;

    return Theme(
      data:
          isDark
              ? ThemeData.dark().copyWith(
                scaffoldBackgroundColor: darkBg,
                primaryColor: primaryColor,
              )
              : ThemeData.light().copyWith(
                scaffoldBackgroundColor: lightBg,
                primaryColor: primaryColor,
              ),
      child: Scaffold(
        backgroundColor: bgCol,
        appBar: AppBar(
          title: Text(
            widget.editId != null ? 'تعديل بيانات المكان' : 'إضافة مكان جديد',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: primaryColor,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          actions: [
            if (widget.editId != null)
              IconButton(
                icon:
                    _isDeleting
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                        : const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: _isDeleting ? null : _deletePlace,
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ================== قسم استيراد الموقع (التصميم الجديد) ==================
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors:
                                isDark
                                    ? [const Color(0xFF2C3E50), const Color(0xFF34495E)]
                                    : [const Color(0xFFE0F2F1), const Color(0xFFB2DFDB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.link, color: primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  "استيراد من خرائط جوجل",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: txtCol,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.black26 : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextField(
                                      controller: _googleCoordsController,
                                      style: TextStyle(color: txtCol, fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'الصق الرابط أو الإحداثيات هنا...',
                                        hintStyle: TextStyle(
                                          color: isDark ? Colors.white38 : Colors.grey,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.close, size: 18),
                                          onPressed: _googleCoordsController.clear,
                                        ),
                                      ),
                                      onSubmitted: (_) => _parseAndSetCoordinates(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // زر اللصق والبحث السريع
                                Material(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _pasteFromClipboard,
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(Icons.content_paste_go, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ================== البيانات الأساسية ==================
                      _buildSectionHeader("بيانات المكان", Icons.info_outline, txtCol),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardCol,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _nameController,
                              label: "اسم المكان",
                              icon: Icons.store_mall_directory,
                              isDark: isDark,
                              txtCol: txtCol,
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownType(isDark, cardCol, txtCol),
                            const SizedBox(height: 16),
                            _buildGovernorateDropdown(isDark, cardCol, txtCol),
                            if (_selectedGovernorateId != null) ...[
                              const SizedBox(height: 16),
                              _buildRegionDropdown(isDark, cardCol, txtCol),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ================== الخريطة ==================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader("تحديد الموقع", Icons.map, txtCol),
                          InkWell(
                            onTap: () => setState(() => _isSatelliteMode = !_isSatelliteMode),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    _isSatelliteMode
                                        ? primaryColor
                                        : Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _isSatelliteMode ? "قمر صناعي" : "خريطة عادية",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _isSatelliteMode ? Colors.white : txtCol,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Container(
                        height: 350,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _selectedLocation!,
                                zoom: 15,
                              ),
                              mapType: _isSatelliteMode ? MapType.satellite : MapType.normal,
                              onMapCreated: (controller) => _mapController = controller,
                              onTap: (point) {
                                setState(() {
                                  _selectedLocation = point;
                                  _updateControllersFromLocation(); // تحديث الحقول عند النقر
                                });
                              },
                              markers: {
                                if (_selectedLocation != null)
                                  Marker(
                                    markerId: const MarkerId('selected'),
                                    position: _selectedLocation!,
                                    icon: BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueRed,
                                    ),
                                  ),
                              },
                              myLocationEnabled: true,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              mapToolbarEnabled: false,
                            ),
                            // زر "موقعي الحالي"
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: FloatingActionButton.small(
                                heroTag: 'gps_btn',
                                backgroundColor: primaryColor,
                                onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                                child:
                                    _isLoadingLocation
                                        ? const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(Icons.my_location, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ================== الإحداثيات اليدوية ==================
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardCol,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildCoordInput(_latController, "Latitude", isDark, txtCol),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCoordInput(_lngController, "Longitude", isDark, txtCol),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80), // مسافة للزر العائم
                    ],
                  ),
                ),
              ),

              // ================== زر الحفظ (ثابت بالأسفل) ==================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardCol,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -4),
                      blurRadius: 10,
                    ),
                  ],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isSaving ? null : _savePlace,
                    child:
                        _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                              widget.editId != null ? "حفظ التعديلات" : "إضافة المكان",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ويدجت مساعدة (Widgets Helpers)
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color txtCol,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: txtCol, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: accentColor),
        filled: true,
        fillColor: isDark ? Colors.black12 : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdownType(bool isDark, Color cardCol, Color txtCol) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedType,
      dropdownColor: cardCol,
      style: TextStyle(color: txtCol),
      decoration: InputDecoration(
        labelText: 'نوع التصنيف',
        prefixIcon: const Icon(Icons.category, color: accentColor),
        filled: true,
        fillColor: isDark ? Colors.black12 : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items:
          placeTypes.map((e) {
            return DropdownMenuItem(
              value: e['key'] as String,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end, // محاذاة لليمين
                children: [
                  Text(e['label'] as String),
                  const SizedBox(width: 10),
                  Icon(e['icon'] as IconData, size: 18, color: Colors.grey),
                ],
              ),
            );
          }).toList(),
      onChanged: (v) => setState(() => _selectedType = v!),
    );
  }

  Widget _buildCoordInput(
    TextEditingController controller,
    String hint,
    bool isDark,
    Color txtCol,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 45,
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 13, color: txtCol, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 0,
              ), // محاذاة النص عمودياً
            ),
            onChanged: (val) {
              double? v = double.tryParse(val);
              if (v != null && _selectedLocation != null) {
                // تحديث الخريطة عند الكتابة اليدوية
                final newLoc =
                    hint == "Latitude"
                        ? LatLng(v, _selectedLocation!.longitude)
                        : LatLng(_selectedLocation!.latitude, v);
                setState(() => _selectedLocation = newLoc);
                _mapController?.animateCamera(CameraUpdate.newLatLng(newLoc));
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGovernorateDropdown(bool isDark, Color cardCol, Color txtCol) {
    if (_isLoadingGovernorates) {
      return const Center(child: CircularProgressIndicator());
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedGovernorateId,
      dropdownColor: cardCol,
      style: TextStyle(color: txtCol),
      decoration: InputDecoration(
        labelText: 'المحافظة',
        prefixIcon: const Icon(Icons.map, color: accentColor),
        filled: true,
        fillColor: isDark ? Colors.black12 : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items:
          _governorates.map((g) {
            return DropdownMenuItem(value: g['id'] as String, child: Text(g['name'] as String));
          }).toList(),
      onChanged: (v) {
        final g = _governorates.firstWhere((element) => element['id'] == v);
        setState(() {
          _selectedGovernorateId = v;
          _selectedGovernorateName = g['name'];
        });
        _fetchRegions(v!);
      },
      validator: (v) => v == null ? 'يرجى اختيار المحافظة' : null,
    );
  }

  Widget _buildRegionDropdown(bool isDark, Color cardCol, Color txtCol) {
    if (_isLoadingRegions) {
      return const Center(child: CircularProgressIndicator());
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedRegionId,
      dropdownColor: cardCol,
      style: TextStyle(color: txtCol),
      decoration: InputDecoration(
        labelText: 'المنطقة (القضاء/الناحية)',
        prefixIcon: const Icon(Icons.location_city, color: accentColor),
        filled: true,
        fillColor: isDark ? Colors.black12 : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items:
          _regions.map((r) {
            return DropdownMenuItem(value: r['id'] as String, child: Text(r['name'] as String));
          }).toList(),
      onChanged: (v) {
        final r = _regions.firstWhere((element) => element['id'] == v);
        setState(() {
          _selectedRegionId = v;
          _selectedRegionName = r['name'];
        });
      },
      validator: (v) => v == null ? 'يرجى اختيار المنطقة' : null,
    );
  }
}
