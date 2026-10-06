import 'package:flutter/material.dart';

// ─── Primary Brand Palette (هوية مدار البصرية الأساسية) ───
const Color primaryColor = Color(0xFF00BFA5); // Modern Teal Vibrant
const Color primaryDark = Color(0xFF00897B); // Deep Teal
const Color accentColor = Color(0xFF00796B); // Deep Emerald
const Color goldAccent = Color(0xFFFFB830); // Premium Gold for badges & VIP ratings
const Color goldDark = Color(0xFFFFA000);
const Color errorColor = Color(0xFFFF5252);
const Color successColor = Color(0xFF00E676);
const Color warningColor = Color(0xFFFFAB00);
const Color infoColor = Color(0xFF29B6F6);

// ─── Light Mode Palette (الوضع النهاري المشرق) ───
const Color backgroundColor = Color(0xFFF8FAFC);
const Color cardColor = Color(0xFFFFFFFF);
const Color surfaceColor = Color(0xFFFFFFFF);
const Color textColor = Color(0xFF1E293B);
const Color subTextColor = Color(0xFF64748B);
const Color hintColor = Color(0xFF94A3B8);
const Color borderColor = Color(0xFFE2E8F0);
const Color dividerColor = Color(0xFFF1F5F9);

// ─── Dark Mode Palette (الوضع الليلي الفخم - Deep Oceanic Obsidian) ───
const Color darkBackground = Color(0xFF081C1E); // خلفية أوبسيديان محيطية عميقة بلمسة مدار
const Color darkSurface = Color(0xFF0E282B); // سطح العناصر والـ AppBars والـ Headers
const Color darkCard = Color(0xFF13363A); // بطاقات زجاجية فاخرة
const Color darkCardElevated = Color(0xFF1A464B); // حوارات ونوافذ ومودلز مرتفعة
const Color darkText = Color(0xFFF8FAFC); // نصوص رئيسية ناصعة ومريحة للعين
const Color darkSubText = Color(0xFF80CBC4); // نصوص فرعية بلمسة تيل راقية
const Color darkHint = Color(0xFF5A7B7E); // نصوص مساعدة وهينت
const Color darkBorder = Color(0xFF1F555A); // حدود ناعمة متوهجة بلون الماركة
const Color darkBorderSubtle = Color(0x1FFFFFFF); // حدود زجاجية خفيفة
const Color darkDivider = Color(0x1AFFFFFF); // فواصل خفيفة جداً

// ─── Gradients (تدرجات مدار الملكية) ───
const LinearGradient primaryGradient = LinearGradient(
  colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient goldGradient = LinearGradient(
  colors: [Color(0xFFFFD54F), Color(0xFFFFB830)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient darkHeaderGradient = LinearGradient(
  colors: [Color(0xFF00BFA5), Color(0xFF00695C)],
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
);

const LinearGradient darkCardGradient = LinearGradient(
  colors: [Color(0xFF153B3F), Color(0xFF0E2A2D)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient darkGlassGradient = LinearGradient(
  colors: [Color(0x3D1A464B), Color(0x1F0E282B)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient lightGlassGradient = LinearGradient(
  colors: [Color(0x80FFFFFF), Color(0x33FFFFFF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─── Logistics Palette (خدمات التوصيل واللوجستيات) ───
const Color logisticsPrimary = Color(0xFF00BFA5);
const Color logisticsSecondary = Color(0xFFE8FBC8);
const Color logisticsAccent = Color(0xFF0F172A);
const Color logisticsSurface = Color(0xFFF5F7F9);
const Color logisticsCardBg = Color(0xFFFFFFFF);
const Color logisticsTextPrimary = Color(0xFF0F172A);
const Color logisticsTextSecondary = Color(0xFF64748B);
