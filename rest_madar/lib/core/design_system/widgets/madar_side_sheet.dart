import 'package:flutter/material.dart';
import '../../responsive/madar_responsive.dart';
import '../madar_colors.dart';
import '../madar_shadows.dart';
import '../madar_typography.dart';

/// =====================================================================
///  Madar Design System — اللوح الجانبي المتكيف (Adaptive Side Sheet)
/// =====================================================================
class MadarSideSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget content;
  final Widget? footer;
  final VoidCallback? onClose;
  final double? width;

  const MadarSideSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.content,
    this.footer,
    this.onClose,
    this.width,
  });

  /// إطلاق اللوح كنافذة منزلقة (Modal Side Sheet) على أجهزة التابلت
  static Future<T?> showModal<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    Widget? leading,
    required Widget content,
    Widget? footer,
  }) {
    final sheetW = MadarResponsive.sideSheetWidth(context);

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SideSheet',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: sheetW,
                height: double.infinity,
                child: MadarSideSheet(
                  title: title,
                  subtitle: subtitle,
                  leading: leading,
                  content: content,
                  footer: footer,
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final offset = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic));

        return SlideTransition(position: offset, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: MadarColors.card,
        border: const Border(right: BorderSide(color: MadarColors.border, width: 1)),
        boxShadow: MadarShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── رأس اللوح الجانبي ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: MadarColors.border)),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: MadarTypography.sectionTitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: MadarTypography.caption(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: MadarColors.textSecondary,
                    onPressed: onClose,
                    splashRadius: 18,
                    tooltip: 'إغلاق',
                  ),
              ],
            ),
          ),

          // ── المحتوى القابل للتمرير ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: content,
            ),
          ),

          // ── التذييل والإجراءات ──
          if (footer != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: MadarColors.background,
                border: Border(top: BorderSide(color: MadarColors.border)),
              ),
              child: footer!,
            ),
        ],
      ),
    );
  }
}
