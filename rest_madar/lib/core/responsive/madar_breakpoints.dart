/// =====================================================================
///  Madar Design System — نقاط التوقف المركزية (Central Breakpoints)
/// =====================================================================
abstract final class MadarBreakpoints {
  /// الهواتف الذكية والشاشات الصغيرة جداً (< 600)
  static const double phone = 600.0;

  /// الأجهزة اللوحية بالوضع الرأسي (iPad Portrait / 8-11" Tablets: 600 - 899)
  static const double tabletPortraitMax = 899.0;

  /// الأجهزة اللوحية بالوضع الأفقي والحواسيب المحمولة الصغيرة (iPad Landscape: 900 - 1199)
  static const double tabletLandscapeMax = 1199.0;

  /// أجهزة سطح المكتب واللابتوب القياسية (Desktop 1200+)
  static const double desktop = 1200.0;

  /// شاشات سطح المكتب فائقة الاتساع (Ultra-Wide / 1600+)
  static const double desktopLarge = 1600.0;

  /// الحد الأقصى المريح لعرض المحتوى لمنع التشتت البصري على الشاشات الكبيرة
  static const double maxContentWidth = 1440.0;

  /// العرض القياسي للشريط الجانبي المكتبي
  static const double desktopSidebarWidth = 252.0;

  /// العرض القياسي للشريط الجانبي المصغر (NavigationRail للتابلت)
  static const double compactSidebarWidth = 76.0;

  /// العرض الأقصى للوحة الفحص والتفاصيل الجانبية (Side Sheet)
  static const double sideSheetWidth = 420.0;
}
