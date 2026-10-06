import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class AppTheme {
  // ─── Core Brand Colors (ألوان مدار الأساسية) ───
  static const Color primaryColor = app_colors.primaryColor; // 0xFF00BFA5
  static const Color accentColor = app_colors.accentColor; // 0xFF00796B
  static const Color primaryDark = app_colors.primaryDark; // 0xFF00897B
  static const Color goldAccent = app_colors.goldAccent; // 0xFFFFB830
  static const Color goldDark = app_colors.goldDark;

  // ─── Light Mode Colors ───
  static const Color backgroundColor = app_colors.backgroundColor; // 0xFFF8FAFC
  static const Color cardColor = app_colors.cardColor; // 0xFFFFFFFF
  static const Color surfaceColor = app_colors.surfaceColor; // 0xFFFFFFFF
  static const Color textColor = app_colors.textColor; // 0xFF1E293B
  static const Color hintColor = app_colors.hintColor; // 0xFF94A3B8
  static const Color subTextColor = app_colors.subTextColor; // 0xFF64748B
  static const Color borderColor = app_colors.borderColor; // 0xFFE2E8F0

  // ─── Status Colors ───
  static const Color successColor = app_colors.successColor;
  static const Color warningColor = app_colors.warningColor;
  static const Color errorColor = app_colors.errorColor;
  static const Color infoColor = app_colors.infoColor;

  // ─── Dark Mode Colors (هوية الوضع الليلي الفخم) ───
  static const Color darkBackground = app_colors.darkBackground; // 0xFF081C1E
  static const Color darkSurface = app_colors.darkSurface; // 0xFF0E282B
  static const Color darkCard = app_colors.darkCard; // 0xFF13363A
  static const Color darkCardElevated = app_colors.darkCardElevated; // 0xFF1A464B
  static const Color darkText = app_colors.darkText; // 0xFFF8FAFC
  static const Color darkSubText = app_colors.darkSubText; // 0xFF80CBC4
  static const Color darkHint = app_colors.darkHint; // 0xFF5A7B7E
  static const Color darkBorder = app_colors.darkBorder; // 0xFF1F555A
  static const Color darkBorderSubtle = app_colors.darkBorderSubtle;
  static const Color darkDivider = app_colors.darkDivider;

  // ─── Design Tokens ───
  static const double kBorderRadius = 18.0;
  static const double kPadding = 16.0;
  static const double kSpacing = 16.0;
  static const double kElevation = 3.0;

  // ─── Animation Durations ───
  static const Duration kAnimationDuration = Duration(milliseconds: 300);
  static const Duration kLongAnimationDuration = Duration(milliseconds: 500);

  // ─── Typography Constant ───
  static const String kFontFamily = 'IBMPlexSansArabic';

  // ─────────────────────────────────────────────────────────────────────────────
  // Light Theme (الوضع النهاري المتناسق والراقي)
  // ─────────────────────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme).apply(
      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
      bodyColor: textColor,
      displayColor: textColor,
    );

    return base.copyWith(
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      cardColor: cardColor,
      canvasColor: backgroundColor,
      splashColor: primaryColor.withValues(alpha: 0.1),
      highlightColor: primaryColor.withValues(alpha: 0.05),
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: accentColor,
        onSecondary: Colors.white,
        tertiary: goldAccent,
        surface: surfaceColor,
        onSurface: textColor,
        error: errorColor,
        onError: Colors.white,
        outline: borderColor,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: textColor),
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          side: const BorderSide(color: borderColor, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryColor.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        hintStyle: GoogleFonts.ibmPlexSansArabic(color: hintColor, fontSize: 13),
        labelStyle: GoogleFonts.ibmPlexSansArabic(color: subTextColor, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.35);
          }
          return Colors.grey.shade200;
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: app_colors.dividerColor,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textColor,
        contentTextStyle: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dark Theme (الوضع الليلي الفخم - Deep Oceanic Obsidian Madar)
  // ─────────────────────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme).apply(
      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
      bodyColor: darkText,
      displayColor: darkText,
    );

    return base.copyWith(
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryColor,
      cardColor: darkCard,
      canvasColor: darkBackground,
      splashColor: primaryColor.withValues(alpha: 0.15),
      highlightColor: primaryColor.withValues(alpha: 0.08),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: accentColor,
        onSecondary: Colors.white,
        tertiary: goldAccent,
        surface: darkSurface,
        onSurface: darkText,
        error: errorColor,
        onError: Colors.white,
        outline: darkBorder,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: darkText),
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(
          color: darkText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          side: const BorderSide(color: darkBorder, width: 0.9),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCardElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(
          color: darkText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCardElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: darkBorder, width: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: primaryColor.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        hintStyle: GoogleFonts.ibmPlexSansArabic(color: darkHint, fontSize: 13),
        labelStyle: GoogleFonts.ibmPlexSansArabic(color: darkSubText, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.white54;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.4);
          }
          return Colors.white.withValues(alpha: 0.1);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCardElevated,
        contentTextStyle: GoogleFonts.ibmPlexSansArabic(color: darkText, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder, width: 0.8),
        ),
      ),
    );
  }
}
