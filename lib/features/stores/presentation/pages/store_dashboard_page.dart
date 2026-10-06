import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:dalal_alqaim/utils/theme_constants.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:dalal_alqaim/pages/technical_support_chat_page.dart';
import 'package:dalal_alqaim/widgets/map_picker_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/madar_points_page.dart';
import 'package:dalal_alqaim/services/user_service.dart';

import '../../domain/entities/store_dashboard_models.dart';
import '../../application/store_dashboard_controller.dart';
import '../widgets/store_dashboard_header.dart';
import '../widgets/store_overview_section.dart';
import '../widgets/store_orders_section.dart';
import '../widgets/store_products_section.dart';
import '../widgets/store_categories_section.dart';
import '../widgets/store_banners_section.dart';
import '../widgets/store_settings_section.dart';
import '../widgets/store_product_editor_sheet.dart';
import '../widgets/store_info_editor_sheet.dart';

/// صفحة لوحة تحكم المتجر (Store Dashboard Page — Presentation Coordinator)
/// منسق عرض خفيف مسؤول حصراً عن دورة الحياة والملاحة وربط مكونات العرض بمتحكم التطبيق
class StoreDashboardPage extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic> storeData;
  final StoreDashboardController? controller;

  const StoreDashboardPage({
    super.key,
    required this.storeId,
    this.storeData = const {},
    this.controller,
  });

  @override
  State<StoreDashboardPage> createState() => _StoreDashboardPageState();
}

class _StoreDashboardPageState extends State<StoreDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final StoreDashboardController _controller;
  bool _isExternalController = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    if (widget.controller != null) {
      _controller = widget.controller!;
      _isExternalController = true;
    } else {
      _controller = StoreDashboardController(storeId: widget.storeId);
      _controller.initialize();
      _controller.migrateOldData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (!_isExternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 1. تسجيل الخروج والمساعدات (Auth & Helper Actions) ─────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _confirmLogout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24.sp),
            SizedBox(width: 10.w),
            Text(
              'تسجيل الخروج',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت تأكد من رغبتك في تسجيل الخروج من حساب المتجر؟',
          style: TextStyle(
            fontSize: 13.5.sp,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: Icon(Icons.logout_rounded, size: 16.sp, color: Colors.white),
            label: Text(
              'تسجيل الخروج',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final nav = Navigator.of(context);
      await UserService.signOut();
      if (mounted) {
        nav.pushNamedAndRemoveUntil(
          '/welcome',
          (route) => false,
        );
      }
    }
  }

  void _launchPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 2. نوافذ الحوار وتعديل النماذج (Sheets & Dialogs) ──────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _showProductBottomSheet({StoreProductEntity? initialProduct}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StoreProductEditorSheet(
          initialProduct: initialProduct,
          categories: _controller.categories,
          isDark: isDark,
          onPickAndUploadImage: () async {
            final picker = ImagePicker();
            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              final bytes = await image.readAsBytes();
              return await CloudinaryService.uploadBytes(bytes, image.name);
            }
            return null;
          },
          onSave: ({
            required String name,
            required double price,
            required String description,
            required String category,
            required String imageUrl,
            required bool isAvailable,
          }) async {
            bool success = false;
            if (initialProduct == null) {
              success = await _controller.createProduct(
                name: name,
                price: price,
                description: description,
                category: category,
                imageUrl: imageUrl,
                isAvailable: isAvailable,
              );
            } else {
              success = await _controller.updateProduct(
                productId: initialProduct.productId,
                name: name,
                price: price,
                description: description,
                category: category,
                imageUrl: imageUrl,
                isAvailable: isAvailable,
              );
            }
            if (success && ctx.mounted) {
              Navigator.pop(ctx);
            }
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: const Text(
          'حذف المنتج',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'متأكد تريد تحذف هذا المنتج؟',
          style: TextStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _controller.deleteProduct(productId);
    }
  }

  void _showCategoryDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: const Text(
          'إضافة قسم جديد',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'اسم القسم',
            labelStyle: const TextStyle(),
            prefixIcon: Icon(Icons.category_rounded, size: 20.sp),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'إلغاء',
              style: TextStyle(),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final success = await _controller.createCategory(
                name: nameController.text.trim(),
              );
              if (success && ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: const Text(
              'إضافة',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBannerBottomSheet() {
    final titleController = TextEditingController();
    final subController = TextEditingController();
    String? imageUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D26) : Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(30.r),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              24.w,
              12.h,
              24.w,
              MediaQuery.of(context).viewInsets.bottom + 24.h,
            ),
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
                  'إضافة بانر عروض',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 24.h),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'العنوان الرئيسي',
                    labelStyle: const TextStyle(),
                    prefixIcon: Icon(Icons.title_rounded, size: 20.sp),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: subController,
                  decoration: InputDecoration(
                    labelText: 'العنوان الفرعي',
                    labelStyle: const TextStyle(),
                    prefixIcon: Icon(Icons.subtitles_rounded, size: 20.sp),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  ),
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        final url = await CloudinaryService.uploadBytes(
                          bytes,
                          image.name,
                        );
                        setDialogState(() => imageUrl = url);
                      }
                    },
                    icon: Icon(
                      imageUrl != null
                          ? Icons.check_circle_rounded
                          : Icons.cloud_upload_outlined,
                      color: imageUrl != null
                          ? Colors.green
                          : AppTheme.primaryColor,
                    ),
                    label: Text(
                      imageUrl != null
                          ? 'تم الرفع بنجاح'
                          : 'رفع صورة البانر',
                      style: TextStyle(
                        color: imageUrl != null
                            ? Colors.green
                            : AppTheme.primaryColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (imageUrl != null && titleController.text.trim().isNotEmpty) {
                        final success = await _controller.createBanner(
                          title: titleController.text.trim(),
                          subtitle: subController.text.trim(),
                          imageUrl: imageUrl!,
                        );
                        if (success && ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'حفظ ونشر',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditStoreBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StoreInfoEditorSheet(
          initialStore: _controller.store,
          fallbackName: widget.storeData['name'] ?? '',
          fallbackLogoUrl: widget.storeData['logoUrl'],
          fallbackCoverUrl: widget.storeData['coverUrl'],
          fallbackLat: (widget.storeData['latitude'] as num?)?.toDouble() ??
              (widget.storeData['lat'] as num?)?.toDouble(),
          fallbackLng: (widget.storeData['longitude'] as num?)?.toDouble() ??
              (widget.storeData['lng'] as num?)?.toDouble(),
          fallbackAddress: widget.storeData['address'] ?? widget.storeData['location'],
          isDark: isDark,
          onPickAndUploadLogo: () async {
            final picker = ImagePicker();
            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              final bytes = await image.readAsBytes();
              return await CloudinaryService.uploadBytes(bytes, image.name);
            }
            return null;
          },
          onPickAndUploadCover: () async {
            final picker = ImagePicker();
            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              final bytes = await image.readAsBytes();
              return await CloudinaryService.uploadBytes(bytes, image.name);
            }
            return null;
          },
          onPickCurrentGpsLocation: () async {
            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
            if (!serviceEnabled) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('الرجاء تفعيل خدمة تحديد الموقع (GPS)', style: TextStyle()),
                  ),
                );
              }
              return null;
            }
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
              if (permission == LocationPermission.denied) return null;
            }
            if (permission == LocationPermission.deniedForever) return null;

            final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
            final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
            String addr = 'موقع محدد';
            if (placemarks.isNotEmpty) {
              final p = placemarks.first;
              final List<String> parts = [];
              if (p.street != null && p.street!.trim().isNotEmpty && !p.street!.contains('+')) parts.add(p.street!.trim());
              if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) parts.add(p.subLocality!.trim());
              if (p.locality != null && p.locality!.trim().isNotEmpty) parts.add(p.locality!.trim());
              if (parts.isNotEmpty) addr = parts.join('،');
            }
            return {'latitude': pos.latitude, 'longitude': pos.longitude, 'address': addr};
          },
          onPickMapLocation: () async {
            final result = await Navigator.push<Map<String, dynamic>>(
              context,
              MaterialPageRoute(builder: (_) => const MapPickerPage()),
            );
            if (result != null) {
              final LatLng location = result['location'] as LatLng;
              return {
                'latitude': location.latitude,
                'longitude': location.longitude,
                'address': result['address'] as String?,
              };
            }
            return null;
          },
          onSave: ({
            required String name,
            String? logoUrl,
            String? coverUrl,
            double? latitude,
            double? longitude,
            String? address,
          }) async {
            final scaffold = ScaffoldMessenger.of(context);
            final success = await _controller.updateStoreProfile(
              name: name,
              logoUrl: logoUrl,
              coverUrl: coverUrl,
              latitude: latitude,
              longitude: longitude,
              address: address,
            );
            if (success && ctx.mounted) {
              Navigator.pop(ctx);
              scaffold.showSnackBar(
                SnackBar(
                  content: const Text(
                    'تم تحديث البيانات بنجاح',
                    style: TextStyle(),
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  behavior: SnackBarBehavior.fixed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  void _showTransferOwnershipDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: Row(
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              color: Colors.orange,
              size: 24.sp,
            ),
            SizedBox(width: 8.w),
            const Text(
              'نقل ملكية المتجر',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل البريد الإلكتروني للمالك الجديد ليتم نقل الصلاحيات له.',
              style: TextStyle(),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                labelStyle: const TextStyle(),
                prefixIcon: Icon(Icons.email_rounded, size: 20.sp),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'إلغاء',
              style: TextStyle(),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim().toLowerCase();
              if (email.isEmpty) return;
              final scaffold = ScaffoldMessenger.of(context);
              final success = await _controller.transferStoreOwnership(email);
              if (success && ctx.mounted) {
                Navigator.pop(ctx);
                if (mounted) Navigator.pop(context);
                scaffold.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تم نقل الملكية بنجاح',
                      style: TextStyle(),
                    ),
                  ),
                );
              } else if (_controller.errorMessage != null && mounted) {
                scaffold.showSnackBar(
                  SnackBar(
                    content: Text(
                      _controller.errorMessage!,
                      style: const TextStyle(),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: const Text(
              'تأكيد النقل',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 3. الشاشة الرئيسية والتبويبات (Main Build Method) ───────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F7FB);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: bgColor,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // ── SliverAppBar ──
              SliverAppBar(
                expandedHeight: 180.h,
                pinned: true,
                floating: false,
                backgroundColor: isDark ? const Color(0xFF12121A) : Colors.white,
                leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () => _confirmLogout(),
                    tooltip: 'تسجيل الخروج',
                    icon: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        size: 18.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: StoreDashboardHeader(
                    store: _controller.store,
                    fallbackName: widget.storeData['name'] ?? 'المتجر',
                    fallbackLogoUrl: widget.storeData['logoUrl'],
                    isDark: isDark,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(56.h),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF12121A) : Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24.r),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 11.sp,
                      ),
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppTheme.primaryColor,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.label,
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      tabs: [
                        Tab(
                          icon: Icon(Icons.analytics_rounded, size: 20.sp),
                          text: 'نظرة عامة',
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_bag_rounded, size: 20.sp),
                              SizedBox(width: 6.w),
                              const Text('الطلبات'),
                              if (_controller.pendingOrderCount > 0) ...[
                                SizedBox(width: 6.w),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Text(
                                    '${_controller.pendingOrderCount}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          icon: Icon(Icons.inventory_2_rounded, size: 20.sp),
                          text: 'المنتجات',
                        ),
                        Tab(
                          icon: Icon(Icons.category_rounded, size: 20.sp),
                          text: 'الأقسام',
                        ),
                        Tab(
                          icon: Icon(Icons.ads_click_rounded, size: 20.sp),
                          text: 'البانرات',
                        ),
                        Tab(
                          icon: Icon(Icons.settings_rounded, size: 20.sp),
                          text: 'الإعدادات',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                StoreOverviewSection(
                  todayRevenue: _controller.todayRevenue,
                  totalRevenue: _controller.totalRevenue,
                  totalOrders: _controller.orderStatistics.totalOrders,
                  productCount: _controller.products.length,
                  orderStatistics: _controller.orderStatistics,
                  isDark: isDark,
                  onAddProduct: () {
                    _tabController.animateTo(2);
                    Future.delayed(
                      const Duration(milliseconds: 300),
                      () => _showProductBottomSheet(),
                    );
                  },
                  onMadarPoints: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MadarPointsPage(
                          storeId: widget.storeId,
                          storeData: widget.storeData,
                        ),
                      ),
                    );
                  },
                  onEditStore: () => _showEditStoreBottomSheet(),
                ),
                StoreOrdersSection(
                  orders: _controller.filteredOrders,
                  selectedFilter: _controller.selectedOrderStatusFilter,
                  isLoading: _controller.isLoading,
                  isDark: isDark,
                  onFilterChanged: (filter) => _controller.setOrderStatusFilter(filter),
                  onStatusChange: (orderId, nextStatus) async {
                    final scaffold = ScaffoldMessenger.of(context);
                    final success = await _controller.updateOrderStatus(
                      orderId: orderId,
                      nextStatus: nextStatus,
                    );
                    if (success && mounted) {
                      scaffold.showSnackBar(
                        SnackBar(
                          content: const Text(
                            'تم تحديث حالة الطلب بنجاح',
                            style: TextStyle(),
                          ),
                          backgroundColor: AppTheme.primaryColor,
                          behavior: SnackBarBehavior.fixed,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      );
                    }
                  },
                  onCallCustomer: (phone) => _launchPhone(phone),
                  onMarkRead: (orderId) => _controller.markOrderAsRead(orderId),
                ),
                StoreProductsSection(
                  products: _controller.products,
                  isLoading: _controller.isLoading,
                  isDark: isDark,
                  onAddProduct: () => _showProductBottomSheet(),
                  onEditProduct: (product) => _showProductBottomSheet(initialProduct: product),
                  onDeleteProduct: (productId) => _confirmDeleteProduct(productId),
                ),
                StoreCategoriesSection(
                  categories: _controller.categories,
                  productCounts: _controller.categoryProductCounts,
                  isLoading: _controller.isLoading,
                  isDark: isDark,
                  onAddCategory: () => _showCategoryDialog(),
                  onDeleteCategory: (categoryId) => _controller.deleteCategory(categoryId),
                ),
                StoreBannersSection(
                  banners: _controller.banners,
                  isLoading: _controller.isLoading,
                  isDark: isDark,
                  onAddBanner: () => _showAddBannerBottomSheet(),
                  onDeleteBanner: (bannerId) => _controller.deleteBanner(bannerId),
                ),
                StoreSettingsSection(
                  isDark: isDark,
                  onEditStoreInfo: () => _showEditStoreBottomSheet(),
                  onTransferOwnership: () => _showTransferOwnershipDialog(),
                  onHelpCenter: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TechnicalSupportChatPage(isAdminPersonalChat: true),
                      ),
                    );
                  },
                  onAboutStore: () {},
                  onDeleteStore: () {},
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
