import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  static const Color primary = app_colors.primaryColor;
  static const Color primaryDark = app_colors.accentColor;
  static const Color accent = app_colors.accentColor;
  static const Color gold = Color(0xFFFFB830);
  static const Color success = app_colors.successColor;
  static const Color surface = app_colors.darkBackground;
  static const Color surfaceCard = app_colors.darkCard;
  static const Color surfaceElevated = app_colors.darkSurface;
  static const Color textPrimary = app_colors.darkText;
  static const Color textSecondary = app_colors.darkSubText;
  static const Color textMuted = app_colors.darkHint;
  static const Color border = app_colors.darkBorder;
  static const Color borderLight = app_colors.borderColor;

  static ThemeData darkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme).apply(
      bodyColor: app_colors.darkText,
      displayColor: app_colors.darkText,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: app_colors.primaryColor,
        secondary: app_colors.accentColor,
        surface: app_colors.darkSurface,
        onPrimary: Colors.white,
        onSurface: app_colors.darkText,
      ),
      primaryColor: app_colors.primaryColor,
      cardColor: app_colors.darkCard,
      scaffoldBackgroundColor: app_colors.darkBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: app_colors.primaryColor),
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(
          fontWeight: FontWeight.bold,
          fontSize: 20.sp,
          color: app_colors.primaryColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: app_colors.primaryColor,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 14.sp),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 24.w),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: app_colors.primaryColor.withValues(alpha: 0.6)),
          foregroundColor: app_colors.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          textStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 14.sp),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: app_colors.darkSurface,
        selectedItemColor: app_colors.primaryColor,
        unselectedItemColor: Colors.white70,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => app_colors.primaryColor),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => app_colors.primaryColor.withValues(alpha: 0.4),
        ),
      ),
      iconTheme: IconThemeData(color: app_colors.darkSubText, size: 24.r),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: app_colors.darkSurface,
        hintStyle: GoogleFonts.ibmPlexSansArabic(color: app_colors.darkHint, fontSize: 12.sp),
        labelStyle: GoogleFonts.ibmPlexSansArabic(color: app_colors.darkSubText, fontSize: 12.sp),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData lightTheme() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme).apply(
      bodyColor: app_colors.textColor,
      displayColor: app_colors.textColor,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: app_colors.primaryColor,
        secondary: app_colors.accentColor,
        surface: Color(0xFFF8F9FD),
      ),
      primaryColor: app_colors.primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF8F9FD),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: app_colors.textColor),
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(
          fontWeight: FontWeight.bold,
          fontSize: 20.sp,
          color: app_colors.textColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: app_colors.primaryColor,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 14.sp),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 24.w),
        ),
      ),
      cardColor: app_colors.backgroundColor,
      iconTheme: IconThemeData(color: app_colors.subTextColor, size: 24.r),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: app_colors.backgroundColor,
        hintStyle: GoogleFonts.ibmPlexSansArabic(color: app_colors.hintColor, fontSize: 12.sp),
        labelStyle: GoogleFonts.ibmPlexSansArabic(color: app_colors.subTextColor, fontSize: 12.sp),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: app_colors.primaryColor),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: app_colors.primaryColor,
        unselectedItemColor: app_colors.hintColor,
        selectedLabelStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 10.sp),
        unselectedLabelStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 10.sp),
      ),
    );
  }
}
