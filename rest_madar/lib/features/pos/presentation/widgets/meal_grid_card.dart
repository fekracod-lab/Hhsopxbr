import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/pos_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../services/cloudinary_service.dart';

/// بطاقة الوجبة في شبكة الكاشير — تصميم موحّد مع دعم الصور والأقسام والأيقونات
class MealGridCard extends StatefulWidget {
  final Map<String, dynamic> mealData;
  final VoidCallback onQuickAdd;
  final VoidCallback onCustomize;
  final VoidCallback? onToggleAvailability;

  const MealGridCard({
    super.key,
    required this.mealData,
    required this.onQuickAdd,
    required this.onCustomize,
    this.onToggleAvailability,
  });

  @override
  State<MealGridCard> createState() => _MealGridCardState();
}

class _MealGridCardState extends State<MealGridCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    final name = widget.mealData['name'] ?? widget.mealData['title'] ?? 'وجبة';
    final price = (widget.mealData['price'] ?? 0).toDouble();
    final imageUrl = widget.mealData['imageUrl'] ?? widget.mealData['photoUrl'];
    final category = (widget.mealData['category'] ?? '').toString();
    final hasVariants =
        (widget.mealData['sizes'] is List && (widget.mealData['sizes'] as List).isNotEmpty) ||
            (widget.mealData['addons'] is List && (widget.mealData['addons'] as List).isNotEmpty);
    final bool isAvailable = widget.mealData['isAvailable'] != false &&
        widget.mealData['available'] != false &&
        widget.mealData['inStock'] != false;

    final categoryIcon = CategoryIconHelper.getIconForCategory(category);
    final categoryColor = CategoryIconHelper.getColorForCategory(category);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isAvailable ? c.card : c.card.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !isAvailable
                ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                : (_isHovered ? c.primary : c.border),
            width: (!isAvailable || _isHovered) ? 1.8 : 1.0,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: (isAvailable ? c.primary : const Color(0xFFEF4444)).withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              if (!isAvailable) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('الوجبة "$name" مسجلة كنافذة الكمية اليوم (86\'d). اضغط على زر الإتاحة أولاً لتفعيلها.'),
                    backgroundColor: const Color(0xFFEF4444),
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }
              if (hasVariants) {
                widget.onCustomize();
              } else {
                widget.onQuickAdd();
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // صورة الوجبة أو أيقونة بديلة
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              CloudinaryService.getOptimizedUrl(imageUrl, width: 320, height: 220),
                              fit: BoxFit.cover,
                              cacheWidth: 320,
                              cacheHeight: 220,
                              errorBuilder: (_, _, _) =>
                                  _buildPlaceholder(c, category),
                            )
                          : _buildPlaceholder(c, category),
                      // شريط التدرج السفلي
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                c.background.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // تصنيف الوجبة مع الأيقونة المخصصة
                      if (category.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: c.surface.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: c.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(categoryIcon, color: categoryColor, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  category,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: c.textPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // شارة الإضافات
                      if (hasVariants)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.gold.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              size: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),

                      // زر تبديل التوفر السريع (نفذت الكمية 86 / متاح)
                      if (widget.onToggleAvailability != null)
                        Positioned(
                          top: 8,
                          left: hasVariants ? 38 : 8,
                          child: InkWell(
                            onTap: widget.onToggleAvailability,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? Colors.black.withValues(alpha: 0.65)
                                    : const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAvailable ? Icons.block_rounded : Icons.check_circle_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isAvailable ? 'نفاد؟' : 'إتاحة',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // غطاء نافذة الكمية (86'd Overlay)
                      if (!isAvailable)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.55),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.do_not_disturb_on_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'نفذت الكمية (86)',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
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

                // بيانات الوجبة والسعر
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: isAvailable ? c.textPrimary : c.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            decoration: isAvailable ? null : TextDecoration.lineThrough,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              PosConstants.formatMoney(price),
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: isAvailable ? c.accent : c.textMuted,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            // زر الإضافة السريع
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? c.primary.withValues(alpha: 0.18)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isAvailable ? c.primary : const Color(0xFFEF4444).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Icon(
                                isAvailable
                                    ? (_isHovered ? Icons.add_shopping_cart_rounded : Icons.add_rounded)
                                    : Icons.block_rounded,
                                color: isAvailable ? c.accent : const Color(0xFFEF4444),
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(PosColors c, String category) {
    final icon = CategoryIconHelper.getIconForCategory(category);
    final color = CategoryIconHelper.getColorForCategory(category);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            c.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, size: 42, color: color.withValues(alpha: 0.7)),
      ),
    );
  }
}