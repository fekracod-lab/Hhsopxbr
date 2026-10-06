import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'madar_colors.dart';

/// =====================================================================
///  Madar Design System — الخطوط وهيكلية النصوص الموحدة (IBM Plex Sans Arabic)
/// =====================================================================
abstract final class MadarTypography {
  static const String fontFamily = 'IBM Plex Sans Arabic';

  /// شاشات العرض الكبرى والعناوين الترحيبية (28 - 32)
  static TextStyle display({Color color = MadarColors.textPrimary}) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.25,
      );

  /// عناوين الصفحات الرئيسية (24 - 28)
  static TextStyle pageTitle({Color color = MadarColors.textPrimary}) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
      );

  /// عناوين الأقسام والبطاقات الكبرى (18 - 22)
  static TextStyle sectionTitle({Color color = MadarColors.textPrimary}) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.35,
      );

  /// العناوين الفرعية وبطاقات القوائم (15 - 17)
  static TextStyle subtitle({Color color = MadarColors.textPrimary}) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.4,
      );

  /// النصوص العامة ومحتوى الجداول (14 - 16)
  static TextStyle body({
    Color color = MadarColors.textPrimary,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 14,
        fontWeight: fontWeight,
        color: color,
        height: 1.45,
      );

  /// النصوص الثانوية والتوضيحية (12 - 13)
  static TextStyle caption({
    Color color = MadarColors.textSecondary,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 12.5,
        fontWeight: fontWeight,
        color: color,
        height: 1.4,
      );

  /// الأرقام والمبالغ المالية في لوحات التحكم (24 - 32)
  static TextStyle metricNumber({
    Color color = MadarColors.textPrimary,
    double fontSize = 26,
  }) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -0.5,
      );

  /// نصوص الأزرار والـ Badges
  static TextStyle button({Color color = Colors.white}) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: color,
      );
}
