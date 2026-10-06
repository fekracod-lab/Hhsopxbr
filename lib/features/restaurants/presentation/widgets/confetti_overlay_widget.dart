import 'dart:math' as math;
import 'package:flutter/material.dart';

/// نموذج جسيم الاحتفال والكونفيتي (Particle Model)
class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });
}

/// رسام الكونفيتي المعزول (Confetti Custom Painter)
class ConfettiPainter extends CustomPainter {
  final List<Particle> particles;
  ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      if (p.x < 0 || p.x > 1 || p.y > 1) continue;
      final px = p.x * size.width;
      final py = p.y * size.height;
      paint.color = p.color;
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation * math.pi / 180);
      if (p.size.toInt() % 2 == 0) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => true;
}

/// ويدجت طبقة الكونفيتي المعزولة تماماً عن إعادة بناء الصفحة الرئيسية (Isolated Confetti Overlay)
class ConfettiOverlayWidget extends StatefulWidget {
  const ConfettiOverlayWidget({super.key});

  @override
  State<ConfettiOverlayWidget> createState() => ConfettiOverlayWidgetState();
}

class ConfettiOverlayWidgetState extends State<ConfettiOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;
  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        if (_particles.isNotEmpty) {
          setState(() {
            for (final p in _particles) {
              p.x += p.vx;
              p.y += p.vy;
              p.vy += 0.0005; // جاذبية خفيفة
              p.rotation += p.rotationSpeed;
              p.vx += (math.Random().nextDouble() - 0.5) * 0.001;
            }
            _particles.removeWhere((p) => p.y > 1.1 || p.x < -0.1 || p.x > 1.1);
          });
        }
      });
  }

  /// إطلاق تأثير الكونفيتي عند الفوز أو إنشاء سلة جماعية
  void trigger() {
    _particles.clear();
    final random = math.Random();
    final colors = [
      const Color(0xFF26A69A),
      const Color(0xFF00796B),
      const Color(0xFFFF7043),
      const Color(0xFFFFB74D),
      const Color(0xFF4DB6AC),
      Colors.white,
    ];
    for (int i = 0; i < 90; i++) {
      _particles.add(Particle(
        x: random.nextDouble(),
        y: -0.1,
        vx: (random.nextDouble() - 0.5) * 0.02,
        vy: random.nextDouble() * 0.015 + 0.005,
        size: random.nextDouble() * 8 + 4,
        color: colors[random.nextInt(colors.length)],
        rotation: random.nextDouble() * 360,
        rotationSpeed: (random.nextDouble() - 0.5) * 8,
      ));
    }
    _confettiController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: ConfettiPainter(particles: _particles),
        ),
      ),
    );
  }
}
