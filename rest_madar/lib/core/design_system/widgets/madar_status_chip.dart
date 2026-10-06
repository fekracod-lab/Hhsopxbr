import 'package:flutter/material.dart';
import '../madar_colors.dart';
import '../madar_radius.dart';
import '../madar_typography.dart';

/// =====================================================================
///  Madar Design System — شريحة الحالة الموحدة (Adaptive Status Chip)
/// =====================================================================
class MadarStatusChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color? backgroundColor;

  const MadarStatusChip({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    this.backgroundColor,
  });

  factory MadarStatusChip.success({required String label, IconData? icon}) =>
      MadarStatusChip(
        label: label,
        icon: icon ?? Icons.check_circle_rounded,
        color: MadarColors.success,
        backgroundColor: MadarColors.successSoft,
      );

  factory MadarStatusChip.warning({required String label, IconData? icon}) =>
      MadarStatusChip(
        label: label,
        icon: icon ?? Icons.hourglass_top_rounded,
        color: MadarColors.warning,
        backgroundColor: MadarColors.warningSoft,
      );

  factory MadarStatusChip.danger({required String label, IconData? icon}) =>
      MadarStatusChip(
        label: label,
        icon: icon ?? Icons.cancel_rounded,
        color: MadarColors.danger,
        backgroundColor: MadarColors.dangerSoft,
      );

  factory MadarStatusChip.info({required String label, IconData? icon}) =>
      MadarStatusChip(
        label: label,
        icon: icon ?? Icons.info_outline_rounded,
        color: MadarColors.info,
        backgroundColor: MadarColors.infoSoft,
      );

  factory MadarStatusChip.neutral({required String label, IconData? icon}) =>
      MadarStatusChip(
        label: label,
        icon: icon,
        color: MadarColors.textSecondary,
        backgroundColor: MadarColors.background,
      );

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: MadarRadius.xs,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: MadarTypography.caption(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
