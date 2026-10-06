import 'package:flutter/material.dart';
import 'madar_breakpoints.dart';

/// =====================================================================
///  Madar Design System — أداة التجاوب الذكية المركزية (Responsive Utility)
/// =====================================================================
abstract final class MadarResponsive {
  /// عرض الشاشة الكلي المتاح
  static double widthOf(BuildContext context) => MediaQuery.sizeOf(context).width;

  /// ارتفاع الشاشة الكلي المتاح
  static double heightOf(BuildContext context) => MediaQuery.sizeOf(context).height;

  /// هل الشاشة تمثل سطح مكتب عريض (>= 1200)
  static bool isDesktop(BuildContext context) =>
      widthOf(context) >= MadarBreakpoints.desktop;

  /// هل الشاشة تمثل جهازاً لوحياً (600 - 1199)
  static bool isTablet(BuildContext context) {
    final w = widthOf(context);
    return w >= MadarBreakpoints.phone && w < MadarBreakpoints.desktop;
  }

  /// هل الشاشة تمثل جهازاً لوحياً بالوضع الأفقي (900 - 1199)
  static bool isTabletLandscape(BuildContext context) {
    final w = widthOf(context);
    return w >= 900 && w < MadarBreakpoints.desktop;
  }

  /// هل الشاشة تمثل جهازاً لوحياً بالوضع الرأسي (< 900)
  static bool isTabletPortrait(BuildContext context) {
    final w = widthOf(context);
    return w >= MadarBreakpoints.phone && w < 900;
  }

  /// هل الشاشة تمثل شاشة هاتف محمول أو مساحة ضيقة جداً (< 600)
  static bool isMobile(BuildContext context) =>
      widthOf(context) < MadarBreakpoints.phone;

  /// هل الاتجاه أفقي (Landscape)
  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// هل الاتجاه رأسي (Portrait)
  static bool isPortrait(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.portrait;

  /// العرض التكيفي للشريط الجانبي وفق حجم الشاشة الحالي
  static double sidebarWidth(BuildContext context, {bool isManuallyCollapsed = false}) {
    if (isDesktop(context)) {
      return isManuallyCollapsed
          ? MadarBreakpoints.compactSidebarWidth
          : MadarBreakpoints.desktopSidebarWidth;
    } else if (isTabletLandscape(context)) {
      return MadarBreakpoints.compactSidebarWidth;
    } else {
      // في وضع التابلت الرأسي يتم إخفاء الشريط واستبداله بـ Drawer
      return 0.0;
    }
  }

  /// حساب العرض المناسب للنافذة الحوارية (Adaptive Dialog Width)
  static double dialogWidth(BuildContext context, {double targetWidth = 500, double? maxWidth}) {
    final effectiveTarget = maxWidth ?? targetWidth;
    final screenW = widthOf(context);
    final maxAllowed = screenW - 32;
    return effectiveTarget > maxAllowed ? maxAllowed : effectiveTarget;
  }

  /// حساب العرض المناسب للوح الجانبي (Side Sheet Width)
  static double sideSheetWidth(BuildContext context) {
    final screenW = widthOf(context);
    if (screenW >= 1200) {
      return MadarBreakpoints.sideSheetWidth;
    } else if (screenW >= 800) {
      return 380.0;
    } else {
      return screenW - 24;
    }
  }

  /// الهامش المناسب لمحتوى الصفحة وفق حجم الشاشة
  static double contentPadding(BuildContext context) {
    if (isDesktop(context)) return 24.0;
    if (isTabletLandscape(context)) return 20.0;
    return 16.0;
  }
}
