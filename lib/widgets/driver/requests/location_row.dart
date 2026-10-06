import 'package:flutter/material.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';

class LocationRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool isDark;

  const LocationRow({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.kFontFamily,
              fontSize: 14,
              color: isDark ? AppTheme.darkText : AppTheme.textColor,
            ),
          ),
        ),
      ],
    );
  }
}
