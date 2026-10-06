import 'package:flutter/material.dart';
import 'dart:math';

/// ويدجيت تراكب بصري متوهج يُعرض فوق العنصر المستهدف لإرشاد المستخدم
/// Glowing overlay that highlights a target widget on screen
class SmartAssistantOverlay extends StatefulWidget {
  final Rect targetRect;
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  const SmartAssistantOverlay({
    super.key,
    required this.targetRect,
    required this.message,
    this.onDismiss,
    this.onTap,
  });

  @override
  State<SmartAssistantOverlay> createState() => _SmartAssistantOverlayState();
}

class _SmartAssistantOverlayState extends State<SmartAssistantOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // الخلفية الشفافة المعتمة
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: CustomPaint(
                  painter: _HighlightPainter(
                    targetRect: widget.targetRect,
                    animation: _pulseAnimation,
                  ),
                ),
              ),
            ),

            // الحلقة المتوهجة حول العنصر
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final expandAmount = 8.0 + (_pulseAnimation.value * 6.0);
                final glowOpacity = 0.3 + (_pulseAnimation.value * 0.4);

                return Positioned(
                  left: widget.targetRect.left - expandAmount,
                  top: widget.targetRect.top - expandAmount,
                  width: widget.targetRect.width + (expandAmount * 2),
                  height: widget.targetRect.height + (expandAmount * 2),
                  child: GestureDetector(
                    onTap: widget.onTap,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF4ECCA3)
                              .withValues(alpha: glowOpacity),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4ECCA3)
                                .withValues(alpha: glowOpacity * 0.5),
                            blurRadius: 20 + (_pulseAnimation.value * 10),
                            spreadRadius: 4 + (_pulseAnimation.value * 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // فقاعة الرسالة أسفل أو أعلى العنصر
            _buildMessageBubble(context),

            // زر تخطي
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'تخطي',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildMessageBubble(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isAbove = widget.targetRect.top > screenHeight * 0.5;

    final top = isAbove ? null : widget.targetRect.bottom + 20;
    final bottom = isAbove ? screenHeight - widget.targetRect.top + 20 : null;

    return Positioned(
      top: top,
      bottom: bottom,
      left: 24,
      right: 24,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, sin(_pulseAnimation.value * pi) * 3),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F2323), Color(0xFF113033)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4ECCA3).withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF26A69A).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Color(0xFF4ECCA3),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// رسام مخصص لتعتيم الخلفية مع استثناء المنطقة المضيئة
class _HighlightPainter extends CustomPainter {
  final Rect targetRect;
  final Animation<double> animation;

  _HighlightPainter({
    required this.targetRect,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.65);

    // رسم الخلفية المعتمة مع ثقب شفاف حول العنصر المستهدف
    final outer = Rect.fromLTWH(0, 0, size.width, size.height);
    final expandAmount = 6.0;
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        targetRect.left - expandAmount,
        targetRect.top - expandAmount,
        targetRect.right + expandAmount,
        targetRect.bottom + expandAmount,
      ),
      const Radius.circular(14),
    );

    final path = Path()
      ..addRect(outer)
      ..addRRect(inner);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HighlightPainter oldDelegate) => true;
}


class SmartAssistantOverlayManager {
  static OverlayEntry? _entry;

  static void show(BuildContext context, Rect rect, String message) {
    dismiss();
    _entry = OverlayEntry(
      builder: (context) => SmartAssistantOverlay(
        targetRect: rect,
        message: message,
        onDismiss: dismiss,
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}
