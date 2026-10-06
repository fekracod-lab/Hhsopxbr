import 'package:flutter/material.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/store_details_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:dalal_alqaim/pages/my_orders_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/user_points_page.dart';
import 'package:dalal_alqaim/widgets/map_picker_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dalal_alqaim/shared/icon_utils.dart';

class MadarStoresPage extends StatefulWidget {
  const MadarStoresPage({super.key});

  @override
  State<MadarStoresPage> createState() => _MadarStoresPageState();
}

class _MadarStoresPageState extends State<MadarStoresPage> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool isAdmin = false;
  String _selectedCategory = 'الكل';

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final role = doc.data()?['role'];
          setState(() {
            isAdmin = (role == 'admin' || role == 'main_admin' || role == 'limited_admin');
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FB);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── 1. الهيدر العراقي الفخم مع زر الرجوع والمحفظة والبحث ──
            SliverToBoxAdapter(
              child: _buildPremiumHeader(isDark),
            ),

            // ── 2. شريط الأقسام المباشر ──
            SliverToBoxAdapter(
              child: _buildDynamicCategories(isDark),
            ),

            // ── 3. عنوان قائمة المتاجر ──
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(Icons.storefront_rounded, color: AppTheme.primaryColor, size: 20.sp),
                        ),
                        SizedBox(width: 10.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCategory == 'الكل' ? 'كل المتاجر المتوفرة هسة' : 'متاجر $_selectedCategory',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'اطلب مباشرة ويوصلك وين ما تكون',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── 4. شبكة عرض المتاجر بتصميم عراقي أنيق ──
            StreamBuilder<QuerySnapshot>(
              stream: _selectedCategory == 'الكل'
                  ? FirebaseFirestore.instance.collection('stores').snapshots()
                  : FirebaseFirestore.instance.collection('stores').where('category', isEqualTo: _selectedCategory).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(50.r),
                        child: const CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2.5),
                      ),
                    ),
                  );
                }

                final docs = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final category = (data['category'] ?? '').toString().toLowerCase();
                  final address = (data['address'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || category.contains(_searchQuery) || address.contains(_searchQuery);
                }).toList();

                if (docs.isEmpty) return _buildEmptyState(isDark);

                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 20.h,
                      crossAxisSpacing: 14.w,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return _buildSquareStoreItem(docs[index].id, data, isDark);
                    }, childCount: docs.length),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(child: SizedBox(height: 120.h)),
          ],
        ),
        floatingActionButton: isAdmin ? FloatingActionButton.extended(
          onPressed: _showAddStoreDialog,
          backgroundColor: AppTheme.primaryColor,
          elevation: 8,
          icon: Icon(Icons.add_business_rounded, color: Colors.white, size: 22.sp),
          label: Text('إضافة متجر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.white)),
        ) : null,
        bottomNavigationBar: _buildUnifiedBottomBar(isDark),
      ),
    );
  }

  // ── الهيدر الملكي مع زر الرجوع ومحفظة النقاط وشريط البحث ──
  Widget _buildPremiumHeader(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppTheme.primaryColor,
            AppTheme.accentColor,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الشريط العلوي (زر الرجوع + الترحيب + زر الدليل)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // زر الرجوع الفخم
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(30.r),
                    child: Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 16.sp,
                      ),
                    ),
                  ),

                  // عنوان الصفحة
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_bag_rounded, color: Colors.amberAccent, size: 20.sp),
                          SizedBox(width: 6.w),
                          Text(
                            'متاجر وسوق مدار',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'اطلب كل شي يوصلك لباب بيتك',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // زر دليل النقاط والمساعدة
                  InkWell(
                    onTap: () => _showPointsInstructions(isDark),
                    borderRadius: BorderRadius.circular(30.r),
                    child: Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                      ),
                      child: Icon(
                        Icons.help_outline_rounded,
                        color: Colors.white,
                        size: 18.sp,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),

              // بطاقة النقاط والمحفظة الزجاجية
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseAuth.instance.currentUser != null 
                    ? FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots()
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                  final points = userData['points'] ?? 0;
                  final balance = double.tryParse((userData['balance'] ?? 0.0).toString()) ?? 0.0;

                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          // قسم النقاط
                          Expanded(
                            flex: 5,
                            child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserPointsPage())),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 16.sp),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'نقاط مدار',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    '$points نقطة',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'استبدلها بخصومات مباشرة',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 9.5.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          VerticalDivider(
                            color: Colors.white.withValues(alpha: 0.2),
                            thickness: 1,
                            indent: 4,
                            endIndent: 4,
                          ),

                          // قسم رصيد المحفظة
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: EdgeInsets.only(right: 12.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 14.sp),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'رصيد المحفظة',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  FittedBox(
                                    child: Text(
                                      '${balance.toInt()} د.ع',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'ادفع منها بضغطة زر',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 9.5.sp,
                                      fontWeight: FontWeight.w600,
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
                },
              ),
              SizedBox(height: 16.h),

              // شريط البحث الذكي
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'دور على متجر، غرض، أو مسواك...',
                    hintStyle: TextStyle(
                      fontSize: 12.sp,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                    prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryColor, size: 22.sp),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, color: Colors.grey, size: 18.sp),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── تصميم مربعات المتاجر الأنيقة والمرتبة جنب بعض ──
  Widget _buildSquareStoreItem(String id, Map<String, dynamic> data, bool isDark) {
    final name = data['name'] ?? 'متجر مدار';
    final logoUrl = data['logoUrl'] ?? data['image'];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StoreDetailsPage(storeId: id, storeData: data),
        ),
      ),
      onLongPress: isAdmin ? () => _showStoreAdminActions(id, data) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // المربع الأنيق
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.r),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(10.r),
                    child: logoUrl != null && logoUrl.toString().isNotEmpty
                        ? Image.network(
                            logoUrl.toString(),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.storefront_rounded,
                              size: 32.sp,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : Icon(
                            Icons.storefront_rounded,
                            size: 32.sp,
                            color: AppTheme.primaryColor,
                          ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          // اسم المتجر تحت المربع
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  // ── القائمة السفلية الزجاجية الموحدة مع زر الرجوع ──
  Widget _buildUnifiedBottomBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
        border: Border(
          top: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomActionItem(
                index: 0,
                icon: Icons.storefront_rounded,
                label: 'المتاجر',
                isSelected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
                isDark: isDark,
              ),
              _buildBottomActionItem(
                index: 1,
                icon: Icons.shopping_bag_outlined,
                label: 'مسواكك وطلباتك',
                isSelected: _currentIndex == 1,
                onTap: () {
                  setState(() => _currentIndex = 1);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersPage()));
                },
                isDark: isDark,
              ),
              _buildBottomActionItem(
                index: 2,
                icon: Icons.stars_rounded,
                label: 'نقاط مدار',
                isSelected: _currentIndex == 2,
                onTap: () {
                  setState(() => _currentIndex = 2);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UserPointsPage()));
                },
                isDark: isDark,
              ),
              _buildBottomActionItem(
                index: 3,
                icon: Icons.arrow_back_rounded,
                label: 'رجوع للمدار',
                isSelected: false,
                isBackButton: true,
                onTap: () => Navigator.pop(context),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    bool isBackButton = false,
  }) {
    final activeColor = isBackButton ? Colors.orangeAccent : AppTheme.primaryColor;
    final inactiveColor = isDark ? Colors.white54 : Colors.grey.shade500;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.all(isSelected || isBackButton ? 6.r : 4.r),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.15)
                    : (isBackButton ? Colors.orange.withValues(alpha: 0.12) : Colors.transparent),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : (isBackButton ? Colors.orange : inactiveColor),
                size: 22.sp,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : (isBackButton ? Colors.orange : inactiveColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStoreAdminActions(String id, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_rounded, color: Colors.blue),
            title: const Text('تعديل المتجر', style: TextStyle()),
            onTap: () {
              Navigator.pop(ctx);
              _showEditStoreDialog(id, data);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_rounded, color: Colors.red),
            title: const Text('حذف المتجر', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(ctx);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('تأكيد الحذف', style: TextStyle()),
                  content: Text('متأكد تريد تحذف "${data['name']}"؟', style: const TextStyle()),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
                    ElevatedButton(onPressed: () => Navigator.pop(d, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('حذف')),
                  ],
                ),
              );
              if (confirm == true) await FirebaseFirestore.instance.collection('stores').doc(id).delete();
            },
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Future<String?> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image == null) return null;
      final bytes = await image.readAsBytes();
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري رفع الصورة...', style: TextStyle())));
      final url = await CloudinaryService.uploadBytes(bytes, image.name);
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      return url;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  void _showAddStoreDialog() {
    final nameController = TextEditingController();
    String? selectedCat = 'الكل';
    String? logoUrl;
    String? coverUrl;
    String? selectedGovId;
    String? selectedGovName;
    String? selectedRegId;
    String? selectedRegName;
    double? storeLat;
    double? storeLng;
    String? storeAddress;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30.r))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, MediaQuery.of(context).viewInsets.bottom + 24.h),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('إضافة متجر جديد', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold), textAlign: TextAlign.start),
                SizedBox(height: 20.h),
                TextField(controller: nameController, decoration: InputDecoration(labelText: 'اسم المتجر', labelStyle: const TextStyle(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)))),
                SizedBox(height: 16.h),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('store_categories').orderBy('createdAt', descending: false).snapshots(),
                  builder: (context, snapshot) {
                    final cats = snapshot.data?.docs.map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String).toList() ?? [];
                    final allItems = ['الكل', ...cats];
                    String? activeValue = selectedCat;
                    if (!allItems.contains(activeValue)) {
                      activeValue = allItems.isNotEmpty ? allItems.first : null;
                    }
                    
                    return DropdownButtonFormField<String>(
                      initialValue: activeValue,
                      items: [
                        const DropdownMenuItem(value: 'الكل', child: Text('الكل', style: TextStyle())),
                        ...cats.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle()))),
                      ],
                      onChanged: (v) => setDialogState(() => selectedCat = v),
                      decoration: InputDecoration(labelText: 'القسم', labelStyle: const TextStyle(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r))),
                    );
                  },
                ),
                SizedBox(height: 16.h),
                
                // ── Dropdown for Governorate ──
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('governorates').snapshots(),
                  builder: (context, govSnapshot) {
                    final govs = govSnapshot.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: selectedGovId,
                      hint: const Text('اختر المحافظة', style: TextStyle()),
                      decoration: InputDecoration(
                        labelText: 'المحافظة',
                        labelStyle: const TextStyle(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                      ),
                      items: govs.map((doc) {
                        final name = doc['name'] as String;
                        return DropdownMenuItem(value: doc.id, child: Text(name, style: const TextStyle()));
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedGovId = val;
                          selectedGovName = govs.firstWhere((doc) => doc.id == val)['name'] as String;
                          selectedRegId = null;
                          selectedRegName = null;
                        });
                      },
                    );
                  },
                ),
                SizedBox(height: 16.h),

                // ── Dropdown for Region ──
                if (selectedGovId != null) ...[
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('governorates')
                        .doc(selectedGovId)
                        .collection('regions')
                        .snapshots(),
                    builder: (context, regSnapshot) {
                      final regs = regSnapshot.data?.docs ?? [];
                      final activeRegs = regs.where((doc) {
                        final rData = doc.data() as Map<String, dynamic>;
                        return rData['isActive'] ?? true;
                      }).toList();

                      return DropdownButtonFormField<String>(
                        initialValue: selectedRegId,
                        hint: const Text('اختر المنطقة', style: TextStyle()),
                        decoration: InputDecoration(
                          labelText: 'المنطقة',
                          labelStyle: const TextStyle(),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        items: activeRegs.map((doc) {
                          final name = doc['name'] as String;
                          return DropdownMenuItem(value: doc.id, child: Text(name, style: const TextStyle()));
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedRegId = val;
                            selectedRegName = activeRegs.firstWhere((doc) => doc.id == val)['name'] as String;
                          });
                        },
                      );
                    },
                  ),
                  SizedBox(height: 16.h),
                ],

                // ── Map Location Picker Buttons (Direct GPS + Map Selection) ──
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                            if (!serviceEnabled) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('الرجاء تفعيل خدمة تحديد الموقع (GPS)', style: TextStyle())),
                                );
                              }
                              return;
                            }
                            LocationPermission permission = await Geolocator.checkPermission();
                            if (permission == LocationPermission.denied) {
                              permission = await Geolocator.requestPermission();
                              if (permission == LocationPermission.denied) return;
                            }
                            if (permission == LocationPermission.deniedForever) return;

                            if (context.mounted) {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                              );
                            }

                            final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
                            final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
                            if (context.mounted) Navigator.pop(context); // close loading

                            String addr = 'موقع محدد';
                            if (placemarks.isNotEmpty) {
                              final p = placemarks.first;
                              final List<String> parts = [];
                              if (p.street != null && p.street!.trim().isNotEmpty && !p.street!.contains('+')) parts.add(p.street!.trim());
                              if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) parts.add(p.subLocality!.trim());
                              if (p.locality != null && p.locality!.trim().isNotEmpty) parts.add(p.locality!.trim());
                              if (parts.isNotEmpty) {
                                addr = parts.join('،');
                              }
                            }
                            setDialogState(() {
                              storeLat = pos.latitude;
                              storeLng = pos.longitude;
                              storeAddress = addr;
                            });
                          } catch (e) {
                            if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('حدث خطأ أثناء تحديد الموقع: $e', style: const TextStyle())),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.my_location_rounded),
                        label: Text(
                          storeLat != null ? 'موقع مباشر (مفعل)' : 'تحديد مباشر (GPS)',
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: storeLat != null ? Colors.teal : Colors.blueGrey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(builder: (_) => const MapPickerPage()),
                          );
                          if (result != null) {
                            final LatLng location = result['location'] as LatLng;
                            setDialogState(() {
                              storeLat = location.latitude;
                              storeLng = location.longitude;
                              storeAddress = result['address'] as String;
                            });
                          }
                        },
                        icon: const Icon(Icons.map_rounded),
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
                if (storeAddress != null) ...[
                  SizedBox(height: 8.h),
                  Text(
                    storeAddress!,
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                  ),
                ],
                SizedBox(height: 16.h),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final url = await _pickAndUploadImage();
                          if (url != null) setDialogState(() => logoUrl = url);
                        },
                        icon: Icon(logoUrl != null ? Icons.check_circle : Icons.add_photo_alternate),
                        label: Text(logoUrl != null ? 'تم رفع الشعار' : 'شعار المتجر', style: const TextStyle()),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final url = await _pickAndUploadImage();
                          if (url != null) setDialogState(() => coverUrl = url);
                        },
                        icon: Icon(coverUrl != null ? Icons.check_circle : Icons.add_photo_alternate),
                        label: Text(coverUrl != null ? 'تم رفع الغلاف' : 'صورة الغلاف', style: const TextStyle()),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30.h),
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isNotEmpty && selectedCat != null) {
                        final user = FirebaseAuth.instance.currentUser;
                        await FirebaseFirestore.instance.collection('stores').add({
                          'name': nameController.text,
                          'category': selectedCat,
                          'rating': 5.0,
                          'ownerId': user?.uid,
                          'logoUrl': logoUrl,
                          'coverUrl': coverUrl,
                          'governorateId': selectedGovId,
                          'governorateName': selectedGovName,
                          'regionId': selectedRegId,
                          'regionName': selectedRegName,
                          'latitude': storeLat,
                          'longitude': storeLng,
                          'address': storeAddress ?? nameController.text,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r))),
                    child: const Text('حفظ المتجر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(height: 10.h),
                Center(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle()))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditStoreDialog(String storeId, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    String? selectedCat = data['category'] ?? 'الكل';
    String? logoUrl = data['logoUrl'];
    String? coverUrl = data['coverUrl'];
    String? selectedGovId = data['governorateId'];
    String? selectedGovName = data['governorateName'];
    String? selectedRegId = data['regionId'];
    String? selectedRegName = data['regionName'];
    double? storeLat = data['latitude'] != null ? (data['latitude'] as num).toDouble() : (data['lat'] != null ? (data['lat'] as num).toDouble() : null);
    double? storeLng = data['longitude'] != null ? (data['longitude'] as num).toDouble() : (data['lng'] != null ? (data['lng'] as num).toDouble() : null);
    String? storeAddress = data['address'] ?? data['location'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30.r))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, MediaQuery.of(context).viewInsets.bottom + 24.h),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('تعديل المتجر', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold), textAlign: TextAlign.start),
                SizedBox(height: 20.h),
                TextField(controller: nameController, decoration: InputDecoration(labelText: 'اسم المتجر', labelStyle: const TextStyle(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)))),
                SizedBox(height: 16.h),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('store_categories').orderBy('createdAt', descending: false).snapshots(),
                  builder: (context, snapshot) {
                    final cats = snapshot.data?.docs.map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String).toList() ?? [];
                    final allItems = ['الكل', ...cats];
                    String? activeValue = selectedCat;
                    if (!allItems.contains(activeValue)) {
                      activeValue = allItems.isNotEmpty ? allItems.first : null;
                    }
                    
                    return DropdownButtonFormField<String>(
                      initialValue: activeValue,
                      items: [
                        const DropdownMenuItem(value: 'الكل', child: Text('الكل', style: TextStyle())),
                        ...cats.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle()))),
                      ],
                      onChanged: (v) => setDialogState(() => selectedCat = v),
                      decoration: InputDecoration(labelText: 'القسم', labelStyle: const TextStyle(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r))),
                    );
                  },
                ),
                SizedBox(height: 16.h),
                
                // ── Dropdown for Governorate ──
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('governorates').snapshots(),
                  builder: (context, govSnapshot) {
                    final govs = govSnapshot.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: selectedGovId,
                      hint: const Text('اختر المحافظة', style: TextStyle()),
                      decoration: InputDecoration(
                        labelText: 'المحافظة',
                        labelStyle: const TextStyle(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                      ),
                      items: govs.map((doc) {
                        final name = doc['name'] as String;
                        return DropdownMenuItem(value: doc.id, child: Text(name, style: const TextStyle()));
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedGovId = val;
                          selectedGovName = govs.firstWhere((doc) => doc.id == val)['name'] as String;
                          selectedRegId = null;
                          selectedRegName = null;
                        });
                      },
                    );
                  },
                ),
                SizedBox(height: 16.h),

                // ── Dropdown for Region ──
                if (selectedGovId != null) ...[
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('governorates')
                        .doc(selectedGovId)
                        .collection('regions')
                        .snapshots(),
                    builder: (context, regSnapshot) {
                      final regs = regSnapshot.data?.docs ?? [];
                      final activeRegs = regs.where((doc) {
                        final rData = doc.data() as Map<String, dynamic>;
                        return rData['isActive'] ?? true;
                      }).toList();

                      return DropdownButtonFormField<String>(
                        initialValue: selectedRegId,
                        hint: const Text('اختر المنطقة', style: TextStyle()),
                        decoration: InputDecoration(
                          labelText: 'المنطقة',
                          labelStyle: const TextStyle(),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        items: activeRegs.map((doc) {
                          final name = doc['name'] as String;
                          return DropdownMenuItem(value: doc.id, child: Text(name, style: const TextStyle()));
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedRegId = val;
                            selectedRegName = activeRegs.firstWhere((doc) => doc.id == val)['name'] as String;
                          });
                        },
                      );
                    },
                  ),
                  SizedBox(height: 16.h),
                ],

                // ── Map Location Picker Buttons (Direct GPS + Map Selection) ──
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                            if (!serviceEnabled) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('الرجاء تفعيل خدمة تحديد الموقع (GPS)', style: TextStyle())),
                                );
                              }
                              return;
                            }
                            LocationPermission permission = await Geolocator.checkPermission();
                            if (permission == LocationPermission.denied) {
                              permission = await Geolocator.requestPermission();
                              if (permission == LocationPermission.denied) return;
                            }
                            if (permission == LocationPermission.deniedForever) return;

                            if (context.mounted) {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                              );
                            }

                            final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
                            final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
                            if (context.mounted) Navigator.pop(context); // close loading

                            String addr = 'موقع محدد';
                            if (placemarks.isNotEmpty) {
                              final p = placemarks.first;
                              final List<String> parts = [];
                              if (p.street != null && p.street!.trim().isNotEmpty && !p.street!.contains('+')) parts.add(p.street!.trim());
                              if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) parts.add(p.subLocality!.trim());
                              if (p.locality != null && p.locality!.trim().isNotEmpty) parts.add(p.locality!.trim());
                              if (parts.isNotEmpty) {
                                addr = parts.join('،');
                              }
                            }
                            setDialogState(() {
                              storeLat = pos.latitude;
                              storeLng = pos.longitude;
                              storeAddress = addr;
                            });
                          } catch (e) {
                            if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('حدث خطأ أثناء تحديد الموقع: $e', style: const TextStyle())),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.my_location_rounded),
                        label: Text(
                          storeLat != null ? 'موقع مباشر (مفعل)' : 'تحديد مباشر (GPS)',
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: storeLat != null ? Colors.teal : Colors.blueGrey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(builder: (_) => const MapPickerPage()),
                          );
                          if (result != null) {
                            final LatLng location = result['location'] as LatLng;
                            setDialogState(() {
                              storeLat = location.latitude;
                              storeLng = location.longitude;
                              storeAddress = result['address'] as String;
                            });
                          }
                        },
                        icon: const Icon(Icons.map_rounded),
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
                if (storeAddress != null) ...[
                  SizedBox(height: 8.h),
                  Text(
                    storeAddress!,
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                  ),
                ],
                SizedBox(height: 16.h),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final url = await _pickAndUploadImage();
                          if (url != null) setDialogState(() => logoUrl = url);
                        },
                        icon: Icon(logoUrl != null ? Icons.check_circle : Icons.add_photo_alternate),
                        label: Text(logoUrl != null ? 'تم رفع الشعار' : 'شعار المتجر', style: const TextStyle()),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final url = await _pickAndUploadImage();
                          if (url != null) setDialogState(() => coverUrl = url);
                        },
                        icon: Icon(coverUrl != null ? Icons.check_circle : Icons.add_photo_alternate),
                        label: Text(coverUrl != null ? 'تم رفع الغلاف' : 'صورة الغلاف', style: const TextStyle()),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30.h),
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isNotEmpty && selectedCat != null) {
                        await FirebaseFirestore.instance.collection('stores').doc(storeId).update({
                          'name': nameController.text,
                          'category': selectedCat,
                          'logoUrl': logoUrl,
                          'coverUrl': coverUrl,
                          'governorateId': selectedGovId,
                          'governorateName': selectedGovName,
                          'regionId': selectedRegId,
                          'regionName': selectedRegName,
                          'latitude': storeLat,
                          'longitude': storeLng,
                          'address': storeAddress ?? nameController.text,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r))),
                    child: const Text('حفظ التعديلات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(height: 10.h),
                Center(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle()))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicCategories(bool isDark) {
    return Padding(
      padding: EdgeInsets.only(top: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أقسام السوق',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'اختار القسم وتصفح المتاجر',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (isAdmin)
                  IconButton(
                    onPressed: _showAddCategoryDialog,
                    icon: Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor, size: 24.sp),
                    tooltip: 'إضافة قسم جديد',
                  ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 95.h,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('store_categories').orderBy('createdAt', descending: false).snapshots(),
              builder: (context, snapshot) {
                final categories = snapshot.data?.docs ?? [];
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildCatItem('الكل', Icons.grid_view_rounded, isDark);
                    final data = categories[index - 1].data() as Map<String, dynamic>;
                    return _buildCatItem(
                      data['name'] ?? '',
                      IconUtils.getIconByCode(data['iconCode'] as int?),
                      isDark,
                      docId: categories[index - 1].id,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatItem(String name, IconData icon, bool isDark, {String? docId}) {
    final isSelected = _selectedCategory == name;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = name),
      onLongPress: () {
        if (isAdmin && docId != null && name != 'الكل') _deleteCategory(docId, name);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 56.r,
              height: 56.r,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  if (!isDark && !isSelected)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                size: 24.sp,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              name,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppTheme.primaryColor : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCategory(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('حذف القسم', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('هل تريد حذف قسم "$name" نهائياً؟', style: const TextStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء', style: TextStyle())),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) await FirebaseFirestore.instance.collection('store_categories').doc(id).delete();
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    IconData selectedIcon = Icons.category_rounded;
    final List<IconData> iconOptions = [
      Icons.restaurant_rounded, Icons.shopping_basket_rounded, Icons.devices_rounded,
      Icons.checkroom_rounded, Icons.local_pharmacy_rounded, Icons.brush_rounded,
      Icons.home_max_rounded, Icons.electrical_services_rounded, Icons.auto_awesome_rounded,
      Icons.fitness_center_rounded, Icons.toys_rounded, Icons.pets_rounded,
      Icons.local_offer_rounded, Icons.star_rounded, Icons.favorite_rounded,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30.r))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, MediaQuery.of(context).viewInsets.bottom + 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إضافة قسم جديد بالسوق', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 20.h),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم القسم (مثال: ملابس، أكلات)',
                  labelStyle: const TextStyle(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
              ),
              SizedBox(height: 20.h),
              Text('اختر الأيقونة المناسبة', style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              SizedBox(height: 10.h),
              SizedBox(
                height: 120.h,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10),
                  itemCount: iconOptions.length,
                  itemBuilder: (context, index) {
                    final icon = iconOptions[index];
                    final isSelected = selectedIcon == icon;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = icon),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: isSelected ? Colors.white : Colors.grey),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('store_categories').add({
                        'name': nameController.text.trim(),
                        'iconCode': selectedIcon.codePoint,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    elevation: 0,
                  ),
                  child: const Text('حفظ القسم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 64.sp,
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'ما لكَينا متاجر بهذا القسم هسة!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'جرب تبحث عن متجر ثاني أو اختار قسم "الكل" لتشوف كل المتاجر المتوفرة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 20.h),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedCategory = 'الكل';
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
                label: const Text(
                  'عرض كل المتاجر',
                  style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPointsInstructions(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 36.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 25,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.stars_rounded, color: Colors.amber.shade700, size: 26.sp),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'دليل نظام نقاط ومكافآت مدار',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'شلون تجمع نقاط وتستفاد منها بطلباتك؟',
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 24.h),
            _buildInstructionItem(Icons.shopping_bag_outlined, 'تسوق واجمع نقاطك', 'كل 1,000 دينار تدفعه بأي متجر بمدار، يرجعلك نقطة بمحفظتك.', isDark),
            _buildInstructionItem(Icons.local_offer_outlined, 'حول نقاطك لخصم مباشر', 'كل 100 نقطة تنطيك خصم فوري بقيمة 1,000 دينار عالفاتورة.', isDark),
            _buildInstructionItem(Icons.card_giftcard_rounded, 'طلبك الجاي بلاش', 'اجمع نقاط كافية وخلي طلبك الجاي مجاني بالكامل بدون ما تدفع شي.', isDark),
            _buildInstructionItem(Icons.bolt_rounded, 'تحديث فوري وسريع', 'نقاطك تنزل بمحفظتك مباشرة أول ما يوصل طلبك للمتجر.', isDark),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String title, String desc, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 18.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 2.h),
                Text(desc, style: TextStyle(fontSize: 11.sp, color: isDark ? Colors.white60 : Colors.grey.shade600, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
