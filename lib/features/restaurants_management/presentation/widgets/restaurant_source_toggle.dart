import 'package:flutter/material.dart';

/// شريط التبديل بين مصدر المطاعم (المجموعة الأساسية / العناصر)
class RestaurantSourceToggle extends StatelessWidget {
  final bool showMainCollection;
  final ValueChanged<bool> onToggle;

  const RestaurantSourceToggle({
    super.key,
    required this.showMainCollection,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.source_rounded, color: Colors.teal.shade600, size: 20),
          const SizedBox(width: 8),
          Text(
            'المصدر:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onToggle(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: showMainCollection ? Colors.teal : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant,
                            size: 18,
                            color: showMainCollection ? Colors.white : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'المطاعم',
                            style: TextStyle(
                              color: showMainCollection ? Colors.white : Colors.grey,
                              fontWeight: showMainCollection ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onToggle(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !showMainCollection ? Colors.teal : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 18,
                            color: !showMainCollection ? Colors.white : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'العناصر',
                            style: TextStyle(
                              color: !showMainCollection ? Colors.white : Colors.grey,
                              fontWeight: !showMainCollection ? FontWeight.bold : FontWeight.normal,
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
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
