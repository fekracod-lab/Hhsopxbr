import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/features/admin/presentation/pages/admin_web_only_notice_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/ride_management_page.dart';
import 'package:dalal_alqaim/pages/users_management_page.dart';
import 'package:dalal_alqaim/pages/restaurants_management_page.dart';
import 'package:dalal_alqaim/pages/madar_stores_orders_management_page.dart';
import 'package:dalal_alqaim/pages/stores_analytics_and_management_page.dart';
import 'package:dalal_alqaim/pages/delivery_weekly_accounting_page.dart';
import 'package:dalal_alqaim/pages/transport_management_page.dart';
import 'package:dalal_alqaim/pages/governorates_management_page.dart';
import 'package:dalal_alqaim/pages/complaints_management_page.dart';
import 'package:dalal_alqaim/pages/technical_support_chat_page.dart';
import 'package:dalal_alqaim/pages/limited_admins_management_page.dart';
import 'package:dalal_alqaim/pages/all_sections_page.dart';
import 'package:dalal_alqaim/pages/notifications_page.dart';

import 'package:dalal_alqaim/core/taxi/data/repositories/taxi_kyc_repository.dart';
import 'package:dalal_alqaim/core/delivery/data/repositories/mersal_kyc_repository.dart';
import 'package:dalal_alqaim/core/restaurant/data/repositories/restaurant_domain_repository.dart';
import 'package:dalal_alqaim/core/stores/data/repositories/store_domain_repository.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final TaxiKycRepository _taxiKycRepo = TaxiKycRepository();
  final MersalKycRepository _mersalKycRepo = MersalKycRepository();
  final RestaurantDomainRepository _restRepo = RestaurantDomainRepository();
  final StoreDomainRepository _storeRepo = StoreDomainRepository();

  int _pagesCount = 0;
  int _usersCount = 0;
  int _taxiRequestsCount = 0;
  int _deliveryRequestsCount = 0;
  int _restaurantsCount = 0;
  int _storesCount = 0;
  int _complaintsCount = 0;

  @override
  void initState() {
    super.initState();
    _listenToStats();
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير والبركة';
    } else if (hour < 17) {
      return 'مساء الخير والعمل';
    } else {
      return 'مساء الخير والأنوار';
    }
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return Icons.light_mode_rounded;
    } else if (hour < 17) {
      return Icons.wb_twilight_rounded;
    } else {
      return Icons.dark_mode_rounded;
    }
  }

  Color _getGreetingIconColor() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return const Color(0xFFFFD54F);
    } else if (hour < 17) {
      return const Color(0xFFFF8A65);
    } else {
      return const Color(0xFFB39DDB);
    }
  }

  String _getFormattedDateArabic() {
    final now = DateTime.now();
    final weekdays = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    final weekdayStr = weekdays[now.weekday == 7 ? 0 : now.weekday];

    final months = [
      'كانون الثاني',
      'شباط',
      'آذار',
      'نيسان',
      'أيار',
      'حزيران',
      'تموز',
      'آب',
      'أيلول',
      'تشرين الأول',
      'تشرين الثاني',
      'كانون الأول',
    ];
    final monthStr = months[now.month - 1];

    return '$weekdayStr، ${now.day} $monthStr';
  }

  Widget _buildTimeDateChip(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 11,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            _getFormattedDateArabic(),
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _listenToStats() {
    // 1. Sections
    FirebaseFirestore.instance.collection('sections').snapshots().listen((snapshot) {
      if (mounted) setState(() => _pagesCount = snapshot.docs.length);
    });

    // 2. Users
    FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
      if (mounted) setState(() => _usersCount = snapshot.docs.length);
    });

    // 3. Taxi Captain Requests (Isolated)
    _taxiKycRepo.streamPendingTaxiKycCount().listen((count) {
      if (mounted) setState(() => _taxiRequestsCount = count);
    });

    // 4. Delivery Requests (Isolated)
    _mersalKycRepo.streamPendingMersalKycCount().listen((count) {
      if (mounted) setState(() => _deliveryRequestsCount = count);
    });

    // 5. Restaurants (Isolated)
    _restRepo.streamRestaurantsCount().listen((count) {
      if (mounted) setState(() => _restaurantsCount = count);
    });

    // 6. Stores (Isolated)
    _storeRepo.streamStoresCount().listen((count) {
      if (mounted) setState(() => _storesCount = count);
    });

    // 7. Complaints
    FirebaseFirestore.instance
        .collection('complaints')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .listen((snapshot) {
      if (mounted) setState(() => _complaintsCount = snapshot.docs.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const AdminWebOnlyNoticePage();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text(
            'لوحة تحكم مدار الإدارية',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          centerTitle: true,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Row
              Row(
                children: [
                  Icon(_getGreetingIcon(), color: _getGreetingIconColor(), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    _getGreetingMessage(),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  _buildTimeDateChip(isDark),
                ],
              ),
              const SizedBox(height: 18),

              // Statistics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'المستخدمين',
                      '$_usersCount',
                      Icons.people_alt_rounded,
                      const Color(0xFF00BFA5),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      'طلبات كباتن التاكسي',
                      '$_taxiRequestsCount',
                      Icons.local_taxi_rounded,
                      Colors.amber.shade800,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'طلبات الدليفري المعلقة',
                      '$_deliveryRequestsCount',
                      Icons.delivery_dining_rounded,
                      Colors.teal,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      'المطاعم المعتمدة',
                      '$_restaurantsCount',
                      Icons.restaurant_rounded,
                      Colors.deepOrangeAccent,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'المتاجر المعتمدة',
                      '$_storesCount',
                      Icons.storefront_rounded,
                      const Color(0xFF00897B),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      'الشكاوى المفتوحة',
                      '$_complaintsCount',
                      Icons.receipt_long_rounded,
                      Colors.redAccent,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Administrative Modules List
              Text(
                'الأقسام والخدمات الإدارية الشاملة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // 1. Taxi Management
              _buildAdminTile(
                icon: Icons.local_taxi_rounded,
                iconColor: Colors.amber.shade800,
                title: 'إدارة التاكسي والرحلات والكباتن',
                subtitle: 'مراقبة الرحلات الحية، تسوية العمولات، تصفير المحافظ، واعتماد الكباتن',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideManagementPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 2. Users Management
              _buildAdminTile(
                icon: Icons.manage_accounts_rounded,
                iconColor: const Color(0xFF00BFA5),
                title: 'إدارة الحسابات والصلاحيات',
                subtitle: 'تعديل الأدوار، حظر الحسابات، وإدارة بيانات الزبائن والكباتن',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersManagementPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 3. Restaurants Management
              _buildAdminTile(
                icon: Icons.restaurant_rounded,
                iconColor: Colors.deepOrangeAccent,
                title: 'إدارة المطاعم والطلبات',
                subtitle: 'اعتماد طلبات انضمام المطاعم، إدارة قوائم الطعام، ومتابعة الطلبات',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantsManagementPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 4. Stores & Sales Management
              _buildAdminTile(
                icon: Icons.shopping_bag_rounded,
                iconColor: const Color(0xFF00897B),
                title: 'إدارة المتاجر وتحليل المبيعات',
                subtitle: 'مراقبة حركة البيع، المنتجات الأكثر طلباً، وإحصائيات المتاجر',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoresAnalyticsAndManagementPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 5. Madar Stores Orders
              _buildAdminTile(
                icon: Icons.storefront_rounded,
                iconColor: Colors.teal,
                title: 'طلبات متاجر مدار',
                subtitle: 'إدارة فواتير وطلبات المتاجر والتسليم',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MadarStoresOrdersManagementPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 6. Delivery Accounting
              _buildAdminTile(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: Colors.purpleAccent,
                title: 'المحاسبة الأسبوعية والذمم المالية',
                subtitle: 'كشوفات حسابات المندوبين والتجار، الأرباح والعمولات الأسبوعية',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryWeeklyAccountingPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 8. Transport Management
              _buildAdminTile(
                icon: Icons.airport_shuttle_rounded,
                iconColor: Colors.cyan,
                title: 'إدارة خطوط النقل والتوصيل',
                subtitle: 'متابعة رحلات النقل الجماعي والخطوط السريعة',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransportManagementPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 9. Governorates Management
              _buildAdminTile(
                icon: Icons.map_rounded,
                iconColor: Colors.indigoAccent,
                title: 'إدارة المحافظات والمناطق',
                subtitle: 'تفعيل المناطق وتعيين المدراء والمشرفين الإقليميين',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GovernoratesManagementPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 10. Complaints & Tickets
              _buildAdminTile(
                icon: Icons.receipt_long_rounded,
                iconColor: Colors.redAccent,
                title: 'إدارة الشكاوى والتذاكر',
                subtitle: 'متابعة شكاوى الزبائن والكباتن وحلها بسرعة',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComplaintsManagementPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 11. Live Support Chat
              _buildAdminTile(
                icon: Icons.support_agent_rounded,
                iconColor: const Color(0xFF00BFA5),
                title: 'الدعم الفني المباشر',
                subtitle: 'المحادثة الفورية مع المستخدمين وتلقي الاستفسارات',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TechnicalSupportChatPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 12. Sections & Content
              _buildAdminTile(
                icon: Icons.grid_view_rounded,
                iconColor: Colors.amber,
                title: 'إدارة الأقسام والصفحات',
                subtitle: 'تعديل وترتيب أقسام التطبيق والخدمات العامة',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllSectionsPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 13. Notifications Center
              _buildAdminTile(
                icon: Icons.notifications_active_rounded,
                iconColor: Colors.orangeAccent,
                title: 'مركز الإشعارات والتعاميم',
                subtitle: 'إرسال تنبيهات جماعية لكافة المستخدمين والكباتن والمتاجر',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 14. Limited Admins & Security
              _buildAdminTile(
                icon: Icons.admin_panel_settings_rounded,
                iconColor: Colors.blueGrey,
                title: 'إدارة المشرفين والقيود',
                subtitle: 'تحديد صلاحيات المشرفين وحماية العمليات الإدارية الحساسة',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LimitedAdminsManagementPage())),
                isDark: isDark,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Color(0xFF00BFA5),
        ),
      ),
    );
  }
}
