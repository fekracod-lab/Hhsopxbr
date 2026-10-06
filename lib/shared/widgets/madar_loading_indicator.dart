import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class MadarLoadingIndicator extends StatefulWidget {
  final double size;
  final String? message;
  final bool showRing;
  final Color? color;

  const MadarLoadingIndicator({
    super.key,
    this.size = 54.0,
    this.message,
    this.showRing = true,
    this.color,
  });

  const MadarLoadingIndicator.small({
    super.key,
    this.size = 26.0,
    this.message,
    this.showRing = true,
    this.color,
  });

  const MadarLoadingIndicator.large({
    super.key,
    this.size = 84.0,
    this.message = 'لحظة وحدة وتدلل...',
    this.showRing = true,
    this.color,
  });

  @override
  State<MadarLoadingIndicator> createState() => _MadarLoadingIndicatorState();
}

class _MadarLoadingIndicatorState extends State<MadarLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.color ?? app_colors.primaryColor;
    final logoSize = widget.size * (widget.showRing ? 0.62 : 0.85);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RepaintBoundary(
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
            children: [
              // ── Outer Glowing Rotating Ring ──
              if (widget.showRing)
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * math.pi,
                      child: CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _MadarRingPainter(color: primary),
                      ),
                    );
                  },
                ),

              // ── Inner Pulsing Madar Logo ──
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? app_colors.darkCard : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'imges/dala_alqaim_logo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/logo.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.hub_rounded,
                          size: logoSize * 0.6,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

        // ── Optional Loading Message ──
        if (widget.message != null && widget.message!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            widget.message!,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _MadarRingPainter extends CustomPainter {
  final Color color;

  _MadarRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2;
    const strokeWidth = 2.5;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.5),
          color,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      1.8 * math.pi,
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
