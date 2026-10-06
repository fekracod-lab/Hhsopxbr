import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dalal_alqaim/services/onesignal_service.dart';
import 'package:dalal_alqaim/widgets/premium_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurant_dashboard_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/store_dashboard_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_dashboard_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_dashboard_page.dart';

// --- Palette ---
const Color _primary = Color(0xFF26A69A);
const Color _lightText = Color(0xFF2C3E50);
const Color _lightSub = Color(0xFF7F8C8D);

class DriverRegistrationStatusPage extends StatefulWidget {
  const DriverRegistrationStatusPage({super.key});

  @override
  State<DriverRegistrationStatusPage> createState() => _DriverRegistrationStatusPageState();
}

class _DriverRegistrationStatusPageState extends State<DriverRegistrationStatusPage> {
  @override
  void initState() {
    super.initState();
    _syncOneSignal();
  }

  Future<void> _syncOneSignal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await OneSignalService.syncUserRole(user.uid);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('لم يتم تسجيل الدخول')));
    }

    final uid = user.uid;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // --- Background pattern ---
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Image.asset(
                  'assets/images/aviation_bg_pattern.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(context),
                  
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.collection('driver_requests').doc(uid).snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: _primary));
                        }

                        final data = snap.data?.data();
                        if (data == null) {
                          return _fallbackFromUsers(uid: uid);
                        }

                        return _buildContent(data);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'حالة الانضمام',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _primary,
            ),
          ),
          TextButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
            label: const Text(
              'خروج',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackFromUsers({required String uid}) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }
        final userData = userSnap.data?.data() ?? {};
        final role = (userData['role'] ?? '').toString().toLowerCase();
        final subRole = (userData['subRole'] ?? '').toString().toLowerCase();

        // If user is a restaurant, stream the restaurants collection too
        if (role == 'restaurant' || subRole == 'restaurant') {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('restaurants').doc(uid).snapshots(),
            builder: (context, restSnap) {
              final restData = restSnap.data?.data() ?? {};
              final restStatus = (restData['status'] ?? '').toString().toLowerCase();
              final isRestApproved = restData['isApproved'] == true ||
                  (restData['isSuspended'] == false && restStatus != 'pending') ||
                  restStatus == 'active' ||
                  restStatus == 'approved';

              final effectiveStatus = isRestApproved
                  ? 'active'
                  : (restStatus.isNotEmpty ? restStatus : (userData['status'] ?? 'pending'));

              final merged = {
                ...userData,
                ...restData,
                'role': 'restaurant',
                'name': restData['restaurantName'] ?? restData['name'] ?? userData['name'] ?? userData['fullName'] ?? '',
                'status': effectiveStatus,
                'isApproved': isRestApproved || userData['isApproved'] == true,
              };

              // Auto-sync users doc if approved in restaurants
              if (isRestApproved && (userData['status'] != 'active' || userData['isApproved'] != true)) {
                FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'status': 'active',
                  'isApproved': true,
                  'role': 'restaurant',
                }).catchError((_) {});
              }

              return _buildContent(merged);
            },
          );
        }

        // If user is a store, stream the stores collection too
        if (role == 'store' || subRole == 'store') {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('stores').doc(uid).snapshots(),
            builder: (context, storeSnap) {
              final storeData = storeSnap.data?.data() ?? {};
              final storeStatus = (storeData['status'] ?? '').toString().toLowerCase();
              final isStoreApproved = storeData['isApproved'] == true ||
                  storeStatus == 'active' ||
                  storeStatus == 'approved';

              final effectiveStatus = isStoreApproved
                  ? 'active'
                  : (storeStatus.isNotEmpty ? storeStatus : (userData['status'] ?? 'pending'));

              final merged = {
                ...userData,
                ...storeData,
                'role': 'store',
                'name': storeData['storeName'] ?? storeData['name'] ?? userData['name'] ?? userData['fullName'] ?? '',
                'status': effectiveStatus,
                'isApproved': isStoreApproved || userData['isApproved'] == true,
              };

              if (isStoreApproved && (userData['status'] != 'active' || userData['isApproved'] != true)) {
                FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'status': 'active',
                  'isApproved': true,
                  'role': 'store',
                }).catchError((_) {});
              }

              return _buildContent(merged);
            },
          );
        }

        // If user is a taxi captain / driver, stream drivers collection too
        if (role == 'captain' || role == 'driver' || role == 'taxi_captain' || subRole == 'captain' || subRole == 'driver') {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('drivers').doc(uid).snapshots(),
            builder: (context, drSnap) {
              final drData = drSnap.data?.data() ?? {};
              final drStatus = (drData['status'] ?? '').toString().toLowerCase();
              final isDrApproved = drData['isApproved'] == true ||
                  drStatus == 'active' ||
                  drStatus == 'approved';

              final effectiveStatus = isDrApproved
                  ? 'active'
                  : (drStatus.isNotEmpty ? drStatus : (userData['status'] ?? 'pending'));

              final merged = {
                ...userData,
                ...drData,
                'role': 'captain',
                'name': drData['name'] ?? drData['fullName'] ?? userData['name'] ?? userData['fullName'] ?? '',
                'status': effectiveStatus,
                'isApproved': isDrApproved || userData['isApproved'] == true,
              };

              if (isDrApproved && (userData['status'] != 'active' || userData['isApproved'] != true)) {
                FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'status': 'active',
                  'isApproved': true,
                  'role': 'driver',
                }).catchError((_) {});
              }

              return _buildContent(merged);
            },
          );
        }

        // If user is a delivery boy / captain, stream delivery_boys collection too
        if (role == 'delivery' || role == 'delivery_boy' || role == 'delivery_captain' || subRole == 'delivery') {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('delivery_boys').doc(uid).snapshots(),
            builder: (context, delivSnap) {
              final delivData = delivSnap.data?.data() ?? {};
              final delivStatus = (delivData['status'] ?? '').toString().toLowerCase();
              final isDelivApproved = delivData['isApproved'] == true ||
                  delivStatus == 'active' ||
                  delivStatus == 'approved';

              final effectiveStatus = isDelivApproved
                  ? 'active'
                  : (delivStatus.isNotEmpty ? delivStatus : (userData['status'] ?? 'pending'));

              final merged = {
                ...userData,
                ...delivData,
                'role': 'delivery',
                'name': delivData['name'] ?? delivData['fullName'] ?? userData['name'] ?? userData['fullName'] ?? '',
                'status': effectiveStatus,
                'isApproved': isDelivApproved || userData['isApproved'] == true,
              };

              if (isDelivApproved && (userData['status'] != 'active' || userData['isApproved'] != true)) {
                FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'status': 'active',
                  'isApproved': true,
                  'role': 'delivery',
                }).catchError((_) {});
              }

              return _buildContent(merged);
            },
          );
        }

        final Map<String, dynamic> mapped = {
          ...userData,
          'name': userData['fullName'] ?? userData['name'] ?? '',
        };
        return _buildContent(mapped);
      },
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final role = (data['role'] ?? 'captain').toString().toLowerCase();

    String roleLabel = 'حساب مدار';
    if (role == 'captain') roleLabel = 'كابتن تكسي';
    if (role == 'restaurant') roleLabel = 'صاحب مطعم';
    if (role == 'store' || role == 'merchant') roleLabel = 'صاحب متجر';
    if (role == 'delivery') roleLabel = 'مندوب توصيل';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // ── Status Banner (Premium) ──
          _buildPremiumStatusCard(status, roleLabel),

          const SizedBox(height: 32),

          // ── Data Card ──
          GlassCard(
            opacity: 0.6,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined, color: _primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'بيانات $roleLabel المسجلة',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primary),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _dataRow('الاسم الكامل', data['name'] ?? data['fullName'] ?? data['ownerName'] ?? '-'),
                  _dataRow('رقم الهاتف', data['phone'] ?? '-'),
                  _dataRow('نوع الحساب', roleLabel),
                  if (data['governorateName'] != null) _dataRow('المحافظة', data['governorateName']),
                  if (data['regionName'] != null) _dataRow('المنطقة', data['regionName']),
                  if (data['carType'] != null || data['vehicleType'] != null)
                    _dataRow('وسيلة النقل', '${data['vehicleType'] ?? data['carType'] ?? ''} ${data['vehicleModel'] ?? data['carModel'] ?? ''}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── Supportive Message ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                const Icon(Icons.info_outline_rounded, color: _primary, size: 24),
                const SizedBox(height: 12),
                Text(
                  _getStatusMessage(status, roleLabel),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _lightSub,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                // --- In-App Support & Navigation Options ---
                if (status == 'approved' || status == 'active' || data['isApproved'] == true) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        final prefs = await SharedPreferences.getInstance();
                        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                        if (currentUid.isNotEmpty) {
                          await prefs.setString('currentUserRole_$currentUid', role);
                        }
                        if (!context.mounted) return;
                        if (role == 'restaurant') {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const RestaurantDashboardPage()),
                            (route) => false,
                          );
                        } else if (role == 'store' || role == 'market') {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => StoreDashboardPage(storeId: currentUid)),
                            (route) => false,
                          );
                        } else if (role == 'delivery') {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const DeliveryDashboardPage()),
                            (route) => false,
                          );
                        } else {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const DriverDashboardPage()),
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 22),
                      label: Text(
                        'الدخول إلى لوحة تحكم $roleLabel الآن',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: _primary),
                      label: const Text('تحديث وفحص حالة الموافقة الآن', style: TextStyle(fontWeight: FontWeight.bold, color: _primary)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: _primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('الدعم الفني والتحقق', style: TextStyle()),
                          content: const Text(
                            'طلبك حالياً تحت التدقيق من قبل فريق الإدارة. سيتم إشعاراتكم بالفبول فور انتهاء المراجعة.',
                            style: TextStyle(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                launchUrl(Uri.parse('https://wa.me/9647712345678'));
                              },
                              child: const Text('مراسلة عبر واتساب'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('حسناً'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
                    label: const Text('تواصل مع الدعم الفني', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await OneSignalService.logout();
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    label: const Text('تسجيل الخروج والعودة للرئيسية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStatusCard(String status, String roleLabel) {
    Color color;
    IconData icon;
    String label;

    if (status == 'approved' || status == 'active') {
      color = Colors.green;
      icon = Icons.verified_rounded;
      label = 'تم قبول طلبك';
    } else if (status == 'pending' || status == 'under_review') {
      color = Colors.orange;
      icon = Icons.hourglass_top_rounded;
      label = 'طلب $roleLabel قيد المراجعة';
    } else {
      color = Colors.redAccent;
      icon = Icons.cancel_rounded;
      label = 'الطلب مرفوض';
    }

    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(icon, size: 120, color: color.withValues(alpha: 0.1)),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 42),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: _lightSub, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: _lightText, fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusMessage(String status, String roleLabel) {
    if (status == 'pending' || status == 'under_review') {
      return 'نحن نقوم بمراجعة بياناتك وصحة المستندات المرفوعة حالياً. ستتلقى إشعاراً فور تفعيل حسابك كـ ($roleLabel) في منصة مدار.';
    }
    if (status == 'approved' || status == 'active') {
      return 'تهانينا! حسابك مفعل الآن. يمكنك الدخول مباشرة إلى لوحة التحكم الخاصة بك.';
    }
    return 'عذراً، لم نتمكن من قبول طلبك كـ ($roleLabel) في الوقت الحالي. يرجى مراجعة البيانات والتواصل مع الدعم الفني.';
  }
}
