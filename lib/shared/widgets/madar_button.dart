import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/shared/widgets/madar_loading_indicator.dart';

class MadarButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final LinearGradient? gradient;
  final Color? color;
  final double? width;
  final double height;
  final double borderRadius;
  final TextStyle? textStyle;
  final bool isOutlined;

  const MadarButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.gradient,
    this.color,
    this.width,
    this.height = 54,
    this.borderRadius = 16,
    this.textStyle,
    this.isOutlined = false,
  });

  @override
  State<MadarButton> createState() => _MadarButtonState();
}

class _MadarButtonState extends State<MadarButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _animController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _animController.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    final defaultGradient = widget.gradient ?? app_colors.primaryGradient;

    final decoration = widget.isOutlined
        ? BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: isEnabled ? app_colors.primaryColor : Colors.grey.shade400,
              width: 1.5,
            ),
          )
        : BoxDecoration(
            gradient: isEnabled ? defaultGradient : null,
            color: isEnabled ? null : Colors.grey.shade600,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: isEnabled && !widget.isOutlined
                ? [
                    BoxShadow(
                      color: app_colors.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          );

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: isEnabled ? widget.onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: decoration,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: widget.isLoading
              ? MadarLoadingIndicator.small(
                  size: 26,
                  color: widget.isOutlined ? app_colors.primaryColor : Colors.white,
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: widget.isOutlined ? app_colors.primaryColor : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.text,
                      style: widget.textStyle ??
                          TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: widget.isOutlined ? app_colors.primaryColor : Colors.white,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
