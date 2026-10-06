import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// =====================================================================
///  نظام الهوية المزدوجة لنظام مدار كاشير (Dark / Light)
///  ── تُحفظ الشاشات القديمة على PosTheme (ثيم داكن مرجعي) للتوافق،
///  ── بينما تعتمد الشاشات المعاد تصميمها على context.posColors.
/// =====================================================================

/// ألوان المرجعية الداكنة (تُحفظ للتوافق مع الكود القديم)
class PosTheme {
  // الألوان الأساسية
  static const Color primary = Color(0xFFFF5B22); // برتقالي مدار الدافئ المؤسسي
  static const Color primaryDark = Color(0xFFE04812);
  static const Color primaryLight = Color(0xFFFF7A45);
  static const Color accent = Color(0xFFFF5722);

  // ألوان الحالات والذهب
  static const Color gold = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // الخلفيات المريحة للعين (Modern SaaS Glassmorphism)
  static const Color bgDark = Color(0xFF0F1218); // خلفية سطح المكتب الداكنة
  static const Color surfaceDark = Color(0xFF15181F); // البطاقات والحاويات
  static const Color cardDark = Color(0xFF1A1E26); // بطاقات الوجبات والعناصر
  static const Color sidebarDark = Color(0xFF15181F); // القائمة الجانبية
  static const Color borderDark = Color(0xFF262B36); // حدود خفيفة وأنيقة

  // النصوص
  static const Color textLight = Color(0xFFF8FAFC); // نص أساسي عالي التباين
  static const Color textMuted = Color(0xFF8B95A5); // نص ثانوي وتوضيحي
  static const Color textDisabled = Color(0xFF64748B);

  /// إعادة التصدير للتوافق: الثيم الداكن (تُبنى الآن ديناميكياً)
  static ThemeData get darkTheme => buildPosTheme(isDark: true);
}

/// ∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
///  اللوحات الدلالية (Semantic Palettes)
/// ∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎

/// ألوان دلالية مرتبطة بالسياق — تعتمد على الوضع الحالي (فاتح/داكن)
class PosColors {
  // الخلفيات
  final Color background; // خلفية الشاشة
  final Color surface; // الحاويات الرئيسية وأشرطة
  final Color card; // البطاقات
  final Color sidebar; // القائمة الجانبية (تُبقى داكنة في الوضعين لهوية موحّدة)
  final Color border; // الحدود

  // العلامة التجارية والحالات
  final Color primary;
  final Color primaryLight;
  final Color accent;
  final Color gold;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  // ألوان الباستيل للبطاقات والمؤشرات
  final Color orangeSoft;
  final Color blueSoft;
  final Color greenSoft;
  final Color purpleSoft;
  final Color amberSoft;
  final Color redSoft;

  // النصوص
  final Color textPrimary;
  final Color textMuted;
  final Color textDisabled;

  // ألوان نص/أيقونات الجانب (على الخلفية الداكنة الثابتة)
  final Color sidebarText;
  final Color sidebarMuted;
  final Color sidebarSelected; // خلفية العنصر المحدد في الجانب

  const PosColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.sidebar,
    required this.border,
    required this.primary,
    required this.primaryLight,
    required this.accent,
    required this.gold,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.orangeSoft,
    required this.blueSoft,
    required this.greenSoft,
    required this.purpleSoft,
    required this.amberSoft,
    required this.redSoft,
    required this.textPrimary,
    required this.textMuted,
    required this.textDisabled,
    required this.sidebarText,
    required this.sidebarMuted,
    required this.sidebarSelected,
  });

  /// اسم مستعار للنص الثانوي (للتوافق مع معايير Material)
  Color get textSecondary => textMuted;

  PosColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? sidebar,
    Color? border,
    Color? primary,
    Color? primaryLight,
    Color? accent,
    Color? gold,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? orangeSoft,
    Color? blueSoft,
    Color? greenSoft,
    Color? purpleSoft,
    Color? amberSoft,
    Color? redSoft,
    Color? textPrimary,
    Color? textMuted,
    Color? textDisabled,
    Color? sidebarText,
    Color? sidebarMuted,
    Color? sidebarSelected,
  }) {
    return PosColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      sidebar: sidebar ?? this.sidebar,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      accent: accent ?? this.accent,
      gold: gold ?? this.gold,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      orangeSoft: orangeSoft ?? this.orangeSoft,
      blueSoft: blueSoft ?? this.blueSoft,
      greenSoft: greenSoft ?? this.greenSoft,
      purpleSoft: purpleSoft ?? this.purpleSoft,
      amberSoft: amberSoft ?? this.amberSoft,
      redSoft: redSoft ?? this.redSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      sidebarText: sidebarText ?? this.sidebarText,
      sidebarMuted: sidebarMuted ?? this.sidebarMuted,
      sidebarSelected: sidebarSelected ?? this.sidebarSelected,
    );
  }
}

/// لوحات الألوان المعتمدة
class PosPalette {
  PosPalette._();

  static const PosColors dark = PosColors(
    background: Color(0xFF0F1218),
    surface: Color(0xFF15181F),
    card: Color(0xFF1A1E26),
    sidebar: Color(0xFF15181F),
    border: Color(0xFF262B36),
    primary: Color(0xFFFF5B22),
    primaryLight: Color(0xFFFF7A45),
    accent: Color(0xFFFF5722),
    gold: Color(0xFFF59E0B),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
    orangeSoft: Color(0xFF2A1B12),
    blueSoft: Color(0xFF142238),
    greenSoft: Color(0xFF122C1D),
    purpleSoft: Color(0xFF251638),
    amberSoft: Color(0xFF2B2010),
    redSoft: Color(0xFF301315),
    textPrimary: Color(0xFFF8FAFC),
    textMuted: Color(0xFF94A3B8),
    textDisabled: Color(0xFF64748B),
    sidebarText: Color(0xFFF8FAFC),
    sidebarMuted: Color(0xFF8B95A5),
    sidebarSelected: Color(0xFFFF5722),
  );

  static const PosColors light = PosColors(
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    sidebar: Color(0xFF15181F),
    border: Color(0xFFE2E8F0),
    primary: Color(0xFFFF5B22),
    primaryLight: Color(0xFFFF7A45),
    accent: Color(0xFFFF5722),
    gold: Color(0xFFF59E0B),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
    orangeSoft: Color(0xFFFFF7ED),
    blueSoft: Color(0xFFEFF6FF),
    greenSoft: Color(0xFFF0FDF4),
    purpleSoft: Color(0xFFFAF5FF),
    amberSoft: Color(0xFFFFFBEB),
    redSoft: Color(0xFFFEF2F2),
    textPrimary: Color(0xFF1E293B),
    textMuted: Color(0xFF64748B),
    textDisabled: Color(0xFF94A3B8),
    sidebarText: Color(0xFFF8FAFC),
    sidebarMuted: Color(0xFF8B95A5),
    sidebarSelected: Color(0xFFFF5722),
  );
}

/// ∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
///  باقة ألوان الهوية والعلامة التجارية (Brand Accent Colors)
/// ∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎

class MadarBrandColor {
  final String id;
  final String name;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accent;
  final Color softBgLight;
  final Color softBgDark;

  const MadarBrandColor({
    required this.id,
    required this.name,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.softBgLight,
    required this.softBgDark,
  });
}

class MadarBrandColors {
  static const orange = MadarBrandColor(
    id: 'orange',
    name: 'برتقالي مدار (الافتراضي)',
    primary: Color(0xFFFF5B22),
    primaryDark: Color(0xFFE04812),
    primaryLight: Color(0xFFFF7A45),
    accent: Color(0xFFFF5722),
    softBgLight: Color(0xFFFFF7ED),
    softBgDark: Color(0xFF2A1B12),
  );

  static const blue = MadarBrandColor(
    id: 'blue',
    name: 'الأزرق الملكي',
    primary: Color(0xFF2563EB),
    primaryDark: Color(0xFF1D4ED8),
    primaryLight: Color(0xFF3B82F6),
    accent: Color(0xFF1E40AF),
    softBgLight: Color(0xFFEFF6FF),
    softBgDark: Color(0xFF142238),
  );

  static const green = MadarBrandColor(
    id: 'green',
    name: 'الأخضر الزمردي',
    primary: Color(0xFF059669),
    primaryDark: Color(0xFF047857),
    primaryLight: Color(0xFF10B981),
    accent: Color(0xFF065F46),
    softBgLight: Color(0xFFF0FDF4),
    softBgDark: Color(0xFF122C1D),
  );

  static const purple = MadarBrandColor(
    id: 'purple',
    name: 'البنفسجي العصري',
    primary: Color(0xFF7C3AED),
    primaryDark: Color(0xFF6D28D9),
    primaryLight: Color(0xFF8B5CF6),
    accent: Color(0xFF5B21B6),
    softBgLight: Color(0xFFFAF5FF),
    softBgDark: Color(0xFF251638),
  );

  static const red = MadarBrandColor(
    id: 'red',
    name: 'الأحمر الياقوتي',
    primary: Color(0xFFDC2626),
    primaryDark: Color(0xFFB91C1C),
    primaryLight: Color(0xFFEF4444),
    accent: Color(0xFF991B1B),
    softBgLight: Color(0xFFFEF2F2),
    softBgDark: Color(0xFF301315),
  );

  static const amber = MadarBrandColor(
    id: 'amber',
    name: 'الذهبي الفاخر',
    primary: Color(0xFFD97706),
    primaryDark: Color(0xFFB45309),
    primaryLight: Color(0xFFF59E0B),
    accent: Color(0xFF92400E),
    softBgLight: Color(0xFFFFFBEB),
    softBgDark: Color(0xFF2B2010),
  );

  static const teal = MadarBrandColor(
    id: 'teal',
    name: 'التركوازي المائي',
    primary: Color(0xFF0D9488),
    primaryDark: Color(0xFF0F766E),
    primaryLight: Color(0xFF14B8A6),
    accent: Color(0xFF115E59),
    softBgLight: Color(0xFFF0FDFA),
    softBgDark: Color(0xFF112926),
  );

  static const rose = MadarBrandColor(
    id: 'rose',
    name: 'الوردي الأنيق',
    primary: Color(0xFFE11D48),
    primaryDark: Color(0xFFBE123C),
    primaryLight: Color(0xFFF43F5E),
    accent: Color(0xFF9F1239),
    softBgLight: Color(0xFFFFF1F2),
    softBgDark: Color(0xFF2C1318),
  );

  static const List<MadarBrandColor> all = [
    orange,
    blue,
    green,
    purple,
    red,
    amber,
    teal,
    rose,
  ];

  static MadarBrandColor findById(String id) {
    return all.firstWhere((c) => c.id == id, orElse: () => orange);
  }
}

/// ∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
///  متحكم الوضع والسمة (فاتح/داكن + ألوان البراند) مع الحفظ التلقائي
/// ∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎

class PosThemeController extends ChangeNotifier {
  PosThemeController._();
  static final PosThemeController instance = PosThemeController._();

  static const String _prefsKey = 'madar_pos_theme_mode';
  static const String _brandKey = 'madar_pos_brand_color';
  static const String _darkValue = 'dark';
  static const String _lightValue = 'light';

  bool _isDark = false;
  bool _loaded = false;
  MadarBrandColor _brandColor = MadarBrandColors.orange;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;
  bool get isLoaded => _loaded;
  MadarBrandColor get brandColor => _brandColor;

  /// الحصول على الألوان الحالية مدمجة مع لون البراند المختار
  PosColors get currentColors {
    final base = _isDark ? PosPalette.dark : PosPalette.light;
    return base.copyWith(
      primary: _brandColor.primary,
      primaryLight: _brandColor.primaryLight,
      accent: _brandColor.accent,
      sidebarSelected: _brandColor.primary,
      orangeSoft: _isDark ? _brandColor.softBgDark : _brandColor.softBgLight,
    );
  }

  /// تحميل الوضع ولون السمة المحفوظ من التخزين المحلي
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_prefsKey);
      _isDark = savedTheme == _darkValue;

      final savedBrand = prefs.getString(_brandKey);
      if (savedBrand != null) {
        _brandColor = MadarBrandColors.findById(savedBrand);
      }
    } catch (_) {
      // الوضع الافتراضي
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value && _loaded) return;
    _isDark = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, value ? _darkValue : _lightValue);
    } catch (_) {}
  }

  Future<void> setBrandColor(MadarBrandColor color) async {
    if (_brandColor.id == color.id) return;
    _brandColor = color;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_brandKey, color.id);
    } catch (_) {}
  }

  Future<void> toggle() => setDark(!_isDark);
}

/// امتداد للحصول على الألوان الدلالية حسب الوضع الحالي ولون البراند
extension PosThemeContext on BuildContext {
  PosColors get posColors => PosThemeController.instance.currentColors;

  bool get isDarkMode => PosThemeController.instance.isDark;

  MadarBrandColor get brandColor => PosThemeController.instance.brandColor;
}

/// ∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
///  بناء ThemeData موحّد للوضعين مدمج مع لون البراند المختار
/// ∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎

ThemeData buildPosTheme({required bool isDark}) {
  final brand = PosThemeController.instance.brandColor;
  final baseColors = isDark ? PosPalette.dark : PosPalette.light;
  final c = baseColors.copyWith(
    primary: brand.primary,
    primaryLight: brand.primaryLight,
    accent: brand.accent,
    sidebarSelected: brand.primary,
    orangeSoft: isDark ? brand.softBgDark : brand.softBgLight,
  );
  final base = isDark ? ThemeData.dark() : ThemeData.light();

  final colorScheme = isDark
      ? ColorScheme.dark(
          primary: c.primary,
          secondary: c.accent,
          surface: c.surface,
          error: c.danger,
        )
      : ColorScheme.light(
          primary: c.primary,
          secondary: c.accent,
          surface: c.background,
          error: c.danger,
        );

  final inputFillDark = PosPalette.dark.card;
  const inputFillLight = Color(0xFFF1F5F4);

  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    primaryColor: c.primary,
    colorScheme: colorScheme.copyWith(
      surface: c.card,
    ),
    brightness: isDark ? Brightness.dark : Brightness.light,

    // بطاقات
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border, width: 1),
      ),
    ),

    // تطبيقات وأدوات
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      elevation: 0,
      centerTitle: false,
      foregroundColor: c.textPrimary,
      surfaceTintColor: Colors.transparent,
    ),

    // أزرار
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: isDark ? Colors.white : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.ibmPlexSansArabic(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        side: BorderSide(color: c.primary.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.ibmPlexSansArabic(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.ibmPlexSansArabic(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
    ),

    // حقول الإدخال
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: isDark ? inputFillDark : inputFillLight,
      hintStyle: GoogleFonts.ibmPlexSansArabic(
        color: c.textDisabled,
        fontSize: 13,
      ),
      labelStyle: GoogleFonts.ibmPlexSansArabic(
        color: c.textMuted,
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.danger),
      ),
    ),

    // الشرائح (Chips)
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.card,
      selectedColor: c.primary.withValues(alpha: 0.22),
      side: BorderSide(color: c.border),
      labelStyle: GoogleFonts.ibmPlexSansArabic(
        color: c.textPrimary,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),

    // الحوارات
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titleTextStyle: GoogleFonts.ibmPlexSansArabic(
        color: c.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),

    // سنك بار
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF20373A) : const Color(0xFF1F3A3D),
      contentTextStyle: GoogleFonts.ibmPlexSansArabic(
        color: Colors.white,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    ),

    // تقسيم وعناصر
    dividerColor: c.border,
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),

    // تبويبات
    tabBarTheme: TabBarThemeData(
      labelColor: c.primary,
      unselectedLabelColor: c.textMuted,
      indicatorColor: c.primary,
      dividerColor: Colors.transparent,
      labelStyle: GoogleFonts.ibmPlexSansArabic(
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      unselectedLabelStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5),
    ),

    // تمرير
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.primary.withValues(alpha: 0.5)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
    ),

    // تلميحات
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF243E41) : const Color(0xFF1F3A3D),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 11.5),
    ),

    // اختيارات القوائم المنسدلة
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: isDark ? inputFillDark : inputFillLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textStyle: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontSize: 13),
    ),

    textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme).copyWith(
      titleLarge: GoogleFonts.ibmPlexSansArabic(
        color: c.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: GoogleFonts.ibmPlexSansArabic(
        color: c.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: GoogleFonts.ibmPlexSansArabic(
        color: c.textPrimary,
        fontSize: 13,
      ),
      bodySmall: GoogleFonts.ibmPlexSansArabic(
        color: c.textMuted,
        fontSize: 12,
      ),
      labelLarge: GoogleFonts.ibmPlexSansArabic(
        color: c.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
