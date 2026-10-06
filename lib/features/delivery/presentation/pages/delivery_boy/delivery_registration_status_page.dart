import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_dashboard_page.dart';
import 'package:dalal_alqaim/services/onesignal_service.dart';
import 'package:dalal_alqaim/widgets/premium_widgets.dart';

class DeliveryRegistrationStatusPage extends StatefulWidget {
  const DeliveryRegistrationStatusPage({super.key});

  @override
  State<DeliveryRegistrationStatusPage> createState() => _DeliveryRegistrationStatusPageState();
}

class _DeliveryRegistrationStatusPageState extends State<DeliveryRegistrationStatusPage> {
  static const Color _primary = Color(0xFF10B981); // Emerald Logistics Green
  static const Color _lightText = Color(0xFF1E293B);
  static const Color _lightSub = Color(0xFF64748B);

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
    HapticFeedback.lightImpact();
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUserRole');
    await prefs.remove('currentUserId');
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('لم يتم تسجيل الدخول')),
      );
    }

    final uid = user.uid;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                  builder: (context, userSnap) {
                    if (userSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _primary));
                    }

                    final userData = userSnap.data?.data() ?? {};

                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.collection('drivers').doc(uid).snapshots(),
                      builder: (context, driverSnap) {
                        final driverData = driverSnap.data?.data() ?? {};

                        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('delivery_boys').doc(uid).snapshots(),
                          builder: (context, delivSnap) {
                            final delivData = delivSnap.data?.data() ?? {};

                            final merged = {
                              ...userData,
                              ...driverData,
                              ...delivData,
                            };

                            return _buildContent(context, merged, uid);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.two_wheeler_rounded, color: _primary, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'حالة انضمام مندوب التوصيل',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _lightText,
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
            label: Text(
              'خروج',
              style: GoogleFonts.ibmPlexSansArabic(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data, String uid) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final isApproved = data['isApproved'] == true || status == 'active' || status == 'approved';

    final name = (data['fullName'] ?? data['name'] ?? 'مندوب مدار').toString();
    final phone = (data['phone'] ?? '-').toString();
    final vehicleType = (data['vehicleType'] ?? 'دراجة نارية / وسيلة توصيل').toString();
    final vehicleModel = (data['vehicleModel'] ?? '').toString();
    final plateNumber = (data['plateNumber'] ?? '').toString();
    final govName = (data['governorateName'] ?? 'العراق').toString();
    final regName = (data['regionName'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          // 1. Status Banner
          _buildStatusBanner(status, isApproved),

          const SizedBox(height: 20),

          // 2. Data Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.badge_rounded, color: _primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'بيانات طلب التوصيل المسجلة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                _buildInfoRow('الاسم الكامل', name),
                _buildInfoRow('رقم الهاتف', phone),
                _buildInfoRow('نوع الحساب', 'مندوب توصيل معتمد'),
                _buildInfoRow('وسيلة التوصيل', vehicleModel.isNotEmpty ? '$vehicleType ($vehicleModel)' : vehicleType),
                if (plateNumber.isNotEmpty) _buildInfoRow('رقم اللوحة / الترخيص', plateNumber),
                _buildInfoRow('المحافظة والمنطقة', regName.isNotEmpty ? '$govName - $regName' : govName),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. Actions / Navigation Button
          if (isApproved) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('currentUserRole_$uid', 'delivery');
                  await prefs.setString('currentUserRole', 'delivery');
                  await prefs.setString('currentUserId', uid);

                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const DeliveryDashboardPage()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
                label: Text(
                  'الدخول إلى لوحة تحكم التوصيل الآن',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم تحديث البيانات وفحص حالة القبول',
                        style: GoogleFonts.ibmPlexSansArabic(),
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 18, color: _primary),
                label: Text(
                  'تحديث وفحص حالة الاعتماد الآن',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.bold,
                    color: _primary,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Contact Support Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton.icon(
              onPressed: () => _openSupportContact(context),
              icon: const Icon(Icons.support_agent_rounded, size: 20, color: _lightSub),
              label: Text(
                'التواصل مع إدارة مناديب مدار للمساعدة',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: _lightSub,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String status, bool isApproved) {
    Color bg;
    Color border;
    Color iconColor;
    IconData icon;
    String title;
    String subtitle;

    if (isApproved) {
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
      iconColor = const Color(0xFF059669);
      icon = Icons.check_circle_rounded;
      title = 'تم تفعيل واعتماد حسابك بنجاح!';
      subtitle = 'أهلاً بك كابتن! يمكنك الآن فتح لوحة تحكم التوصيل وبدء استقبال طلبات الزبائن والمطاعم والمتاجر فوراً.';
    } else if (status == 'rejected') {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      iconColor = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
      title = 'تم رفض طلب الانضمام';
      subtitle = 'نعتذر منك، تم رفض الطلب لمراجعة البيانات. يرجى التواصل مع إدارة مدار لمعرفة الأسباب واستكمال النواقص.';
    } else {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      iconColor = const Color(0xFFD97706);
      icon = Icons.hourglass_top_rounded;
      title = 'طلبك قيد المراجعة والتدقيق';
      subtitle = 'تم استلام طلب انضمامك كمندوب توصيل في مدار بنجاح. يجري حالياً تدقيق بيانات المركبة والمستندات وسيتم إشعارك فور الاعتماد.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _lightText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12.5,
              color: _lightSub,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              color: _lightSub,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSupportContact(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الدعم الفني وإدارة مناديب مدار',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'فريق العمل جاهز لمساعدتك في تسريع وتدقيق طلب الانضمام.',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(color: _lightSub, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF25D366),
                  child: Icon(Icons.chat_rounded, color: Colors.white),
                ),
                title: Text('محادثة عبر واتساب', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w600)),
                subtitle: const Text('+964 780 000 0000', textDirection: TextDirection.ltr),
                onTap: () async {
                  Navigator.pop(context);
                  final uri = Uri.parse('https://wa.me/9647800000000?text=${Uri.encodeComponent('مرحباً إدارة مدار، أود الاستفسار عن حالة طلب انضمامي كمندوب توصيل')}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
