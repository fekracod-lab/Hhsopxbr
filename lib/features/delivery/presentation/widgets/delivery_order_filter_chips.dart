// شريط فلاتر تصنيف طلبات التوصيل (Delivery Order Filter Chips Widget)
// Presentation Layer — Pure UI Component

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/delivery_dashboard_models.dart';

class DeliveryOrderFilterChips extends StatelessWidget {
  final DeliveryFilterType selectedFilter;
  final ValueChanged<DeliveryFilterType> onFilterChanged;

  static const Color _primary = Color(0xFF00BFA5);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _textSub = Color(0xFF475569);

  const DeliveryOrderFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'type': DeliveryFilterType.all, 'label': 'كل الطلبات'},
      {'type': DeliveryFilterType.mersal, 'label': 'مرسال وشراء'},
      {'type': DeliveryFilterType.food, 'label': 'وجبات مطاعم'},
      {'type': DeliveryFilterType.store, 'label': 'مسواك متاجر'},
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final filterType = f['type'] as DeliveryFilterType;
          final bool isSelected = selectedFilter == filterType;

          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onFilterChanged(filterType);
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _primary : _cardLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _primary : _borderLight,
                  width: 1.2,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Center(
                child: Text(
                  f['label'] as String,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isSelected ? Colors.white : _textSub,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
