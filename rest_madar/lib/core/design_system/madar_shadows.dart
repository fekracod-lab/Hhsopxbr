import 'package:flutter/material.dart';

/// =====================================================================
///  Madar Design System — ظلال البطاقات والعمق البصري (Shadow Tokens)
/// =====================================================================
abstract final class MadarShadows {
  /// ظل خافت جداً للبطاقات القياسية
  static final List<BoxShadow> subtle = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// ظل ناعم لعناصر التفاعل والقوائم المنسدلة
  static final List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  /// ظل بارز للنوافذ الحوارية والألواح الجانبية
  static final List<BoxShadow> modal = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.16),
      blurRadius: 28,
      offset: const Offset(0, 8),
    ),
  ];

  /// توهج برتقالي ناعم للعناصر النشطة وزر الـ CTA الأساسي
  static final List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: const Color(0xFFFF6B1A).withValues(alpha: 0.28),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
