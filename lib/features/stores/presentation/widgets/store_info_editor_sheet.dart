import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import '../../domain/entities/store_dashboard_models.dart';

/// ورقة تعديل بيانات المتجر (Store Info Editor Bottom Sheet)
/// نموذج إدخال نقي لتعديل اسم المتجر، الشعار، الغلاف، والموقع الجغرافي
class StoreInfoEditorSheet extends StatefulWidget {
  final StoreDashboardEntity? initialStore;
  final String fallbackName;
  final String? fallbackLogoUrl;
  final String? fallbackCoverUrl;
  final double? fallbackLat;
  final double? fallbackLng;
  final String? fallbackAddress;
  final bool isDark;
  final Future<String?> Function()? onPickAndUploadLogo;
  final Future<String?> Function()? onPickAndUploadCover;
  final Future<Map<String, dynamic>?> Function()? onPickCurrentGpsLocation;
  final Future<Map<String, dynamic>?> Function()? onPickMapLocation;
  final Function({
    required String name,
    String? logoUrl,
    String? coverUrl,
    double? latitude,
    double? longitude,
    String? address,
  }) onSave;

  const StoreInfoEditorSheet({
    super.key,
    this.initialStore,
    this.fallbackName = '',
    this.fallbackLogoUrl,
    this.fallbackCoverUrl,
    this.fallbackLat,
    this.fallbackLng,
    this.fallbackAddress,
    required this.isDark,
    this.onPickAndUploadLogo,
    this.onPickAndUploadCover,
    this.onPickCurrentGpsLocation,
    this.onPickMapLocation,
    required this.onSave,
  });

  @override
  State<StoreInfoEditorSheet> createState() => _StoreInfoEditorSheetState();
}

class _StoreInfoEditorSheetState extends State<StoreInfoEditorSheet> {
  late TextEditingController _nameController;
  String? _currentLogo;
  String? _currentCover;
  double? _storeLat;
  double? _storeLng;
  String? _storeAddress;

  bool _isUploadingLogo = false;
  bool _isUploadingCover = false;
  bool _isLoadingGps = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initialStore;
    _nameController = TextEditingController(
      text: s?.name.isNotEmpty == true ? s!.name : widget.fallbackName,
    );
    _currentLogo = s?.logoUrl.isNotEmpty == true ? s!.logoUrl : widget.fallbackLogoUrl;
    _currentCover = s?.coverUrl.isNotEmpty == true ? s!.coverUrl : widget.fallbackCoverUrl;
    _storeLat = s?.latitude ?? widget.fallbackLat;
    _storeLng = s?.longitude ?? widget.fallbackLng;
    _storeAddress = s?.address.isNotEmpty == true ? s!.address : widget.fallbackAddress;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogoPick() async {
    if (widget.onPickAndUploadLogo == null || _isUploadingLogo) return;
    setState(() => _isUploadingLogo = true);
    try {
      final url = await widget.onPickAndUploadLogo!();
      if (url != null && mounted) {
        setState(() => _currentLogo = url);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
      }
    }
  }

  Future<void> _handleCoverPick() async {
    if (widget.onPickAndUploadCover == null || _isUploadingCover) return;
    setState(() => _isUploadingCover = true);
    try {
      final url = await widget.onPickAndUploadCover!();
      if (url != null && mounted) {
        setState(() => _currentCover = url);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingCover = false);
      }
    }
  }

  Future<void> _handleGpsPick() async {
    if (widget.onPickCurrentGpsLocation == null || _isLoadingGps) return;
    setState(() => _isLoadingGps = true);
    try {
      final res = await widget.onPickCurrentGpsLocation!();
      if (res != null && mounted) {
        setState(() {
          _storeLat = (res['latitude'] as num?)?.toDouble();
          _storeLng = (res['longitude'] as num?)?.toDouble();
          _storeAddress = res['address']?.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGps = false);
      }
    }
  }

  Future<void> _handleMapPick() async {
    if (widget.onPickMapLocation == null) return;
    final res = await widget.onPickMapLocation!();
    if (res != null && mounted) {
      setState(() {
        _storeLat = (res['latitude'] as num?)?.toDouble();
        _storeLng = (res['longitude'] as num?)?.toDouble();
        _storeAddress = res['address']?.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      padding: EdgeInsets.fromLTRB(
        24.w,
        24.h,
        24.w,
        MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'تعديل بيانات المتجر',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 20.h),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'اسم المتجر',
                labelStyle: const TextStyle(),
                prefixIcon: Icon(Icons.storefront_rounded, size: 20.sp),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              ),
            ),
            SizedBox(height: 16.h),
            // Location pick buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _handleGpsPick,
                    icon: _isLoadingGps
                        ? SizedBox(
                            width: 14.r,
                            height: 14.r,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded, size: 16),
                    label: Text(
                      _storeLat != null ? 'موقع مباشر (مفعل)' : 'تحديد مباشر (GPS)',
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _storeLat != null ? Colors.teal : Colors.blueGrey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _handleMapPick,
                    icon: const Icon(Icons.map_rounded, size: 16),
                    label: const Text(
                      'اختيار من الخريطة',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                  ),
                ),
              ],
            ),
            if (_storeAddress != null) ...[
              SizedBox(height: 8.h),
              Text(
                _storeAddress!,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
              ),
            ],
            SizedBox(height: 20.h),
            // Logo & Cover
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'الشعار',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      GestureDetector(
                        onTap: _handleLogoPick,
                        child: Container(
                          height: 80.r,
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? Colors.white10
                                : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: _isUploadingLogo
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                    strokeWidth: 2,
                                  ),
                                )
                              : _currentLogo != null && _currentLogo!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16.r),
                                      child: Image.network(
                                        _currentLogo!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    )
                                  : Center(
                                      child: Icon(
                                        Icons.add_a_photo_rounded,
                                        color: Colors.grey,
                                        size: 24.sp,
                                      ),
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Text(
                        'الغلاف',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      GestureDetector(
                        onTap: _handleCoverPick,
                        child: Container(
                          height: 80.r,
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? Colors.white10
                                : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: _isUploadingCover
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                    strokeWidth: 2,
                                  ),
                                )
                              : _currentCover != null && _currentCover!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16.r),
                                      child: Image.network(
                                        _currentCover!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    )
                                  : Center(
                                      child: Icon(
                                        Icons.add_photo_alternate_rounded,
                                        color: Colors.grey,
                                        size: 24.sp,
                                      ),
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 30.h),
            SizedBox(
              width: double.infinity,
              height: 54.h,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameController.text.trim().isEmpty) return;
                  widget.onSave(
                    name: _nameController.text.trim(),
                    logoUrl: _currentLogo,
                    coverUrl: _currentCover,
                    latitude: _storeLat,
                    longitude: _storeLng,
                    address: _storeAddress,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'حفظ التغييرات',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
