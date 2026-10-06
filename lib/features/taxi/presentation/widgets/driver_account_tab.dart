import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/driver_dashboard_models.dart';
import '../pages/captain/driver_settings_page.dart';
import '../pages/captain/wallet_page.dart';
import '../../../../pages/technical_support_chat_page.dart';

/// تبويب الحساب والإعدادات وتسجيل الخروج للكابتن
class DriverAccountTab extends StatelessWidget {
  final DriverProfileEntity? profile;
  final DriverStatsEntity? stats;
  final VoidCallback onSignOut;
  final VoidCallback onOpenMyWay;
  final VoidCallback onNavigateToHistory;

  const DriverAccountTab({
    super.key,
    required this.profile,
    required this.stats,
    required this.onSignOut,
    required this.onOpenMyWay,
    required this.onNavigateToHistory,
  });

  static const Color _bgDark = Color(0xFF0F172A);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _primaryTeal = Color(0xFF26A69A);
  static const Color _accentGold = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final driverName = (profile?.name != null && profile!.name.isNotEmpty)
        ? profile!.name
        : 'كابتن مدار';
    final driverPhone = profile?.phone ?? '';
    final rating = profile?.rating ?? 5.0;
    final walletBalance = profile?.walletBalance ?? 0.0;
    final isOnline = profile?.isOnline ?? false;
    final photoUrl = profile?.photoUrl;

    return Container(
      color: _bgDark,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── بطاقة الملف الشخصي الرئيسية ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // صورة الكابتن مع شارة الحالة
                    Stack(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isOnline ? const Color(0xFF10B981) : Colors.white24,
                              width: 2.5,
                            ),
                          ),
                          child: ClipOval(
                            child: (photoUrl != null && photoUrl.isNotEmpty)
                                ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar())
                                : _defaultAvatar(),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(color: _cardBg, width: 2.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // الاسم ورقم الهاتف والشارة
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  driverName,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _accentGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _accentGold.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: _accentGold, size: 14),
                                    const SizedBox(width: 3),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: _accentGold,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            driverPhone.isNotEmpty ? driverPhone : 'حساب كابتن موثق',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isOnline ? const Color(0xFF10B981) : Colors.white12).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOnline ? 'الكابتن متصل ومتاح' : 'الكابتن غير متصل حالياً',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isOnline ? const Color(0xFF10B981) : Colors.white54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 14),
                // زر الدخول المباشر لتعديل الحساب والسيارة
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DriverSettingsPage()),
                      );
                    },
                    icon: const Icon(Icons.tune_rounded, size: 18, color: _primaryTeal),
                    label: Text(
                      'تعديل الملف الشخصي وبيانات السيارة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: _primaryTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _primaryTeal.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── بطاقات الإحصائيات السريعة ──
          Row(
            children: [
              // رصيد المحفظة
              Expanded(
                child: _buildQuickStatCard(
                  title: 'رصيد المحفظة',
                  value: '${walletBalance.toStringAsFixed(0)} د.ع',
                  icon: Icons.account_balance_wallet_rounded,
                  color: _primaryTeal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WalletPage()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              // رحلات اليوم
              Expanded(
                child: _buildQuickStatCard(
                  title: 'رحلات اليوم',
                  value: '${stats?.todayCompletedTrips ?? 0} رحلة',
                  icon: Icons.local_taxi_rounded,
                  color: _accentGold,
                  onTap: onNavigateToHistory,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── قائمة الإعدادات والأقسام ──
          Text(
            'الإعدادات والخدمات',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                _buildMenuTile(
                  icon: Icons.tune_rounded,
                  title: 'إعدادات الكابتن والتنبيهات',
                  subtitle: 'أصوات الإشعار، القبول التلقائي، بيانات المركبة',
                  iconColor: _primaryTeal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DriverSettingsPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'المحفظة والشحن',
                  subtitle: 'سجل العمليات، العمولة، وتصفية الرصيد',
                  iconColor: _primaryTeal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WalletPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.history_rounded,
                  title: 'سجل الرحلات السابقة',
                  subtitle: 'عرض كافة الرحلات المكتملة والملغاة',
                  iconColor: const Color(0xFF60A5FA),
                  onTap: onNavigateToHistory,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.alt_route_rounded,
                  title: 'ميزة درب الرجعة',
                  subtitle: 'توجيه الرحلات نحو منطقتك فقط',
                  iconColor: _accentGold,
                  onTap: onOpenMyWay,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.headset_mic_rounded,
                  title: 'الدعم الفني والمساعدة',
                  subtitle: 'تواصل مباشر مع فريق دعم كباتن مدار',
                  iconColor: const Color(0xFFA78BFA),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TechnicalSupportChatPage()),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── زر تسجيل الخروج الصريح والواضح ──
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
              label: Text(
                'تسجيل الخروج من الحساب',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // رقم الإصدار والحقوق
          Center(
            child: Text(
              'مدار كابتن • الإصدار 2.5.0 Enterprise',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11,
                color: Colors.white30,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: Colors.white10,
      child: const Icon(Icons.person, size: 36, color: Colors.white70),
    );
  }

  Widget _buildQuickStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.ibmPlexSansArabic(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 11,
          color: Colors.white54,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white30),
    );
  }

  Widget _buildDivider() {
    return const Divider(color: Colors.white10, height: 1, indent: 60, endIndent: 16);
  }
}
