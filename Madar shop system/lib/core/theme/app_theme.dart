import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نظام الألوان والهوية البصرية لمنظومة كاشير ومتاجر مدار (Madar Shop POS)
class ShopColors {
  // ── الألوان الرئيسية والعلامة التجارية (Madar Brand Identity) ──
  static const Color primary = Color(0xFF00BFA5); // لون مدار الأساسي (Teal)
  static const Color primaryDark = Color(0xFF00897B);
  static const Color primaryLight = Color(0xFF64D8CB);

  // ── ألوان الذهب والتمييز (Featured / "مميز") ──
  static const Color gold = Color(0xFFFFB830); // ذهبي مدار الفاخر
  static const Color goldLight = Color(0xFFFFD56B);
  static const Color goldDark = Color(0xFFC78A17);

  // ── ألوان الحالات (Status Colors) ──
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── الوضع الداكن (Dark Mode Glassmorphic) ──
  static const Color darkBg = Color(0xFF0A1417);
  static const Color darkSurface = Color(0xFF0F1E22);
  static const Color darkCard = Color(0xFF14272C);
  static const Color darkBorder = Color(0xFF1F383E);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkSubText = Color(0xFF94A3B8);

  // ── الوضع الفاتح (Light Mode Crisp) ──
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightSubText = Color(0xFF64748B);
}

/// متحكم المظهر الفاتح / الداكن مع الحفظ الدائم
class ShopThemeController extends ChangeNotifier {
  static final ShopThemeController instance = ShopThemeController._();
  ShopThemeController._();

  bool _isDark = true;
  bool get isDark => _isDark;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool('shop_is_dark') ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('shop_is_dark', _isDark);
    } catch (_) {}
  }
}

/// موفر الثيم الخاص بكاشير مدار
class ShopTheme {
  static ThemeData buildTheme({required bool isDark}) {
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.cairoTextTheme(base.textTheme).apply(
      fontFamily: GoogleFonts.cairo().fontFamily,
      bodyColor: isDark ? ShopColors.darkText : ShopColors.lightText,
      displayColor: isDark ? ShopColors.darkText : ShopColors.lightText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: ShopColors.primary,
      scaffoldBackgroundColor: isDark ? ShopColors.darkBg : ShopColors.lightBg,
      cardColor: isDark ? ShopColors.darkCard : ShopColors.lightCard,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: ShopColors.primary,
        onPrimary: Colors.white,
        secondary: ShopColors.gold,
        onSecondary: Colors.black,
        error: ShopColors.danger,
        onError: Colors.white,
        surface: isDark ? ShopColors.darkSurface : ShopColors.lightSurface,
        onSurface: isDark ? ShopColors.darkText : ShopColors.lightText,
      ),
      textTheme: textTheme,
      dividerColor: isDark ? ShopColors.darkBorder : ShopColors.lightBorder,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: isDark ? ShopColors.darkSurface : ShopColors.lightSurface,
        foregroundColor: isDark ? ShopColors.darkText : ShopColors.lightText,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? ShopColors.darkText : ShopColors.lightText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ShopColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}
