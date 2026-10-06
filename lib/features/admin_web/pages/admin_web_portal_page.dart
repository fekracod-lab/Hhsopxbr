import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/services/audit_log_service.dart';
import 'package:dalal_alqaim/core/security/web_session_guard.dart';

// Admin Sub-pages
import 'package:dalal_alqaim/pages/admin_dashboard_page.dart';
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

/// Modern Responsive Admin Web Portal & Comprehensive Management Shell
class AdminWebPortalPage extends StatefulWidget {
  const AdminWebPortalPage({super.key});

  @override
  State<AdminWebPortalPage> createState() => _AdminWebPortalPageState();
}

class _AdminWebPortalPageState extends State<AdminWebPortalPage> {
  int _selectedNavIndex = 0;
  bool _isAuthorizedAdmin = false;
  bool _isCheckingAuth = true;
  String _adminRole = '';
  String _adminName = '';

  // Direct Admin Login Form State
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoggingIn = false;
  String? _loginError;

  final List<Map<String, dynamic>> _navItems = [
    {'title': 'لوحة الإحصائيات العامة', 'icon': Icons.dashboard_rounded, 'badge': null},
    {'title': 'إدارة التاكسي والرحلات', 'icon': Icons.local_taxi_rounded, 'badge': 'نشط'},
    {'title': 'إدارة المستخدمين والأدوار', 'icon': Icons.people_alt_rounded, 'badge': null},
    {'title': 'إدارة المطاعم والطلبات', 'icon': Icons.restaurant_rounded, 'badge': null},
    {'title': 'إدارة المتاجر والمبيعات', 'icon': Icons.shopping_bag_rounded, 'badge': 'جديد'},
    {'title': 'طلبات متاجر مدار', 'icon': Icons.storefront_rounded, 'badge': null},
    {'title': 'المحاسبة والذمم المالية', 'icon': Icons.account_balance_wallet_rounded, 'badge': null},
    {'title': 'إدارة النقل والتوصيل', 'icon': Icons.airport_shuttle_rounded, 'badge': null},
    {'title': 'إدارة المحافظات والمناطق', 'icon': Icons.map_rounded, 'badge': null},
    {'title': 'إدارة الشكاوى والتذاكر', 'icon': Icons.receipt_long_rounded, 'badge': null},
    {'title': 'الدعم الفني المباشر', 'icon': Icons.support_agent_rounded, 'badge': 'مباشر'},
    {'title': 'إدارة الأقسام والصفحات', 'icon': Icons.grid_view_rounded, 'badge': null},
    {'title': 'إرسال الإشعارات والتعاميم', 'icon': Icons.notifications_active_rounded, 'badge': null},
    {'title': 'إدارة المشرفين والقيود', 'icon': Icons.admin_panel_settings_rounded, 'badge': 'آمن'},
    {'title': 'سجل الأمان والعمليات (Audit)', 'icon': Icons.shield_rounded, 'badge': 'SECURITY'},
  ];

  @override
  void initState() {
    super.initState();
    _verifyAdminRole();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyAdminRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _setUnauthorized();
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        _setUnauthorized();
        return;
      }

      final data = doc.data() ?? {};
      final role = (data['role'] ?? '').toString().toLowerCase();
      final status = (data['status'] ?? 'active').toString().toLowerCase();

      final allowedAdminRoles = [
        'admin',
        'super_admin',
        'main_admin',
        'limited_admin',
        'complaints_admin',
        'governorate_manager',
      ];

      if (allowedAdminRoles.contains(role) && (status == 'active' || status == 'approved')) {
        if (mounted) {
          setState(() {
            _isAuthorizedAdmin = true;
            _isCheckingAuth = false;
            _adminRole = role;
            _adminName = data['name']?.toString() ?? 'مشرف النظام';
            _loginError = null;
          });
        }
        // Log access audit
        AuditLogService.logAction(
          action: 'WEB_PORTAL_ACCESS',
          targetId: user.uid,
          targetType: 'admin_session',
          details: {'role': role, 'accessTime': DateTime.now().toIso8601String()},
        );
      } else {
        _setUnauthorized('حسابك الحالي لا يملك صلاحيات المشرفين والإدارة.');
      }
    } catch (e) {
      debugPrint(' Admin Web Verification Error: $e');
      _setUnauthorized('حدث خطأ في التحقق من البيانات.');
    }
  }

  void _setUnauthorized([String? errorMsg]) {
    if (mounted) {
      setState(() {
        _isAuthorizedAdmin = false;
        _isCheckingAuth = false;
        if (errorMsg != null) _loginError = errorMsg;
      });
    }
  }

  Future<void> _handleAdminLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _loginError = 'يرجى إدخال البريد الإلكتروني وكلمة المرور');
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _loginError = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _verifyAdminRole();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoggingIn = false;
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _loginError = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
        } else {
          _loginError = 'خطأ في تسجيل الدخول: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoggingIn = false;
        _loginError = 'صار خطأ، حاول مرة ثانية: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: app_colors.primaryColor),
              SizedBox(height: 16),
              Text(
                'جاري التحقق من أمان وصلاحيات الجلسة...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isAuthorizedAdmin) {
      return _buildAdminLoginView();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;

        // Sidebar Navigation
        Widget sidebarContent = Container(
          width: 280,
          color: const Color(0xFF1E293B),
          child: Column(
            children: [
              // Header Brand
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00BFA5), Color(0xFF004D40)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.security_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'منصة مَـــدار',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'لوحة التحكم والإدارة الشاملة',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF00BFA5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Navigation List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  itemCount: _navItems.length,
                  itemBuilder: (context, index) {
                    final item = _navItems[index];
                    final isSelected = _selectedNavIndex == index;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() => _selectedNavIndex = index);
                            if (!isDesktop) Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF00BFA5).withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(color: const Color(0xFF00BFA5).withValues(alpha: 0.4), width: 1)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  color: isSelected ? const Color(0xFF00BFA5) : Colors.white70,
                                  size: 19,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item['title'] as String,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : Colors.white70,
                                    ),
                                  ),
                                ),
                                if (item['badge'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF00BFA5) : const Color(0xFF334155),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      item['badge'] as String,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.black87 : Colors.white70,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Admin User Info & Logout
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF00BFA5), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _adminName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _adminRole.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                      tooltip: 'تسجيل الخروج',
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        _verifyAdminRole();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        // Main View
        Widget mainBody = Column(
          children: [
            // Top Bar
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
              ),
              child: Row(
                children: [
                  if (!isDesktop)
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu_rounded, color: Colors.white),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
                  Text(
                    _navItems[_selectedNavIndex]['title'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // Refresh Button
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    tooltip: 'تحديث البيانات',
                    onPressed: () => setState(() {}),
                  ),
                ],
              ),
            ),

            // Content Area (IndexedStack for all administrative modules)
            Expanded(
              child: Container(
                color: const Color(0xFF0F172A),
                child: IndexedStack(
                  index: _selectedNavIndex,
                  children: [
                    const AdminDashboardPage(),
                    const RideManagementPage(),
                    const UsersManagementPage(),
                    const RestaurantsManagementPage(),
                    const StoresAnalyticsAndManagementPage(),
                    const MadarStoresOrdersManagementPage(),
                    const DeliveryWeeklyAccountingPage(),
                    const TransportManagementPage(),
                    const GovernoratesManagementPage(),
                    const ComplaintsManagementPage(),
                    const TechnicalSupportChatPage(),
                    const AllSectionsPage(),
                    const NotificationsPage(),
                    const LimitedAdminsManagementPage(),
                    _buildAuditLogsView(),
                  ],
                ),
              ),
            ),
          ],
        );

        return WebSessionGuard(
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            drawer: !isDesktop ? Drawer(child: sidebarContent) : null,
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: isDesktop
                  ? Row(
                      children: [
                        sidebarContent,
                        Expanded(child: mainBody),
                      ],
                    )
                  : mainBody,
            ),
          ),
        );
      },
    );
  }

  /// Real-time Security Audit Log Viewer
  Widget _buildAuditLogsView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'سجل العمليات والأمان الإدارية (Audit Logs)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'يتم توثيق كافة تغييرات الصلاحيات والموافقة على الكباتن وحظر الحسابات والتعديلات المالية فورياً بختم زمني.',
            style: TextStyle(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AuditLogService.getAuditLogsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: app_colors.primaryColor));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('لا توجد سجلات أمان مسجلة حالياً', style: TextStyle(color: Colors.white54)),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final action = data['action'] ?? 'UNKNOWN_ACTION';
                    final adminName = data['adminName'] ?? 'مشرف';
                    final targetId = data['targetId'] ?? '-';
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                    final platform = data['platform'] ?? 'web';

                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.2),
                          child: const Icon(Icons.security_rounded, color: Colors.blueAccent),
                        ),
                        title: Text(
                          'الإجراء: $action | بواسطة: $adminName',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        subtitle: Text(
                          'المستهدف: $targetId | المنصة: $platform | الوقت: ${timestamp != null ? timestamp.toString().substring(0, 19) :'الآن'}',
                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ),
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

  /// Admin Login Interface (Glassmorphic)
  Widget _buildAdminLoginView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF334155), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00BFA5), Color(0xFF004D40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'بوابة الإدارة والحوكمة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'تسجيل الدخول للمشرفين والمدراء المعتمدين',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_loginError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _loginError!,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Email
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'البريد الإلكتروني للإدارة',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00BFA5), size: 20),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF00BFA5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Password
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'كلمة المرور',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF00BFA5), size: 20),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF00BFA5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFA5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _isLoggingIn ? null : _handleAdminLogin,
                      child: _isLoggingIn
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'تسجيل الدخول للوحة التحكم',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
