import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/cart_item.dart';
import '../../application/pos_controller.dart';
import 'checkout_dialog.dart';
import 'hold_carts_dialog.dart';

/// الشريط الجانبي لسلة مشتريات الكاشير (POS Cart Sidebar)
class ShopCartSidebar extends StatelessWidget {
  final PosController controller;
  final VoidCallback onClear;

  const ShopCartSidebar({
    super.key,
    required this.controller,
    required this.onClear,
  });

  void _showGeneralDiscountDialog(BuildContext context) {
    final textCtrl = TextEditingController(
      text: controller.generalDiscount > 0 ? controller.generalDiscount.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('خصم إضافي على الفاتورة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: textCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'قيمة الخصم (د.ع)',
            suffixText: 'د.ع',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () {
              final d = double.tryParse(textCtrl.text.trim()) ?? 0.0;
              controller.setGeneralDiscount(d);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: ShopColors.primary),
            child: Text('تطبيق', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showHoldCartDialog(BuildContext context) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعليق الفاتورة الحالية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: textCtrl,
          decoration: const InputDecoration(
            labelText: 'اسم الزبون أو رقم الطابور',
            hintText: 'مثال: زبون 1 أو أحمد',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () {
              controller.holdCurrentCart(textCtrl.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: ShopColors.warning),
            child: Text('تعليق', style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = controller.cart;

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: isDark ? ShopColors.darkSurface : ShopColors.lightSurface,
        border: Border(
          right: BorderSide(
            color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder,
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_checkout_rounded, color: ShopColors.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'سلة المبيعات (${controller.totalItemsCount})',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (controller.holdCarts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ActionChip(
                      avatar: const Icon(Icons.pause_circle_rounded, size: 16, color: ShopColors.warning),
                      label: Text('${controller.holdCarts.length}', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: ShopColors.warning.withValues(alpha: 0.15),
                      side: BorderSide(color: ShopColors.warning.withValues(alpha: 0.3)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => HoldCartsDialog(controller: controller),
                        );
                      },
                    ),
                  ),
                if (cart.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, color: ShopColors.danger, size: 22),
                    tooltip: 'مسح السلة بالكامل',
                    onPressed: onClear,
                  ),
              ],
            ),
          ),

          // ── Items List ──
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_shopping_cart_rounded, size: 54, color: Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'السلة فارغة هسة',
                          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'امسح الباركود أو انقر على المنتجات لإضافتها',
                          style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: cart.length,
                    separatorBuilder: (_, _i) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) => _buildCartItemTile(context, cart[idx], isDark),
                  ),
          ),

          // ── Financial Summary & Checkout ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? ShopColors.darkCard : ShopColors.lightBg,
              border: Border(
                top: BorderSide(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('المجموع الفرعي:', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                    Text('${controller.subtotal.toStringAsFixed(0)} د.ع', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => _showGeneralDiscountDialog(context),
                      child: Row(
                        children: [
                          const Icon(Icons.discount_outlined, size: 14, color: ShopColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            controller.generalDiscount > 0
                                ? 'الخصم (${controller.generalDiscount.toStringAsFixed(0)} د.ع)'
                                : 'إضافة خصم +',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: ShopColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '- ${controller.totalDiscounts.toStringAsFixed(0)} د.ع',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: controller.totalDiscounts > 0 ? ShopColors.danger : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الصافي النهائي:',
                      style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${controller.netTotal.toStringAsFixed(0)} د.ع',
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: cart.isEmpty ? null : () => _showHoldCartDialog(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ShopColors.warning,
                          side: const BorderSide(color: ShopColors.warning),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('تعليق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: cart.isEmpty
                            ? null
                            : () {
                                showDialog(
                                  context: context,
                                  builder: (_) => CheckoutDialog(
                                    controller: controller,
                                    onSuccess: () {},
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ShopColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                        label: Text(
                          'دفع وطباعة',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(BuildContext context, PosCartItem item, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? ShopColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.product.name,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                onPressed: () => controller.removeFromCart(item.product.id),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.unitPrice.toStringAsFixed(0)} د.ع',
                style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
              ),
              // Quantity Stepper
              Container(
                decoration: BoxDecoration(
                  color: isDark ? ShopColors.darkSurface : ShopColors.lightBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stepperBtn(Icons.remove_rounded, () {
                      controller.updateQuantity(item.product.id, item.quantity - 1);
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${item.quantity}',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    _stepperBtn(Icons.add_rounded, () {
                      controller.updateQuantity(item.product.id, item.quantity + 1);
                    }),
                  ],
                ),
              ),
              Text(
                '${item.totalPrice.toStringAsFixed(0)} د.ع',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: ShopColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16),
      ),
    );
  }
}
