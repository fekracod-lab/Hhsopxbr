import 'package:flutter/material.dart';

/// =====================================================================
///  Madar Design System — الألوان المركزية الموحدة لنظام مطاعم مدار
/// =====================================================================
abstract final class MadarColors {
  // ── الألوان الرئيسية للماركة ──
  static const Color primary = Color(0xFFFF6B1A); // برتقالي مدار المؤسسي الحديث
  static const Color primaryHover = Color(0xFFE55A0F);
  static const Color primaryLight = Color(0xFFFF853E);
  static const Color primarySoft = Color(0xFFFFF2EB); // خلفيات خافتة للأزرار والأيقونات

  // ── درجات الأسود والرمادي الداكن ──
  static const Color dark = Color(0xFF111827); // Dark Charcoal Near-Black
  static const Color darkSurface = Color(0xFF1F2937);
  static const Color darkCard = Color(0xFF161F2E);
  static const Color darkBorder = Color(0xFF374151);

  // ── ألوان النصوص ──
  static const Color textPrimary = Color(0xFF111827); // نص رئيسي عالي التباين
  static const Color textSecondary = Color(0xFF64748B); // نص ثانوي وتوضيحي
  static const Color textDisabled = Color(0xFF94A3B8);
  static const Color textLight = Color(0xFFF9FAFB); // نصوص على الخلفيات الداكنة
  static const Color textLightMuted = Color(0xFF9CA3AF);

  // ── الخلفيات والأسطح (Light Theme) ──
  static const Color background = Color(0xFFF6F7F9); // خلفية التطبيق العامة المريحة
  static const Color card = Color(0xFFFFFFFF); // البطاقات والحاويات البيضاء
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0); // حدود ناعمة وأنيقة
  static const Color borderLight = Color(0xFFF1F5F9);

  // ── ألوان الحالات والوظائف الدلالية (Semantic Colors) ──
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFDCFCE7);
  
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF3C7);
  
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  
  static const Color info = Color(0xFF2563EB);
  static const Color infoSoft = Color(0xFFDBEAFE);

  // ── ألوان القائمة الجانبية (Sidebar Dark Theme الثابت) ──
  static const Color sidebarBg = Color(0xFF111827);
  static const Color sidebarSurface = Color(0xFF1F2937);
  static const Color sidebarBorder = Color(0xFF1E293B);
  static const Color sidebarActive = Color(0xFFFF6B1A);
  static const Color sidebarActiveBg = Color(0xFF1E2433);
  static const Color sidebarInactiveText = Color(0xFF94A3B8);
  static const Color sidebarActiveText = Color(0xFFFFFFFF);
}
