import 'package:flutter/material.dart';

class TourStep {
  final GlobalKey targetKey;
  final String title;
  final String description;

  TourStep({required this.targetKey, required this.title, required this.description});
}

class AppTourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;

  const AppTourOverlay({super.key, required this.steps, required this.onComplete, this.onSkip});

  @override
  State<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<AppTourOverlay> with TickerProviderStateMixin {
  int _currentStep = 0;
  Rect? _targetRect;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..forward(); // Run once instead of repeat

    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 12.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTargetRect();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _calculateTargetRect() {
    if (_currentStep >= widget.steps.length) return;

    final key = widget.steps[_currentStep].targetKey;
    final context = key.currentContext;
    if (context != null && mounted) {
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox) return;
      final RenderBox box = renderObject;
      final Offset offset = box.localToGlobal(Offset.zero);

      // Get the offset of the overlay itself
      final RenderBox overlayBox = this.context.findRenderObject() as RenderBox;
      final Offset overlayOffset = overlayBox.localToGlobal(Offset.zero);

      final Offset relativeOffset = offset - overlayOffset;

      setState(() {
        _targetRect = Rect.fromLTWH(
          relativeOffset.dx,
          relativeOffset.dy,
          box.size.width,
          box.size.height,
        );
      });
    }
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      _fadeController.reverse().then((_) {
        setState(() {
          _currentStep++;
          _calculateTargetRect();
        });
        _fadeController.forward();
      });
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targetRect == null) {
      // Retry calculation if we don't have a rect yet
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _targetRect == null) {
          _calculateTargetRect();
        }
      });
      return const SizedBox.shrink();
    }

    final step = widget.steps[_currentStep];
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dimmed background with hole
          GestureDetector(
            onTap: _nextStep,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: screenSize,
                  painter: _HolePainter(
                    targetRect: _targetRect!.inflate(4),
                    pulseValue: _pulseAnimation.value,
                    primaryColor: theme.primaryColor,
                  ),
                );
              },
            ),
          ),

          // Tooltip and UI
          FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(_fadeAnimation),
              child: _buildTooltip(step, screenSize, theme),
            ),
          ),

          // Skip and Don't Show Again Buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: widget.onSkip ?? widget.onComplete,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'تخطّي',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onComplete,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'عدم الإظهار مرة أخرى',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(TourStep step, Size screenSize, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    bool isBottom = _targetRect!.center.dy < screenSize.height / 2;
    double top = isBottom ? _targetRect!.bottom + 30 : _targetRect!.top - 240;

    if (top < 100) top = 100;
    if (top > screenSize.height - 280) top = screenSize.height - 280;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutQuart,
              top: top,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF0F1717) : Colors.white).withValues(
                      alpha: 0.85,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: (isDark ? Colors.white : theme.primaryColor).withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 40,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Step Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: theme.primaryColor,
                              size: 22,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentStep + 1} / ${widget.steps.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        step.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.7,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Footer
                      Row(
                        children: [
                          // Pulse Dots Indicator
                          Row(
                            children: List.generate(
                              widget.steps.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(right: 6),
                                width: _currentStep == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  gradient:
                                      _currentStep == index
                                          ? LinearGradient(
                                            colors: [
                                              theme.primaryColor,
                                              theme.primaryColor.withValues(alpha: 0.7),
                                            ],
                                          )
                                          : null,
                                  color:
                                      _currentStep != index
                                          ? theme.primaryColor.withValues(alpha: 0.15)
                                          : null,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _nextStep,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.primaryColor,
                                    theme.primaryColor.withValues(alpha: 0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentStep == widget.steps.length - 1
                                        ? 'ابدأ الاستخدام'
                                        : 'التالي',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HolePainter extends CustomPainter {
  final Rect targetRect;
  final double pulseValue;
  final Color primaryColor;

  _HolePainter({required this.targetRect, required this.pulseValue, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.7);

    final fullRectPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath =
        Path()..addRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(20)));

    canvas.drawPath(Path.combine(PathOperation.difference, fullRectPath, holePath), paint);

    // Pulse animation
    final pulsePaint =
        Paint()
          ..color = primaryColor.withValues(alpha: (0.5 - (pulseValue / 24)).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect.inflate(pulseValue), Radius.circular(20 + pulseValue)),
      pulsePaint,
    );

    // Static highlight border
    final borderPaint =
        Paint()
          ..color = primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
    canvas.drawRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(20)), borderPaint);

    // Inner glow
    final glowPaint =
        Paint()
          ..color = primaryColor.withValues(alpha: 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);
    canvas.drawRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(20)), glowPaint);
  }

  @override
  bool shouldRepaint(covariant _HolePainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.pulseValue != pulseValue;
  }
}
