// مصفاة الأقسام لنقطة البيع (MADAR SHOP POS Category Filter)
// Presentation Layer — Dynamic Catalog Chips

import 'package:flutter/material.dart';
import '../controllers/windows_pos_controller.dart';

class PosCategoryFilter extends StatelessWidget {
  final WindowsPosController controller;

  const PosCategoryFilter({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = controller.categories;
    final selectedId = controller.selectedCategoryId;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final catId = isAll ? 'ALL' : categories[index - 1].categoryId;
          final catName = isAll ? 'الكل' : categories[index - 1].name;
          final isSelected = selectedId == catId;

          return FilterChip(
            selected: isSelected,
            label: Text(
              catName,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Cairo',
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            selectedColor: const Color(0xFF1E88E5),
            backgroundColor: isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9),
            checkmarkColor: Colors.white,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF1E88E5)
                    : (isDark ? Colors.white10 : Colors.black12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            onSelected: (_) => controller.setCategory(catId),
          );
        },
      ),
    );
  }
}
