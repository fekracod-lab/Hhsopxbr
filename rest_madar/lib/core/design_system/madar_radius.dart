import 'package:flutter/material.dart';

/// =====================================================================
///  Madar Design System — أنصاف أقطار الانحناء (Corner Radii)
/// =====================================================================
abstract final class MadarRadius {
  static const double xsVal = 8.0;
  static const double smVal = 12.0;
  static const double mdVal = 16.0;
  static const double lgVal = 20.0;
  static const double roundVal = 999.0;

  static const Radius radiusXs = Radius.circular(xsVal);
  static const Radius radiusSm = Radius.circular(smVal);
  static const Radius radiusMd = Radius.circular(mdVal);
  static const Radius radiusLg = Radius.circular(lgVal);

  static final BorderRadius xs = BorderRadius.circular(xsVal);
  static final BorderRadius sm = BorderRadius.circular(smVal);
  static final BorderRadius md = BorderRadius.circular(mdVal);
  static final BorderRadius lg = BorderRadius.circular(lgVal);
  static final BorderRadius round = BorderRadius.circular(roundVal);
}
