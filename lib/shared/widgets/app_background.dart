import 'package:flutter/material.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class AppBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final bool showBlurCircles;

  const AppBackground({super.key, required this.child, this.colors, this.showBlurCircles = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    final defaultColors =
        isDark
            ? [const Color(0xFF0F0F0F), const Color(0xFF1A0A0A), const Color(0xFF0A1A0D)]
            : [const Color(0xFFFDFDFD), const Color(0xFFF5FDF5), const Color(0xFFFDFCF5)];

    return Stack(
      children: [
        // Base Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors ?? defaultColors,
            ),
          ),
        ),
        // Decorative Circles (lightweight, no blur)
        if (showBlurCircles) ...[
          _PositionedCircle(
            top: -100,
            right: -100,
            size: 400,
            color: app_colors.primaryColor.withValues(alpha: isDark ? 0.08 : 0.03),
          ),
          _PositionedCircle(
            top: size.height * 0.3,
            left: -150,
            size: 350,
            color: app_colors.accentColor.withValues(alpha: isDark ? 0.06 : 0.02),
          ),
          _PositionedCircle(
            bottom: -50,
            left: size.width * 0.2,
            size: 300,
            color: app_colors.primaryColor.withValues(alpha: isDark ? 0.05 : 0.015),
          ),
        ],
        // Lightweight overlay (no BackdropFilter)
        Positioned.fill(
          child: Container(
            color:
                isDark
                    ? Colors.black.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child,
      ],
    );
  }
}

class _PositionedCircle extends StatelessWidget {
  final double? top, bottom, left, right;
  final double size;
  final Color color;

  const _PositionedCircle({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
