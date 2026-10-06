import 'package:flutter/material.dart';

/// خلفية هندسية جمالية متحركة بلمسات فيروزية فاخرة تعكس هوية مدار
class DashboardLightTealPainter extends CustomPainter {
  final bool isDark;

  const DashboardLightTealPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // الخلفية الأساسية المتدرجة
    final bgGradient = LinearGradient(
      colors: isDark
          ? [
              const Color(0xFF081C1E),
              const Color(0xFF0D2528),
              const Color(0xFF081C1E),
            ]
          : [
              const Color(0xFFF4FAF9),
              const Color(0xFFEBF5F4),
              const Color(0xFFF9FCFC),
            ],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    );

    final bgPaint = Paint()..shader = bgGradient.createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // توهج ضوئي في الزاوية العلوية اليمنى
    final glowPaint1 = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFF00BFA5).withValues(alpha: 0.15),
                const Color(0xFF00BFA5).withValues(alpha: 0.0),
              ]
            : [
                const Color(0xFF00BFA5).withValues(alpha: 0.12),
                const Color(0xFF00BFA5).withValues(alpha: 0.0),
              ],
        radius: 0.8,
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.9, size.height * 0.1),
          radius: size.width * 0.7,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.1),
      size.width * 0.7,
      glowPaint1,
    );

    // توهج ضوئي ذهبي خافت في المنتصف السفلي
    final glowPaint2 = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFFFFB830).withValues(alpha: 0.08),
                const Color(0xFFFFB830).withValues(alpha: 0.0),
              ]
            : [
                const Color(0xFFFFB830).withValues(alpha: 0.06),
                const Color(0xFFFFB830).withValues(alpha: 0.0),
              ],
        radius: 0.6,
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.1, size.height * 0.65),
          radius: size.width * 0.5,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.65),
      size.width * 0.5,
      glowPaint2,
    );

    // خطوط ديكور زجاجية انسيابية ناعمة جداً
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF00BFA5)).withValues(alpha: isDark ? 0.03 : 0.04)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.3);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.22,
      size.width,
      size.height * 0.35,
    );

    path.moveTo(0, size.height * 0.55);
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.65,
      size.width,
      size.height * 0.58,
    );

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant DashboardLightTealPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
