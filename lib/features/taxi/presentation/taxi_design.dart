import 'package:flutter/material.dart';

class TaxiDesign {
  // Global Standard Palette (Uber/Careem inspired)
  static const Color primary = Color(0xFF000000); // Sleek Black
  static const Color accent = Color(0xFF276EF1); // Global Blue
  static const Color pickup = Color(0xFF00C896); // Vibrant Green
  static const Color dropoff = Color(0xFFFF5252); // Vibrant Red
  static const Color background = Color(0xFFF6F6F6);
  static const Color surface = Colors.white;
  static const Color greyText = Color(0xFF5E5E5E);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2D3436), Color(0xFF000000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF276EF1), Color(0xFF0645AD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Map Filter (Premium Quiet Mode)
  static const List<double> quietMapFilter = <double>[
    0.85,
    0,
    0,
    0,
    0,
    0,
    0.85,
    0,
    0,
    0,
    0,
    0,
    0.85,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  // Shadows
  static List<BoxShadow> premiumShadow = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 12)),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
  ];

  static const String kFontFamily = 'IBMPlexSansArabic';
  static const double kBorderRadius = 24.0;
}
