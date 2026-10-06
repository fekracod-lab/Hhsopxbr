import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../responsive/madar_responsive.dart';
import '../madar_colors.dart';
import '../madar_radius.dart';
import '../madar_typography.dart';

/// =====================================================================
///  Madar Design System — النافذة الحوارية التكيفية الذكية
///  تضمن عدم حدوث Overflow على أي قياس شاشة أو اتجاه في iPad أو Windows
/// =====================================================================
class MadarAdaptiveDialog extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String? subtitle;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final EdgeInsets padding;

  const MadarAdaptiveDialog({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.content,
    this.actions,
    this.maxWidth = 520.0,
    this.padding = const EdgeInsets.all(22.0),
  });

  static Future<T?> show<T>(
    BuildContext context, {
    Widget? icon,
    required String title,
    String? subtitle,
    required Widget content,
    List<Widget>? actions,
    double maxWidth = 520.0,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => MadarAdaptiveDialog(
        icon: icon,
        title: title,
        subtitle: subtitle,
        content: content,
        actions: actions,
        maxWidth: maxWidth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MadarResponsive.widthOf(context);
    final screenH = MadarResponsive.heightOf(context);
    final effectiveWidth = math.min(maxWidth, screenW - 32.0);
    final maxHeight = screenH * 0.88;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: MadarColors.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: MadarRadius.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: effectiveWidth,
            maxHeight: maxHeight,
          ),
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── رأس الحوار (Header) ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: MadarTypography.sectionTitle(),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              style: MadarTypography.caption(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: MadarColors.textSecondary,
                      splashRadius: 18,
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: MadarColors.border, height: 1),
                const SizedBox(height: 16),

                // ── محتوى الحوار القابل للتمرير الآمن ──
                Flexible(
                  child: SingleChildScrollView(
                    child: content,
                  ),
                ),

                // ── أزرار الإجراءات (Actions) ──
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
