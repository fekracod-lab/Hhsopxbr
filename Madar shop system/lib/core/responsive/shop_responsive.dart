import 'package:flutter/material.dart';

/// مصفوفة التجاوب والأحجام لشاشات الكاشير وأجهزة سطح المكتب والتابلت (Shop Responsive Matrix)
class ShopBreakpoints {
  static const double mobile = 600;
  static const double tablet = 960;
  static const double desktop = 1280;
  static const double ultraWide = 1600;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= mobile && w < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  static int getProductGridColumns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1600) return 5;
    if (w >= 1280) return 4;
    if (w >= 960) return 3;
    if (w >= 600) return 2;
    return 2;
  }
}

/// ودجت بناء متجاوب حسب حجم شاشة الكاشير
class ShopResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) mobile;
  final Widget Function(BuildContext context)? tablet;
  final Widget Function(BuildContext context) desktop;

  const ShopResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= ShopBreakpoints.desktop) {
      return desktop(context);
    }
    if (width >= ShopBreakpoints.mobile && tablet != null) {
      return tablet!(context);
    }
    return mobile(context);
  }
}
