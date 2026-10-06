import 'dart:math' as math;
import 'package:flutter/material.dart';

enum ParticleType { snow, bell, star }

class FestiveParticle {
  double x = math.Random().nextDouble();
  double y = math.Random().nextDouble();
  double radius = math.Random().nextDouble() * 2 + 1;
  double velocity = math.Random().nextDouble() * 2 + 1;
  double rotation = math.Random().nextDouble() * math.pi * 2;
  double rotationSpeed = (math.Random().nextDouble() - 0.5) * 0.1;
  ParticleType type = ParticleType.snow;

  FestiveParticle({this.type = ParticleType.snow});
}

class FestivePainter extends CustomPainter {
  final List<FestiveParticle> particles;
  final double controllerValue;
  final Color snowColor;
  final Color bellColor;

  FestivePainter({
    required this.particles,
    required this.controllerValue,
    required this.snowColor,
    required this.bellColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Stronger wind/Air effect
    double windBase = math.sin(controllerValue * math.pi * 2);

    // Draw subtle wind streaks (air animation)
    // Use the snowColor as a base but ensure it's visible even if the input has low opacity
    final baseColor = snowColor.withValues(alpha: 1.0);
    final windPaint =
        Paint()
          ..color = baseColor.withValues(alpha: isDark ? 0.12 : 0.06)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

    for (int i = 0; i < 4; i++) {
      double y = ((i * 0.25) + (controllerValue * 0.15)) % 1.0;
      double xDist = size.width * 0.4;
      double xStart =
          (math.sin(controllerValue * math.pi + i) * 0.3 + 0.5) * size.width - (xDist / 2);

      Path windPath = Path();
      windPath.moveTo(xStart, y * size.height);
      windPath.conicTo(
        xStart + (xDist * 0.5),
        (y + 0.05) * size.height,
        xStart + xDist,
        (y + 0.01) * size.height,
        0.5,
      );
      canvas.drawPath(windPath, windPaint);
    }

    for (var particle in particles) {
      double movement = particle.velocity * 0.005;
      particle.y += movement;

      // Stronger air animation: drift + random gust
      double gust = math.sin(controllerValue * math.pi * 4 + particle.y * 5) * 0.5;
      particle.x += (windBase + gust + (particle.velocity * 0.5)) * 0.003;

      particle.rotation += particle.rotationSpeed;

      // Wrap around screen
      if (particle.y > 1.0) {
        particle.y = -0.1;
        particle.x = math.Random().nextDouble();
      }
      if (particle.x > 1.2) particle.x = -0.2;
      if (particle.x < -0.2) particle.x = 1.2;

      final offset = Offset(particle.x * size.width, particle.y * size.height);

      if (particle.type == ParticleType.snow) {
        // Glowing snow effect for better visibility
        final paint =
            Paint()
              ..color = snowColor.withValues(alpha: (snowColor.a * 0.6).clamp(0.0, 1.0))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
        canvas.drawCircle(offset, particle.radius, paint);

        final corePaint = Paint()..color = snowColor;
        canvas.drawCircle(offset, particle.radius * 0.7, corePaint);
      } else if (particle.type == ParticleType.bell) {
        _drawBell(canvas, offset, particle.radius * 4, particle.rotation, bellColor);
      } else if (particle.type == ParticleType.star) {
        _drawStar(
          canvas,
          offset,
          particle.radius * 3,
          particle.rotation,
          Colors.amber.withValues(alpha: 0.5),
        );
      }
    }
  }

  bool get isDark =>
      snowColor.computeLuminance() > 0.5; // Simple check for dark mode context (white snow)

  void _drawBell(Canvas canvas, Offset offset, double size, double rotation, Color color) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(rotation);

    final paint = Paint()..color = color;
    final path = Path();
    // Simplified bell shape
    path.moveTo(-size / 2, size / 2);
    path.quadraticBezierTo(-size / 2, -size / 2, 0, -size / 2);
    path.quadraticBezierTo(size / 2, -size / 2, size / 2, size / 2);
    path.close();

    canvas.drawPath(path, paint);
    // Draw bell clapper
    canvas.drawCircle(Offset(0, size / 2), size / 4, paint);

    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset offset, double size, double rotation, Color color) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(rotation);
    final paint = Paint()..color = color;
    // Drawing a simple star or just a glowing diamond
    final path = Path();
    path.moveTo(0, -size);
    path.lineTo(size / 3, -size / 3);
    path.lineTo(size, 0);
    path.lineTo(size / 3, size / 3);
    path.lineTo(0, size);
    path.lineTo(-size / 3, size / 3);
    path.lineTo(-size, 0);
    path.lineTo(-size / 3, -size / 3);
    path.close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FestivePainter oldDelegate) => true;
}

class SnowfallWrapper extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final Color? snowflakeColor;
  final bool showBells;
  final bool showStars;

  const SnowfallWrapper({
    super.key,
    required this.child,
    this.particleCount = 60,
    this.snowflakeColor,
    this.showBells = true,
    this.showStars = true,
  });

  @override
  State<SnowfallWrapper> createState() => _SnowfallWrapperState();
}

class _SnowfallWrapperState extends State<SnowfallWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<FestiveParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _initializeParticles();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat(); // Slowed down significantly
  }

  void _initializeParticles() {
    final random = math.Random();
    for (int i = 0; i < widget.particleCount; i++) {
      ParticleType type = ParticleType.snow;
      if (widget.showBells && random.nextDouble() < 0.15) {
        type = ParticleType.bell;
      } else if (widget.showStars && random.nextDouble() < 0.1) {
        type = ParticleType.star;
      }
      _particles.add(FestiveParticle(type: type));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultSnowColor =
        isDark ? Colors.white.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.05);
    final bellColor =
        isDark ? Colors.amber.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.2);

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: FestivePainter(
                  particles: _particles,
                  controllerValue: _controller.value,
                  snowColor: widget.snowflakeColor ?? defaultSnowColor,
                  bellColor: bellColor,
                ),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}
