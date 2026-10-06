// ملف وإعدادات مندوب التوصيل (Delivery Profile Settings View Widget)
// Presentation Layer — Pure UI Component

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeliveryProfileSettingsView extends StatelessWidget {
  final String driverName;
  final String driverPhone;
  final double rating;
  final bool isOnline;
  final bool isTogglingAvailability;
  final VoidCallback onToggleAvailability;
  final VoidCallback onEditProfile;
  final VoidCallback onSupportChat;
  final VoidCallback onSignOut;

  static const Color _primary = Color(0xFF00BFA5);
  static const Color _primaryDark = Color(0xFF00897B);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);

  const DeliveryProfileSettingsView({
    super.key,
    required this.driverName,
    required this.driverPhone,
    required this.rating,
    required this.isOnline,
    this.isTogglingAvailability = false,
    required this.onToggleAvailability,
    required this.onEditProfile,
    required this.onSupportChat,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          // بطاقة الملف الشخصي للمندوب
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _borderLight, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.person_rounded, size: 44, color: _primaryDark),
                ),
                const SizedBox(height: 12),
                Text(
                  driverName,
                  style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  driverPhone,
                  style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(تقييم الكابتن)',
                      style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // بطاقة التوفر والاتصال
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderLight, width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isOnline ? const Color(0xFF00C853) : Colors.grey).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: isOnline ? const Color(0xFF00C853) : _textSub,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOnline ? 'حالة التوفر: متصل' : 'حالة التوفر: أوفلاين',
                        style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOnline ? 'أنت جاهز لاستقبال الطلبات الفورية' : 'لن تظهر لك الطلبات في الرادار',
                        style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isOnline,
                  activeTrackColor: _primary,
                  onChanged: isTogglingAvailability ? null : (_) => onToggleAvailability(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // قائمة الإجراءات
          _buildSettingsTile(
            title: 'تعديل الملف الشخصي والمركبة',
            icon: Icons.edit_rounded,
            color: const Color(0xFF0284C7),
            onTap: onEditProfile,
          ),
          const SizedBox(height: 10),
          _buildSettingsTile(
            title: 'الدعم الفني والمساعدة',
            icon: Icons.support_agent_rounded,
            color: _primaryDark,
            onTap: onSupportChat,
          ),
          const SizedBox(height: 10),
          _buildSettingsTile(
            title: 'تسجيل الخروج من الحساب',
            icon: Icons.logout_rounded,
            color: const Color(0xFFE53935),
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderLight, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: _textSub, size: 16),
          ],
        ),
      ),
    );
  }
}
