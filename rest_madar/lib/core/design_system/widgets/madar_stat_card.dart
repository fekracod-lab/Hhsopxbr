import 'package:flutter/material.dart';
import '../madar_colors.dart';
import '../madar_radius.dart';
import '../madar_shadows.dart';
import '../madar_typography.dart';

/// =====================================================================
///  Madar Design System — بطاقة مؤشرات الأداء المتكيفة (Adaptive Stat Card)
/// =====================================================================
class MadarStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? unit;
  final IconData icon;
  final Color iconColor;
  final Color? iconBgColor;
  final String? trendText;
  final String? trendSubtitle;
  final bool isPositive;
  final VoidCallback? onTap;

  const MadarStatCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    required this.icon,
    this.iconColor = MadarColors.primary,
    this.iconBgColor,
    this.trendText,
    this.trendSubtitle,
    this.isPositive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconBg = iconBgColor ?? iconColor.withValues(alpha: 0.12);

    return InkWell(
      onTap: onTap,
      borderRadius: MadarRadius.md,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MadarColors.card,
          borderRadius: MadarRadius.md,
          border: Border.all(color: MadarColors.border),
          boxShadow: MadarShadows.subtle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── الصف العلوي: الأيقونة والعنوان ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: effectiveIconBg,
                    borderRadius: MadarRadius.sm,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: MadarTypography.caption(
                      color: MadarColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── القيمة الرقمية الكبرى مع الوحدة ──
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: MadarTypography.metricNumber(
                      color: MadarColors.textPrimary,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit!,
                      style: MadarTypography.caption(
                        color: MadarColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── المؤشر والنمو (Trend Indicator) ──
            if (trendText != null || trendSubtitle != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (trendText != null) ...[
                    Icon(
                      isPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 16,
                      color: isPositive ? MadarColors.success : MadarColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trendText!,
                      style: MadarTypography.caption(
                        color: isPositive ? MadarColors.success : MadarColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (trendSubtitle != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        trendSubtitle!,
                        style: MadarTypography.caption(
                          color: MadarColors.textDisabled,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
