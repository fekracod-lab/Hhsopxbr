import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// شرائح الحالة الموحّدة (جاهز / جاري التحضير / مكتمل / معلق / أوفلاين ...)
class PosStatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;

  const PosStatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? color
            : color.withValues(alpha: context.isDarkMode ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: filled ? 0 : 0.45),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: filled ? Colors.white : color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              color: filled ? Colors.white : color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// دوّارة حالة دائرية صغيرة (نقطة ملونة)
class PosDot extends StatelessWidget {
  final Color color;
  final double size;
  const PosDot({super.key, required this.color, this.size = 9});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}