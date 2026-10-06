import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? customColor;
  final Border? border;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blur = 15,
    this.customColor,
    this.border,
    this.shadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultBgColor = isDark
        ? (customColor ?? app_colors.darkCard.withValues(alpha: 0.75))
        : (customColor ?? Colors.white.withValues(alpha: 0.85));

    final defaultBorder = border ??
        Border.all(
          color: isDark ? app_colors.darkBorderSubtle : Colors.white.withValues(alpha: 0.6),
          width: 1.2,
        );

    final defaultShadows = shadows ?? [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: defaultBgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: defaultBorder,
          ),
          child: child,
        ),
      ),
    );

    if (margin != null || defaultShadows.isNotEmpty) {
      content = Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: defaultShadows,
        ),
        child: content,
      );
    }

    if (onTap != null) {
      return RepaintBoundary(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    return RepaintBoundary(child: content);
  }
}
