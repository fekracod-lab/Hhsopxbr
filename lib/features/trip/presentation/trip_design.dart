import 'package:flutter/material.dart';

class TripDesign {
  // Light Palette
  static const Color primary = Color(0xFF26A69A);
  static const Color accent = Color(0xFF00796B);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF333333);
  static const Color subTextColor = Color(0xFF757575);
  static const Color hintColor = Color(0xFF9E9E9E);
  static const Color error = Color(0xFFFF6B6B);

  // Dark Palette
  static const Color darkBackground = Color(0xFF07191A);
  static const Color darkSurface = Color(0xFF0F2323);
  static const Color darkCard = Color(0xFF113033);
  static const Color darkText = Color(0xFFE0F2F1);
  static const Color darkSubText = Color(0xFF80CBC4);
  static const Color darkHint = Color(0xFF4DB6AC);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF26A69A), Color(0xFF00796B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0F2323), Color(0xFF07191A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Shadows
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static const String kFontFamily = 'IBMPlexSansArabic';
}
