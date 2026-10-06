import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dalal_alqaim/features/trip/presentation/trip_design.dart';

class PremiumFinderPainter extends CustomPainter {
  final Animation<double> pulse;
  final Animation<double> spin;

  PremiumFinderPainter({required this.pulse, required this.spin})
    : super(repaint: Listenable.merge([pulse, spin]));

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.9;

    // 1. Draw Expanding Waves (Pulse)
    final pulsePaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = TripDesign.primary.withValues(alpha: 0.05);

    for (int i = 0; i < 3; i++) {
      final val = (pulse.value + i * 0.35) % 1.0;
      final radius = maxRadius * val;
      final opacity = (1.0 - val).clamp(0.0, 1.0);
      pulsePaint.color = Colors.white.withValues(alpha: (opacity * 0.1).clamp(0.0, 1.0));
      canvas.drawCircle(center, radius, pulsePaint);
    }

    // 2. Draw Rotating Dashed Ring
    final ringPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.3);

    final dashRadius = maxRadius * 0.55;
    final dashCount = 30;
    final angleStep = (2 * pi) / dashCount;
    final rotateOffset = spin.value * 2 * pi;

    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) continue;
      final angle = (i * angleStep) + rotateOffset;
      final p1 = Offset(center.dx + cos(angle) * dashRadius, center.dy + sin(angle) * dashRadius);
      final p2 = Offset(
        center.dx + cos(angle + angleStep * 0.6) * dashRadius,
        center.dy + sin(angle + angleStep * 0.6) * dashRadius,
      );
      canvas.drawLine(p1, p2, ringPaint);
    }

    // 3. Draw Outer Orbit Ring
    final orbitPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.1);
    canvas.drawCircle(center, maxRadius * 0.8, orbitPaint);

    // 4. Draw Rotating Scanner Gradient
    final scannerRect = Rect.fromCircle(center: center, radius: maxRadius * 0.5);
    final scannerPaint =
        Paint()
          ..shader = SweepGradient(
            center: Alignment.center,
            startAngle: 0.0,
            endAngle: 2 * pi,
            colors: [
              Colors.white.withValues(alpha: 0.0),
              TripDesign.primary.withValues(alpha: 0.3),
            ],
            stops: const [0.7, 1.0],
            transform: GradientRotation(spin.value * 2 * pi * -1),
          ).createShader(scannerRect);

    canvas.drawArc(scannerRect, 0, 2 * pi, true, scannerPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class SearchingView extends StatefulWidget {
  final VoidCallback onCancel;
  final String destinationAddress;
  final bool isEmbedded;

  const SearchingView({
    super.key,
    required this.onCancel,
    required this.destinationAddress,
    this.isEmbedded = false,
  });

  @override
  State<SearchingView> createState() => _SearchingViewState();
}

class _SearchingViewState extends State<SearchingView> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _spinController;
  int _currentTextIndex = 0;

  final List<String> _searchMessages = [
    "جاري البحث عن كابتن قريب...",
    "نتصل بالسائقين في منطقتك...",
    "يتم تحديد أفضل مسار لك...",
    "ثوانٍ قليلة ونكون جاهزون...",
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat();

    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() => _currentTextIndex = (_currentTextIndex + 1) % _searchMessages.length);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: PremiumFinderPainter(pulse: _pulseController, spin: _spinController),
          ),
        ),
        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: TripDesign.primary.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: ClipOval(
              child: Image.asset(
                'imges/dala_alqaim_logo.png',
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stackTrace) =>
                        const Icon(Icons.location_searching, color: TripDesign.primary),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Spacer(flex: 2),
              _buildStatusText(),
              const Spacer(flex: 3),
              _buildTripSummary(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _glassIconButton(Icons.arrow_back, () => Navigator.pop(context)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Text(
              "جاري البحث...",
              style: TextStyle(
                color: Colors.white,
                fontFamily: TripDesign.kFontFamily,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Text(
          _searchMessages[_currentTextIndex],
          key: ValueKey<int>(_currentTextIndex),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TripDesign.kFontFamily,
            fontSize: widget.isEmbedded ? 18 : 24,
            color: widget.isEmbedded ? TripDesign.textColor : Colors.white,
            fontWeight: widget.isEmbedded ? FontWeight.bold : FontWeight.w300,
            shadows:
                widget.isEmbedded
                    ? null
                    : [const Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2))],
          ),
        ),
      ),
    );
  }

  Widget _buildTripSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        boxShadow: TripDesign.softShadow,
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: TripDesign.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                "إلى:",
                style: TextStyle(fontFamily: TripDesign.kFontFamily, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.destinationAddress,
                  style: const TextStyle(
                    fontFamily: TripDesign.kFontFamily,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: widget.onCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEFF2F5),
                foregroundColor: TripDesign.error,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "إلغاء الطلب",
                    style: TextStyle(
                      fontFamily: TripDesign.kFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
