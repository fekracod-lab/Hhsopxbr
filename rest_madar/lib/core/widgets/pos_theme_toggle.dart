import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// زر تبديل هوية المظهر (فاتح/داكن) مع حفظ تلقائي — بدون أي تأثير على قواعد البيانات
class PosThemeToggle extends StatelessWidget {
  final bool compact;

  /// عند true يظهر كزر مربع صغير (للشريط العلوي)
  final bool iconOnly;

  const PosThemeToggle({super.key, this.compact = false, this.iconOnly = false});

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    return ListenableBuilder(
      listenable: PosThemeController.instance,
      builder: (context, _) {
        final isDark = context.isDarkMode;
        return InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            PosThemeController.instance.toggle();
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: iconOnly ? 9 : 12,
              vertical: iconOnly ? 9 : 8,
            ),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: iconOnly
                ? Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 17,
                    color: isDark ? c.gold : c.primary,
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 16,
                        color: isDark ? c.gold : c.primary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        isDark ? 'وضع فاتح' : 'وضع داكن',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}