import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/core/location/iraq_location_resolver.dart';
import '../services/complaints_service.dart';
import 'complaint_marker_helper.dart';

class ComplaintAddSheet extends StatefulWidget {
  final bool isDark;
  final LatLng? initialPosition;

  const ComplaintAddSheet({
    super.key,
    required this.isDark,
    this.initialPosition,
  });

  @override
  State<ComplaintAddSheet> createState() => _ComplaintAddSheetState();
}

class _ComplaintAddSheetState extends State<ComplaintAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final ComplaintsService _service = ComplaintsService();

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _locationNameCtrl = TextEditingController();

  String _selectedCategory = 'حفرة وتخسف بالشارع';
  String _selectedGovernorate = 'الأنبار';
  String _selectedCity = 'القائم';
  LatLng _selectedLatLng = const LatLng(33.3152, 44.3661);
  final List<XFile> _selectedImages = [];
  bool _isPublishing = false;
  bool _isGeneratingAI = false;
  bool _isLocating = false;
  GoogleMapController? _mapController;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'حفرة وتخسف بالشارع', 'icon': Icons.construction_rounded},
    {'name': 'ماء فايض وكسر بوري', 'icon': Icons.water_drop_rounded},
    {'name': 'وايرات كهرباء ومحولات', 'icon': Icons.bolt_rounded},
    {'name': 'انسداد مجاري وفتحات', 'icon': Icons.plumbing_rounded},
    {'name': 'تراكم نفايات وأوساخ', 'icon': Icons.delete_sweep_rounded},
    {'name': 'إنارة شوارع طافية', 'icon': Icons.lightbulb_rounded},
    {'name': 'مشكلة خدمية أخرى', 'icon': Icons.report_problem_rounded},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _selectedLatLng = widget.initialPosition!;
    } else {
      _determineCurrentLocation();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationNameCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _determineCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final iraqLoc = await IraqLocationResolver().getCurrentDeviceLocation(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (iraqLoc != null && mounted) {
        setState(() {
          _selectedLatLng = iraqLoc.latLng;
          if (iraqLoc.governorate != null) _selectedGovernorate = iraqLoc.governorate!;
          if (iraqLoc.district != null) _selectedCity = iraqLoc.district!;
          if (_locationNameCtrl.text.isEmpty && iraqLoc.formattedAddress.isNotEmpty) {
            _locationNameCtrl.text = iraqLoc.formattedAddress;
          }
          _isLocating = false;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(iraqLoc.latLng, 16.5));
      } else {
        if (mounted) setState(() => _isLocating = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLocating = false);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    if (source == ImageSource.gallery) {
      final imgs = await picker.pickMultiImage(imageQuality: 85);
      if (imgs.isNotEmpty && mounted) {
        setState(() => _selectedImages.addAll(imgs));
      }
    } else {
      final img = await picker.pickImage(source: source, imageQuality: 85);
      if (img != null && mounted) {
        setState(() => _selectedImages.add(img));
      }
    }
  }

  Future<void> _generateAIDescription() async {
    if (_locationNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى تحديد الحي أو المنطقة بالقائم لمساعدة سكوزمي',
            style: TextStyle(),
          ),
          backgroundColor: app_colors.primaryColor,
        ),
      );
      return;
    }

    setState(() => _isGeneratingAI = true);
    try {
      final text = await _service.generateCivicReportWithAI(
        issueCategory: _selectedCategory,
        location: _locationNameCtrl.text.trim(),
        additionalNotes: _titleCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _descCtrl.text = text;
          if (_titleCtrl.text.isEmpty) {
            _titleCtrl.text =
                'بلاغ عن $_selectedCategory في ${_locationNameCtrl.text.trim()}';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAI = false);
    }
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;
    if (_service.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'سجّل دخولك أولاً لتوثيق البلاغ',
            style: TextStyle(),
          ),
          backgroundColor: app_colors.primaryColor,
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);
    try {
      await _service.addComplaint(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _selectedCategory,
        locationName: _locationNameCtrl.text.trim(),
        governorate: _selectedGovernorate,
        city: _selectedCity,
        latitude: _selectedLatLng.latitude,
        longitude: _selectedLatLng.longitude,
        imageFiles: _selectedImages,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم توثيق بلاغك ونشره على الخريطة بنجاح!',
              style: TextStyle(),
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل النشر: $e',
              style: const TextStyle(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A1F22) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        child: Column(
          children: [
            // Top Handle
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),

            // Header Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: app_colors.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_location_alt_rounded,
                      color: app_colors.primaryColor,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'توثيق بلاغ جديد على الخريطة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                      color: isDark ? Colors.white : const Color(0xFF0C2428),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: isDark ? Colors.white12 : Colors.grey.shade200),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 1. Interactive Mini Map ──
                      Text(
                        '1. حدد مكان المشكلة بالخريطة (انقر لتغيير المكان) :',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18.r),
                        child: SizedBox(
                          height: 160.h,
                          width: double.infinity,
                          child: Stack(
                            children: [
                              GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: _selectedLatLng,
                                  zoom: 15,
                                ),
                                onMapCreated: (ctrl) {
                                  _mapController = ctrl;
                                  if (widget.initialPosition == null) {
                                    _determineCurrentLocation();
                                  }
                                },
                                onTap: (latLng) {
                                  setState(() => _selectedLatLng = latLng);
                                },
                                markers: {
                                  Marker(
                                    markerId: const MarkerId(
                                      'picked_issue_pos',
                                    ),
                                    position: _selectedLatLng,
                                    draggable: true,
                                    onDragEnd:
                                        (newPos) => setState(
                                          () => _selectedLatLng = newPos,
                                        ),
                                  ),
                                },
                                zoomControlsEnabled: false,
                                myLocationEnabled: true,
                                myLocationButtonEnabled: false,
                              ),
                              Positioned(
                                bottom: 10.h,
                                left: 10.w,
                                child: FloatingActionButton.small(
                                  onPressed:
                                      _isLocating
                                          ? null
                                          : _determineCurrentLocation,
                                  backgroundColor: app_colors.primaryColor,
                                  child:
                                      _isLocating
                                          ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Icon(
                                            Icons.my_location_rounded,
                                            color: Colors.white,
                                          ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // ── 2. Issue Category Selector ──
                      Text(
                        '2. نوع المشكلة أو العطل :',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children:
                            _categories.map((c) {
                              final isSel = _selectedCategory == c['name'];
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      c['icon'] as IconData,
                                      size: 13.sp,
                                      color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(c['name']),
                                  ],
                                ),
                                selected: isSel,
                                onSelected:
                                    (_) => setState(
                                      () => _selectedCategory = c['name'],
                                    ),
                                selectedColor: app_colors.primaryColor,
                                backgroundColor:
                                    isDark
                                        ? const Color(0xFF113035)
                                        : Colors.grey.shade100,
                                labelStyle: TextStyle(
                                  fontWeight:
                                      isSel
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color:
                                      isSel
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                  fontSize: 11.sp,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              );
                            }).toList(),
                      ),
                      SizedBox(height: 14.h),

                      // ── 3. Governorate & City & District ──
                      Text(
                        'المحافظة والمدينة بالعراق 🇮🇶:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ComplaintMarkerHelper.iraqGovernorates.map((gov) {
                            final isSel = _selectedGovernorate == gov;
                            return Padding(
                              padding: EdgeInsets.only(left: 6.w),
                              child: ChoiceChip(
                                label: Text(gov),
                                selected: isSel,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedGovernorate = gov;
                                    final cities = ComplaintMarkerHelper.getCitiesForGovernorate(gov);
                                    _selectedCity = cities.isNotEmpty ? cities.first : gov;
                                  });
                                },
                                selectedColor: app_colors.primaryColor,
                                backgroundColor: isDark ? const Color(0xFF113035) : Colors.grey.shade100,
                                labelStyle: TextStyle(
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontSize: 10.5.sp,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ComplaintMarkerHelper.getCitiesForGovernorate(_selectedGovernorate).map((c) {
                            final isSel = _selectedCity == c;
                            return Padding(
                              padding: EdgeInsets.only(left: 6.w),
                              child: ActionChip(
                                label: Text(c),
                                backgroundColor: isSel ? app_colors.primaryColor.withValues(alpha: 0.2) : (isDark ? const Color(0xFF113035) : Colors.grey.shade100),
                                side: BorderSide(color: isSel ? app_colors.primaryColor : Colors.transparent),
                                labelStyle: TextStyle(
                                  fontSize: 10.5.sp,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? app_colors.primaryColor : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                onPressed: () => setState(() => _selectedCity = c),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      _buildTextField(
                        controller: _locationNameCtrl,
                        label: 'اسم الحي / الشارع (مثال: حي الجمعية، شارع المحطة، قرب جامع...)',
                        icon: Icons.location_city_rounded,
                        isDark: isDark,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى تحديد الحي أو اسم الشارع' : null,
                      ),
                      SizedBox(height: 14.h),

                      // ── 4. Photo Picker ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'صور من مكان المشكلة (${_selectedImages.length} صور):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.camera_alt_rounded, color: app_colors.primaryColor, size: 20),
                                tooltip: 'التقاط بالكاميرا',
                                onPressed: () => _pickImage(ImageSource.camera),
                              ),
                              IconButton(
                                icon: const Icon(Icons.photo_library_rounded, color: app_colors.primaryColor, size: 20),
                                tooltip: 'اختيار من المعرض',
                                onPressed: () => _pickImage(ImageSource.gallery),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Add Photo Action Tile
                            GestureDetector(
                              onTap: () => _pickImage(ImageSource.gallery),
                              child: Container(
                                width: 85.w,
                                height: 85.h,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF13363A) : const Color(0xFFE8F6F4),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(color: app_colors.primaryColor, width: 1.5),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_a_photo_rounded, color: app_colors.primaryColor, size: 22),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'إضافة صور',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                        color: app_colors.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Thumbnails
                            ..._selectedImages.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final img = entry.value;
                              return Stack(
                                children: [
                                  Container(
                                    margin: EdgeInsets.only(right: 8.w),
                                    width: 85.w,
                                    height: 85.h,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16.r),
                                      image: DecorationImage(
                                        image: FileImage(File(img.path)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedImages.removeAt(idx)),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // ── 5. Title & Description + AI Button ──
                      _buildTextField(
                        controller: _titleCtrl,
                        label: 'عنوان البلاغ (مثال: حفرة عميقة قرب المحطة)',
                        icon: Icons.title_rounded,
                        isDark: isDark,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'يرجى كتابة عنوان البلاغ'
                                    : null,
                      ),
                      SizedBox(height: 10.h),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'تفاصيل البلاغ :',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          TextButton.icon(
                            onPressed:
                                _isGeneratingAI ? null : _generateAIDescription,
                            icon:
                                _isGeneratingAI
                                    ? SizedBox(
                                      width: 14.r,
                                      height: 14.r,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: app_colors.primaryColor,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 15,
                                      color: app_colors.primaryColor,
                                    ),
                            label: Text(
                              'صيغلي الشكوى بسكوزمي',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: app_colors.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      _buildTextField(
                        controller: _descCtrl,
                        label:
                            'اكتب الشرح أو اضغط زر سكوزمي لكتابة البلاغ تلقائياً وبلهجة عراقية واضحة...',
                        icon: Icons.notes_rounded,
                        isDark: isDark,
                        maxLines: 4,
                      ),
                      SizedBox(height: 24.h),

                      // ── Submit Button ──
                      SizedBox(
                        width: double.infinity,
                        height: 50.h,
                        child: ElevatedButton.icon(
                          onPressed: _isPublishing ? null : _submitComplaint,
                          icon:
                              _isPublishing
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                  ),
                          label: Text(
                            _isPublishing
                                ? 'جاري توثيق البلاغ...'
                                : 'نشر البلاغ على الخريطة هسة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: app_colors.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F2D32) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        cursorColor: app_colors.primaryColor,
        style: TextStyle(
          fontSize: 12.5.sp,
          color: isDark ? Colors.white : Colors.black87,
        ),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 11.sp,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
          prefixIcon: Icon(icon, color: app_colors.primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: 12.h,
          ),
        ),
      ),
    );
  }
}
