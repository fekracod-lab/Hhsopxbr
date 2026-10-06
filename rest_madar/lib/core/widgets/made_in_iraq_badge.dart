import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// =====================================================================
///  Made in Iraq Badge (شعار صُنع في العراق الفاخر)
///  ── علامة فخر تقنية وطنية تبرز هوية النظام البرمجية العراقية 100%
/// =====================================================================
class MadeInIraqBadge extends StatelessWidget {
  final bool isCompact;
  final bool showArabicSubtext;
  final VoidCallback? onTap;

  const MadeInIraqBadge({
    super.key,
    this.isCompact = false,
    this.showArabicSubtext = true,
    this.onTap,
  });

  void _showPrideInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF15181F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF2E384D), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCE1126).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🇮🇶', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MADE IN IRAQ • صُنع في العراق',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'هندسة وبرمجة وتصميم وطني 100%',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E2533), Color(0xFF141923)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF5B22).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: Color(0xFFFF5B22), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'منظومة مدار المتكاملة للمطاعم والكافيهات',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'طُوّرت المنظومة بالكامل في العراق لتلائم خصوصية وسرعة المطاعم العراقية واحتياجات الكاشير والمطبخ والزبائن، بدعم كامل للدينار العراقي وبأحدث تقنيات الـ Cloud والمزامنة السحابية اللحظية.',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFFBAC2CD),
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCityChip('بغداد 🏛️'),
                  _buildCityChip('القائم 🌴'),
                  _buildCityChip('أربيل 🏔️'),
                  _buildCityChip('البصرة 🌊'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'إغلاق',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: const Color(0xFFFF5B22),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildCityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3448)),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          color: const Color(0xFFE2E8F0),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return InkWell(
        onTap: onTap ?? () => _showPrideInfo(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A2130), Color(0xFF121722)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF5B22).withValues(alpha: 0.35),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇮🇶', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 4),
              Text(
                'MADE IN IRAQ',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: const Color(0xFFF1F5F9),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap ?? () => _showPrideInfo(context),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1B2333),
              Color(0xFF121722),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFF5B22).withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5B22).withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFCE1126).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: const Color(0xFFCE1126).withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: const Text('🇮🇶', style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 7),
            Text(
              'MADE IN IRAQ',
              style: GoogleFonts.ibmPlexSansArabic(
                color: const Color(0xFFF8FAFC),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            if (showArabicSubtext) ...[
              const SizedBox(width: 6),
              Container(
                width: 3.5,
                height: 3.5,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'صُنع في العراق',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: const Color(0xFFCBD5E1),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
