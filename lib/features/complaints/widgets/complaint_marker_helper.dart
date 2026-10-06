import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ComplaintMarkerHelper {
  static final Map<String, BitmapDescriptor> _markerCache = {};

  static double getMarkerHue(String category, String status) {
    if (status == 'resolved') {
      return BitmapDescriptor.hueGreen;
    }

    final cat = category.toLowerCase();
    if (cat.contains('حفر') || cat.contains('تخسف') || cat.contains('شارع')) {
      return BitmapDescriptor.hueOrange;
    }
    if (cat.contains('ماء') || cat.contains('بوري') || cat.contains('تسريب')) {
      return BitmapDescriptor.hueAzure;
    }
    if (cat.contains('كهرباء') || cat.contains('واير') || cat.contains('محول')) {
      return BitmapDescriptor.hueYellow;
    }
    if (cat.contains('مجاري') || cat.contains('منهول') || cat.contains('فتحة')) {
      return BitmapDescriptor.hueViolet;
    }
    if (cat.contains('نفايات') || cat.contains('زبالة') || cat.contains('حاوية')) {
      return BitmapDescriptor.hueRed;
    }
    if (cat.contains('إنارة') || cat.contains('انارة') || cat.contains('عمود')) {
      return BitmapDescriptor.hueCyan;
    }

    return BitmapDescriptor.hueRose;
  }

  static Color getCategoryColor(String category, String status) {
    if (status == 'resolved') {
      return const Color(0xFF10B981);
    }

    final cat = category.toLowerCase();
    if (cat.contains('حفر') || cat.contains('تخسف') || cat.contains('شارع')) {
      return const Color(0xFFF59E0B);
    }
    if (cat.contains('ماء') || cat.contains('بوري') || cat.contains('تسريب')) {
      return const Color(0xFF0284C7);
    }
    if (cat.contains('كهرباء') || cat.contains('واير') || cat.contains('محول')) {
      return const Color(0xFFEAB308);
    }
    if (cat.contains('مجاري') || cat.contains('منهول') || cat.contains('فتحة')) {
      return const Color(0xFF8B5CF6);
    }
    if (cat.contains('نفايات') || cat.contains('زبالة') || cat.contains('حاوية')) {
      return const Color(0xFFEF4444);
    }
    if (cat.contains('إنارة') || cat.contains('انارة') || cat.contains('عمود')) {
      return const Color(0xFF06B6D4);
    }

    return const Color(0xFFF43F5E);
  }

  static IconData getCategoryIcon(String category, String status) {
    if (status == 'resolved') {
      return Icons.check_circle_rounded;
    }
    final cat = category.toLowerCase();
    if (cat.contains('حفر') || cat.contains('تخسف') || cat.contains('شارع')) {
      return Icons.construction_rounded;
    }
    if (cat.contains('ماء') || cat.contains('بوري') || cat.contains('تسريب') || cat.contains('طوفان')) {
      return Icons.water_drop_rounded;
    }
    if (cat.contains('كهرباء') || cat.contains('واير') || cat.contains('محول')) {
      return Icons.bolt_rounded;
    }
    if (cat.contains('مجاري') || cat.contains('منهول') || cat.contains('فتحة')) {
      return Icons.plumbing_rounded;
    }
    if (cat.contains('نفايات') || cat.contains('زبالة') || cat.contains('حاوية')) {
      return Icons.delete_sweep_rounded;
    }
    if (cat.contains('إنارة') || cat.contains('انارة') || cat.contains('عمود') || cat.contains('ضوء')) {
      return Icons.lightbulb_rounded;
    }
    return Icons.report_problem_rounded;
  }

  static String getCategoryEmoji(String category) {
    return '';
  }

  static String getStatusLabel(String status) {
    switch (status) {
      case 'resolved':
        return 'تم الحل والإصلاح';
      case 'in_progress':
        return 'قيد المعالجة بالبلدية';
      case 'rejected':
        return 'مرفوض / غير مطابق';
      case 'pending':
      default:
        return 'قيد المتابعة';
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'resolved':
        return const Color(0xFF10B981);
      case 'in_progress':
        return const Color(0xFF3B82F6);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  /// Create a high-definition custom square badge marker with category vector icon & status for Google Map
  static Future<BitmapDescriptor> createCustomSquareMarker({
    required String category,
    required String status,
  }) async {
    final color = getCategoryColor(category, status);
    final iconData = getCategoryIcon(category, status);
    final cacheKey = '${iconData.codePoint}-${color.toARGB32()}-$status';

    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    try {
      const double width = 120.0;
      const double height = 138.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

      // 1. Draw Drop Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 10, 96, 96),
        const Radius.circular(26),
      );
      canvas.drawRRect(rect.shift(const Offset(0, 5)), shadowPaint);

      // 2. Draw Bottom Pointer Pin (Triangle Needle)
      final pointerPath = Path()
        ..moveTo(width / 2 - 14, 102)
        ..lineTo(width / 2, 132)
        ..lineTo(width / 2 + 14, 102)
        ..close();

      final pointerShadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(pointerPath.shift(const Offset(0, 3)), pointerShadow);

      final pointerPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(pointerPath, pointerPaint);

      // 3. Draw White Badge Background
      final bgPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, bgPaint);

      // 4. Draw Thick Category Colored Border
      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5;
      canvas.drawRRect(rect, borderPaint);

      // 5. Draw Inner Colored Circle Disc
      final innerCirclePaint = Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(60, 58), 34, innerCirclePaint);

      final innerCircleBorder = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(const Offset(60, 58), 34, innerCircleBorder);

      // 6. Draw Vector Icon Glyph in the Center
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontSize: 44,
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((width - textPainter.width) / 2, 58 - (textPainter.height / 2)),
      );

      // 7. Top Status Dot Indicator
      final statusColor = status == 'resolved' ? const Color(0xFF10B981) : color;
      final statusOuterPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(width - 20, 20), 10, statusOuterPaint);

      final statusDotPaint = Paint()
        ..color = statusColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(width - 20, 20), 7, statusDotPaint);

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        final descriptor = BitmapDescriptor.bytes(bytes);
        _markerCache[cacheKey] = descriptor;
        return descriptor;
      }
    } catch (e) {
      debugPrint('Custom marker render error: $e');
    }

    // Fallback to standard marker
    final hue = getMarkerHue(category, status);
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  // ══════════════════════════════════════════════════════════
  // قائمة محافظات ومدن العراق (All Iraq Governorates & Cities)
  // ══════════════════════════════════════════════════════════
  static const List<String> iraqGovernorates = [
    'بغداد',
    'الأنبار',
    'البصرة',
    'أربيل',
    'النجف الأشرف',
    'كربلاء المقدسة',
    'نينوى (الموصل)',
    'كركوك',
    'بابل (الحلة)',
    'ديالى (بعقوبة)',
    'صلاح الدين (تكريت / سامراء)',
    'ذي قار (الناصرية)',
    'واسط (الكوت)',
    'ميسان (العمارة)',
    'المثنى (السماوة)',
    'الديوانية (القادسية)',
    'دهوك',
    'السليمانية',
  ];

  static List<String> getCitiesForGovernorate(String gov) {
    switch (gov) {
      case 'الأنبار':
        return [
          'القائم',
          'الرمادي',
          'الفلوجة',
          'هيت',
          'حديثة',
          'الرطبة',
          'راوة',
          'عنة',
          'الكرمة',
          'الخالدية',
          'حصيبة',
          'الرمانة',
          'العبيدي',
        ];
      case 'بغداد':
        return [
          'الكرخ',
          'الرصافة',
          'المنصور',
          'الكرادة',
          'الأعظمية',
          'الكاظمية',
          'الدورة',
          'الشعب',
          'مدينة الصدر',
          'السيدية',
          'العامرية',
          'الغزالية',
          'الزعفرانية',
          'بغداد الجديدة',
        ];
      case 'البصرة':
        return ['المركز (العشار)', 'الجمهورية', 'الجبيلة', 'القرنة', 'الزبير', 'شط العرب', 'أبي الخصيب', 'الفاو'];
      case 'نينوى (الموصل)':
        return ['الموصل الأيمن', 'الموصل الأيسر', 'تلعفر', 'الحمدانية', 'سنجار', 'الشيخان'];
      case 'أربيل':
        return ['أربيل المركز', 'عنكاوا', 'عينكاوة', 'سوران', 'شقلاوة', 'كويسنجق'];
      case 'كربلاء المقدسة':
        return ['المركز (قرب الحرمين)', 'حي الحسين', 'حي العباس', 'الهندية', 'عين التمر'];
      case 'النجف الأشرف':
        return ['المدينة القديمة', 'الكوفة', 'حي الغدير', 'حي الأمير', 'المناذرة'];
      default:
        return ['المركز', 'حي الجمعية', 'السوق الكبير', 'حي الزهور', 'حي المعلمين'];
    }
  }
}
