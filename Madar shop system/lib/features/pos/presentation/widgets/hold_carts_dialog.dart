import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/hold_cart.dart';
import '../../application/pos_controller.dart';

/// نافذة إدارة واسترجاع السلات المعلقة في الطابور (Hold Carts Dialog)
class HoldCartsDialog extends StatelessWidget {
  final PosController controller;

  const HoldCartsDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final holdCarts = controller.holdCarts;

    return Dialog(
      backgroundColor: isDark ? ShopColors.darkSurface : ShopColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ShopColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.pause_circle_filled_rounded, color: ShopColors.warning, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'الفواتير المعلقة في الطابور (${holdCarts.length})',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            if (holdCarts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    Text(
                      'لا توجد فواتير معلقة حالياً',
                      style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: holdCarts.length,
                  separatorBuilder: (_, _i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final item = holdCarts[i];
                    return _buildHoldCard(context, item, isDark);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldCard(BuildContext context, HoldCart item, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ShopColors.darkCard : ShopColors.lightBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.customerName,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.itemCount} مواد • الإجمالي: ${item.total.toStringAsFixed(0)} د.ع',
                  style: GoogleFonts.cairo(color: ShopColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              controller.resumeHoldCart(item);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: Text('استرجاع', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ShopColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: ShopColors.danger, size: 20),
            onPressed: () => controller.deleteHoldCart(item.id),
          ),
        ],
      ),
    );
  }
}
