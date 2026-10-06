import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// عنوان قسم موحّد داخل الشاشات (مع خط فاصل اختياري)
class PosSectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;

  const PosSectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: c.accent),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: GoogleFonts.ibmPlexSansArabic(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}