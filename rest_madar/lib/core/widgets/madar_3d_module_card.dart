import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// بطاقة ثلاثية الأبعاد متطورة لعرض أقسام وصفحات المنصة الرئيسية
/// مصممة بشكل مربع أنيق (Square Card) مخصص للشاشات الرئيسية بدون كلام أو حشو،
/// مع التركيز على الصورة ثلاثية الأبعاد والتوهج اللمسي وتأثيرات التحويم الفاخرة.
class Madar3DModuleCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? imageAsset;
  final IconData fallbackIcon;
  final Color accentColor;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;
  final String? countText;
  final bool isFeatured;
  final bool isSquare;

  const Madar3DModuleCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageAsset,
    required this.fallbackIcon,
    required this.accentColor,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
    this.countText,
    this.isFeatured = false,
    this.isSquare = true,
  });

  @override
  State<Madar3DModuleCard> createState() => _Madar3DModuleCardState();
}

class _Madar3DModuleCardState extends State<Madar3DModuleCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    final isDark = context.isDarkMode;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _isHovered
                  ? widget.accentColor.withValues(alpha: 0.75)
                  : (widget.isFeatured
                      ? widget.accentColor.withValues(alpha: 0.35)
                      : c.border),
              width: _isHovered ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.accentColor.withValues(alpha: isDark ? 0.35 : 0.2)
                    : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: _isHovered ? 24 : 10,
                offset: Offset(0, _isHovered ? 8 : 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(22),
              splashColor: widget.accentColor.withValues(alpha: 0.15),
              highlightColor: widget.accentColor.withValues(alpha: 0.08),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // خلفية إشعاعية خفيفة تضيء عند تمرير الماوس
                  if (_isHovered)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: RadialGradient(
                            colors: [
                              widget.accentColor.withValues(alpha: isDark ? 0.18 : 0.1),
                              Colors.transparent,
                            ],
                            radius: 0.85,
                          ),
                        ),
                      ),
                    ),

                  // المحتوى المربع الأنيق
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // الصورة ثلاثية الأبعاد 3D
                        Expanded(
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              constraints: const BoxConstraints(
                                maxWidth: 90,
                                maxHeight: 90,
                              ),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    widget.accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                    widget.accentColor.withValues(alpha: isDark ? 0.04 : 0.02),
                                  ],
                                ),
                                border: Border.all(
                                  color: widget.accentColor.withValues(alpha: _isHovered ? 0.45 : 0.2),
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: widget.imageAsset != null
                                    ? Image.asset(
                                        widget.imageAsset!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (ctx, err, stack) => _buildFallbackIcon(),
                                      )
                                    : _buildFallbackIcon(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // الاسم فقط بدون كلام أو نصوص فرعية مشتتة
                        Text(
                          widget.title,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _isHovered ? widget.accentColor : c.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // شارة العداد أو التنبيه في الزاوية العلوية
                  if (widget.badgeText != null || widget.countText != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (widget.badgeColor ?? widget.accentColor),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: (widget.badgeColor ?? widget.accentColor).withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.countText ?? widget.badgeText!,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.accentColor.withValues(alpha: 0.15),
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          widget.fallbackIcon,
          size: 32,
          color: widget.accentColor,
        ),
      ),
    );
  }
}
