import 'package:flutter/material.dart';

/// =====================================================================
///  Madar Design System — نظام المسافات والحشوات الموحد
/// =====================================================================
abstract final class MadarSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // ── الحشوات الجاهزة (Padding Presets) ──
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  static const EdgeInsets pagePaddingCompact = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: xs,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(sm);
  static const EdgeInsets dialogPadding = EdgeInsets.all(xl);

  // ── الفواصل العمودية (Vertical Spacers) ──
  static const Widget gap4 = SizedBox(height: xxs, width: xxs);
  static const Widget gap8 = SizedBox(height: xs, width: xs);
  static const Widget gap12 = SizedBox(height: sm, width: sm);
  static const Widget gap16 = SizedBox(height: md, width: md);
  static const Widget gap20 = SizedBox(height: lg, width: lg);
  static const Widget gap24 = SizedBox(height: xl, width: xl);
  static const Widget gap32 = SizedBox(height: xxl, width: xxl);
}
