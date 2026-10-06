import 'package:flutter/material.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class AppLogo extends StatelessWidget {
  final double size;
  final bool showBorder;
  final bool showShadow;

  const AppLogo({super.key, this.size = 120, this.showBorder = true, this.showShadow = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
            showBorder
                ? Border.all(color: app_colors.primaryColor.withValues(alpha: 0.4), width: 1.5)
                : null,
        boxShadow:
            showShadow
                ? [
                  BoxShadow(
                    color: app_colors.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ]
                : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.black45 : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const CircleAvatar(
          radius: 42,
          backgroundColor: Colors.transparent,
          backgroundImage: AssetImage('imges/dala_alqaim_logo.png'),
        ),
      ),
    );
  }
}
