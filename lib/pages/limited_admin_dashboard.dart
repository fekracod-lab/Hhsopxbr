import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/features/admin/presentation/pages/admin_web_only_notice_page.dart';
import 'restaurants_management_page.dart';
import 'places_management_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_requests_page.dart';
import 'restaurant_requests_page.dart';
import 'page_items_screen.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_requests_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_management_page.dart';
import 'transport_requests_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/ride_management_page.dart';
import 'restaurant_analytics_page.dart';
import 'transport_management_page.dart';
import 'page_list_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/taxi_settings_page.dart';
import 'users_management_page.dart';
import 'governorates_management_page.dart';
import 'complaints_management_page.dart';

import 'package:dalal_alqaim/core/taxi/data/repositories/taxi_kyc_repository.dart';
import 'package:dalal_alqaim/core/delivery/data/repositories/mersal_kyc_repository.dart';
import 'package:dalal_alqaim/core/restaurant/data/repositories/restaurant_kyc_repository.dart';
import 'package:dalal_alqaim/core/stores/data/repositories/store_kyc_repository.dart';

// --- Palette requested by the user ---
class AppPalette {
  // Light Mode
  static const Color primary = Color(0xFF26A69A);
  static const Color accent = Color(0xFF00796B);
  static const Color background = Color(0xFFF5F6F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF333333);
  static const Color subText = Color(0xFF757575);
  static const Color hint = Color(0xFF9E9E9E);

  // Dark Mode
  static const Color darkBackground = Color(0xFF07191A);
  static const Color darkSurface = Color(0xFF0F2323);
  static const Color darkCard = Color(0xFF113033);
  static const Color darkText = Color(0xFFE0F2F1);
  static const Color darkSubText = Color(0xFF80CBC4);
  static const Color darkHint = Color(0xFF4DB6AC);

  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color getBackground(BuildContext context) =>
      isDarkMode(context) ? darkBackground : background;
  static Color getSurface(BuildContext context) => isDarkMode(context) ? darkCard : surface;
  static Color getText(BuildContext context) => isDarkMode(context) ? darkText : text;
  static Color getSubText(BuildContext context) => isDarkMode(context) ? darkSubText : subText;
}

class LimitedAdminDashboard extends StatefulWidget {
  const LimitedAdminDashboard({super.key});

  @override
  State<LimitedAdminDashboard> createState() => _LimitedAdminDashboardState();
}

class _LimitedAdminDashboardState extends State<LimitedAdminDashboard> {

  User? get _currentUser => FirebaseAuth.instance.currentUser;
  final TaxiKycRepository _taxiKycRepository = TaxiKycRepository();
  final MersalKycRepository _mersalKycRepository = MersalKycRepository();
  final RestaurantKycRepository _restaurantKycRepository = RestaurantKycRepository();
  final StoreKycRepository _storeKycRepository = StoreKycRepository();

  Stream<int> _pendingDriverRequestsCountStream() {
    return _taxiKycRepository.streamPendingTaxiKycCount();
  }

  Stream<int> _pendingDeliveryRequestsCountStream() {
    return _mersalKycRepository.streamPendingMersalKycCount();
  }

  Stream<int> _pendingTransportRequestsCountStream() {
    return FirebaseFirestore.instance
        .collection('transport_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _pendingComplaintsCountStream() {
    return FirebaseFirestore.instance
        .collection('complaints')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _adminDocStream() {
    return FirebaseFirestore.instance.collection('users').doc(_currentUser?.uid).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const AdminWebOnlyNoticePage();
    }

    final isDark = AppPalette.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppPalette.getBackground(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppPalette.darkSurface : AppPalette.primary,
        title: const Text(
          'لوحة تحكم الأدمن المحدود',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _adminDocStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppPalette.primary));
          }

          final userData = snap.data?.data();
          final displayName =
              userData?['username'] ?? userData?['name'] ?? _currentUser?.displayName ?? 'أدمن';
          final assignedPages =
              (userData?['assignedPages'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          final permissions = (userData?['permissions'] as List<dynamic>?)?.cast<String>() ?? [];

          bool hasPermission(String key) => permissions.contains(key);

          return CustomScrollView(
            slivers: [
              // Header section
              SliverToBoxAdapter(child: _buildHeader(isDark, displayName)),

              // Quick Actions / Stats Grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  delegate: SliverChildListDelegate([
                    if (hasPermission('driver_requests'))
                      StreamBuilder<int>(
                        stream: _pendingDriverRequestsCountStream(),
                        builder: (context, countSnap) {
                          final count = countSnap.data ?? 0;
                          return _DashboardCard(
                            title: 'طلبات السائقين',
                            subtitle: 'طلبات الانضمام المعلقة',
                            icon: Icons.local_shipping,
                            badgeCount: count,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DriverRequestsPage()),
                              );
                            },
                          );
                        },
                      ),

                    if (hasPermission('delivery_requests'))
                      StreamBuilder<int>(
                        stream: _pendingDeliveryRequestsCountStream(),
                        builder: (context, countSnap) {
                          final count = countSnap.data ?? 0;
                          return _DashboardCard(
                            title: 'طلبات الدليفري',
                            subtitle: 'طلبات انضمام الموصلين',
                            icon: Icons.delivery_dining,
                            badgeCount: count,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DeliveryRequestsPage()),
                              );
                            },
                          );
                        },
                      ),

                    if (hasPermission('transport_requests'))
                      StreamBuilder<int>(
                        stream: _pendingTransportRequestsCountStream(),
                        builder: (context, countSnap) {
                          final count = countSnap.data ?? 0;
                          return _DashboardCard(
                            title: 'طلبات سيارات النقل',
                            subtitle: 'طلبات انضمام شركاء النقل',
                            icon: Icons.local_shipping,
                            badgeCount: count,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TransportRequestsPage()),
                              );
                            },
                          );
                        },
                      ),

                    if (hasPermission('ride_management'))
                      _DashboardCard(
                        title: 'إدارة الرحلات',
                        subtitle: 'سجل الرحلات والسائقين',
                        icon: Icons.history,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RideManagementPage()),
                          );
                        },
                      ),

                    if (hasPermission('restaurant_analytics'))
                      _DashboardCard(
                        title: 'تحليلات المطاعم',
                        subtitle: 'إحصائيات المبيعات والطلبات',
                        icon: Icons.bar_chart,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RestaurantAnalyticsPage()),
                          );
                        },
                      ),

                    if (hasPermission('delivery_management'))
                      _DashboardCard(
                        title: 'إدارة فريق الدليفري',
                        subtitle: 'إدارة الموصلين المعتمدين',
                        icon: Icons.settings_suggest,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DeliveryManagementPage()),
                          );
                        },
                      ),

                    if (hasPermission('transport_management'))
                      _DashboardCard(
                        title: 'إدارة أسطول النقل',
                        subtitle: 'إدارة الرحلات والأرباح',
                        icon: Icons.local_shipping,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TransportManagementPage()),
                          );
                        },
                      ),

                    if (hasPermission('restaurant_requests'))
                      StreamBuilder<int>(
                        stream: _restaurantKycRepository.streamPendingRestaurantKycCount(),
                        builder: (context, countSnap) {
                          final count = countSnap.data ?? 0;
                          return _DashboardCard(
                            title: 'طلبات المطاعم',
                            subtitle: 'طلبات الانضمام المعلقة',
                            icon: Icons.storefront,
                            badgeCount: count,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RestaurantRequestsPage()),
                              );
                            },
                          );
                        },
                      ),

                    if (hasPermission('restaurants'))
                      _DashboardCard(
                        title: 'إدارة المطاعم',
                        subtitle: 'تعديل وحذف المطاعم',
                        icon: Icons.restaurant,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RestaurantsManagementPage()),
                          );
                        },
                      ),

                    if (hasPermission('places'))
                      _DashboardCard(
                        title: 'إدارة الأماكن',
                        subtitle: 'إدارة المعالم السياحية',
                        icon: Icons.place,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PlacesManagementPage()),
                          );
                        },
                      ),

                    if (hasPermission('pages_management'))
                      _DashboardCard(
                        title: 'إدارة الأقسام والصفحات',
                        subtitle: 'إضافة وتعديل الأقسام والصفحات',
                        icon: Icons.grid_view_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PageListPage()),
                          );
                        },
                      ),

                    if (hasPermission('taxi_settings'))
                      _DashboardCard(
                        title: 'إعدادات أسعار التكسي',
                        subtitle: 'تعديل أسعار الكيلومتر والأسعار الأساسية',
                        icon: Icons.local_taxi_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TaxiSettingsPage()),
                          );
                        },
                      ),

                    if (hasPermission('users_management'))
                      _DashboardCard(
                        title: 'إدارة المستخدمين',
                        subtitle: 'عرض وحظر المستخدمين',
                        icon: Icons.people_alt_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UsersManagementPage()),
                          );
                        },
                      ),
                    if (hasPermission('governorates'))
                      _DashboardCard(
                        title: 'إدارة المحافظات',
                        subtitle: 'إضافة وتعديل المحافظات',
                        icon: Icons.map_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GovernoratesManagementPage(canDelete: false),
                            ),
                          );
                        },
                      ),
                    if (hasPermission('complaints_management'))
                      StreamBuilder<int>(
                        stream: _pendingComplaintsCountStream(),
                        builder: (context, countSnap) {
                          final count = countSnap.data ?? 0;
                          return _DashboardCard(
                            title: 'الشكاوى والاقتراحات',
                            subtitle: 'إدارة وحل شكاوى المستخدمين',
                            icon: Icons.feedback_outlined,
                            badgeCount: count,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ComplaintsManagementPage()),
                              );
                            },
                          );
                        },
                      ),
                  ]),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    mainAxisExtent: 100,
                    mainAxisSpacing: 12,
                  ),
                ),
              ),

              // Assigned Pages Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'الصفحات المخصصة لي',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.getText(context),
                    ),
                  ),
                ),
              ),

              if (assignedPages.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'لا توجد صفحات مخصصة حالياً.',
                      style: TextStyle(color: AppPalette.getSubText(context)),
                    ),
                  ),
                )
              else
                SliverReorderableList(
                  itemCount: assignedPages.length,
                  onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, assignedPages),
                  itemBuilder: (context, index) {
                    final p = assignedPages[index];
                    final pageId = p['pageId']?.toString() ?? '';
                    final pageName = p['pageName']?.toString() ?? '';
                    final sectionId = p['sectionId']?.toString() ?? '';
                    final sectionLabel = p['sectionLabel']?.toString() ?? '';

                    return Container(
                      key: ValueKey(pageId),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppPalette.getSurface(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PageItemsScreen(
                                sectionId: sectionId,
                                pageId: pageId,
                                pageName: pageName,
                                sectionColor: AppPalette.primary,
                                sectionIcon: Icons.folder,
                                isAdmin: true,
                              ),
                            ),
                          );
                        },
                        leading: const Icon(Icons.check_circle_outline, color: AppPalette.primary),
                        title: Text(
                          pageName,
                          style: TextStyle(
                            color: AppPalette.getText(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          sectionLabel,
                          style: TextStyle(color: AppPalette.getSubText(context), fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                              onPressed:
                                  () => _renamePage(
                                    pageId,
                                    pageName,
                                    sectionId,
                                    index,
                                    assignedPages,
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              onPressed:
                                  () => _deletePage(
                                    pageId,
                                    pageName,
                                    sectionId,
                                    index,
                                    assignedPages,
                                  ),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.reorder, color: AppPalette.hint),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _renamePage(
    String pageId,
    String oldName,
    String sectionId,
    int index,
    List<Map<String, dynamic>> allPages,
  ) async {
    final controller = TextEditingController(text: oldName);
    final isDark = AppPalette.isDarkMode(context);

    final newName = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: isDark ? AppPalette.darkCard : Colors.white,
            title: const Text('تغيير اسم الصفحة', style: TextStyle()),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'الاسم الجديد'),
              style: TextStyle(color: AppPalette.getText(context)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('حفظ'),
              ),
            ],
          ),
    );

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      try {
        // 1. Update global page document
        await FirebaseFirestore.instance
            .collection('sections')
            .doc(sectionId)
            .collection('pages')
            .doc(pageId)
            .update({'name': newName});

        // 2. Update local user assignment list
        final updatedList = List<Map<String, dynamic>>.from(allPages);
        updatedList[index]['pageName'] = newName;

        await FirebaseFirestore.instance.collection('users').doc(_currentUser?.uid).update({
          'assignedPages': updatedList,
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم تغيير الاسم بنجاح')));
        }
      } catch (e) {
        debugPrint('Error renaming page: $e');
      }
    }
  }

  Future<void> _deletePage(
    String pageId,
    String pageName,
    String sectionId,
    int index,
    List<Map<String, dynamic>> allPages,
  ) async {
    final isDark = AppPalette.isDarkMode(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: isDark ? AppPalette.darkCard : Colors.white,
            title: const Text('حذف الصفحة', style: TextStyle()),
            content: Text('متأكد تريد تحذف صفحة "$pageName" نهائياً مع كافة عناصرها؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        // 1. Delete items inside the page
        final items =
            await FirebaseFirestore.instance
                .collection('sections')
                .doc(sectionId)
                .collection('pages')
                .doc(pageId)
                .collection('items')
                .get();

        for (var doc in items.docs) {
          await doc.reference.delete();
        }

        // 2. Delete the page document itself
        await FirebaseFirestore.instance
            .collection('sections')
            .doc(sectionId)
            .collection('pages')
            .doc(pageId)
            .delete();

        // 3. Remove from local assignment list
        final updatedList = List<Map<String, dynamic>>.from(allPages);
        updatedList.removeAt(index);

        await FirebaseFirestore.instance.collection('users').doc(_currentUser?.uid).update({
          'assignedPages': updatedList,
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم حذف الصفحة')));
        }
      } catch (e) {
        debugPrint('Error deleting page: $e');
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex, List<Map<String, dynamic>> allPages) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final updatedList = List<Map<String, dynamic>>.from(allPages);
    final item = updatedList.removeAt(oldIndex);
    updatedList.insert(newIndex, item);

    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUser?.uid).update({
        'assignedPages': updatedList,
      });
    } catch (e) {
      debugPrint('Error reordering pages: $e');
    }
  }

  Widget _buildHeader(bool isDark, String name) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkSurface : AppPalette.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'أدمن محدود - لوحة العمليات',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int? badgeCount;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showBadge = (badgeCount ?? 0) > 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppPalette.getSurface(context),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppPalette.primary.withValues(alpha: 0.1),
                    ),
                    child: Icon(icon, color: AppPalette.primary, size: 28),
                  ),
                  if (showBadge)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade800,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppPalette.getText(context),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: AppPalette.getSubText(context)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: AppPalette.getSubText(context)),
            ],
          ),
        ),
      ),
    );
  }
}
