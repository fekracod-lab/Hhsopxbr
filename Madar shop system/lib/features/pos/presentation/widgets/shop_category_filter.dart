import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../products/domain/entities/shop_category.dart';

/// شريط تصنيفات وأقسام المتجر المفلترة في نقطة البيع (Shop Category Filter)
class ShopCategoryFilter extends StatelessWidget {
  final List<ShopCategory> categories;
  final String selectedCategory;
  final Function(String category) onCategorySelected;

  const ShopCategoryFilter({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildChip('الكل', Icons.grid_view_rounded, isDark),
          ...categories.map((c) => _buildChip(c.name, IconData(c.iconCode, fontFamily: 'MaterialIcons'), isDark)),
        ],
      ),
    );
  }

  Widget _buildChip(String name, IconData icon, bool isDark) {
    final isSelected = selectedCategory == name;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: () => onCategorySelected(name),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? ShopColors.primary
                : (isDark ? ShopColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? ShopColors.primary
                  : (isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: ShopColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : (isDark ? ShopColors.darkText : ShopColors.lightText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
