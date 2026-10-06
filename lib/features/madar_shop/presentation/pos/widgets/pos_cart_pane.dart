// لوحة سلة المشتريات لنقطة البيع (MADAR SHOP POS Cart Pane)
// Presentation Layer — Fast Item Modifiers, Held Carts Tabs & Customer Details

import 'package:flutter/material.dart';

import '../../../domain/pos/entities/cart_item.dart';
import '../controllers/windows_pos_controller.dart';
import 'pos_customer_dialog.dart';
import 'pos_discount_dialog.dart';

class PosCartPane extends StatelessWidget {
  final WindowsPosController controller;

  const PosCartPane({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cart = controller.currentCart;
    final items = cart.items;
    final selectedCustomer = controller.selectedCustomer;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF232734) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // شريط السلات المتعددة المعلقة (Cart 1, Cart 2, Cart 3)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1E29) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF232734) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                ...List.generate(WindowsPosController.maxCarts, (i) {
                  final isCurrent = i == controller.activeCartIndex;
                  final slotCart = controller.cartSlots[i].currentCart;
                  final count = slotCart.items.length;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => controller.switchCartSlot(i),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFF1E88E5)
                                : (isDark ? Colors.white10 : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'سلة ${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    color: isCurrent
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                if (count > 0) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isCurrent ? Colors.white.withAlpha(50) : Colors.grey.shade400,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isCurrent ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline_rounded, size: 20),
                  tooltip: 'تعليق الفاتورة الحالية (F4)',
                  onPressed: () => controller.holdCurrentCart(),
                ),
              ],
            ),
          ),

          // شريط العميل (زبون نقدي عام أو تحديد عميل)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13151D) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF232734) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selectedCustomer != null ? Icons.account_circle : Icons.person_outline_rounded,
                  size: 20,
                  color: selectedCustomer != null ? const Color(0xFF1E88E5) : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedCustomer != null
                        ? '${selectedCustomer.name} (رصيد متاح: ${(selectedCustomer.availableCreditMinorUnits / 100).toStringAsFixed(0)} د.ع)'
                        : 'زبون عام (نقدي)',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.person_search_rounded, size: 16),
                  label: Text(
                    selectedCustomer != null ? 'تغيير (F2)' : 'اختيار عميل (F2)',
                    style: const TextStyle(fontSize: 11.5, fontFamily: 'Cairo'),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => PosCustomerDialog(controller: controller),
                    );
                  },
                ),
                if (selectedCustomer != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    tooltip: 'إلغاء اختيار العميل',
                    onPressed: () => controller.setCustomer(null),
                  ),
              ],
            ),
          ),

          // قائمة بنود السلة
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text(
                          'السلة فارغة؛ امسح الباركود أو اضغط على المنتجات للإضافة',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF232734) : const Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildCartItemTile(context, item, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(BuildContext context, CartItem item, bool isDark) {
    final uom = item.unitOfMeasure.isNotEmpty ? item.unitOfMeasure : 'كغم';
    final qtyDisplay = item.isWeighable
        ? '${item.quantity.toStringAsFixed(3)} $uom'
        : item.quantity.toInt().toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // معلومات المنتج والسعر
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${item.unitPrice.toAmount().toStringAsFixed(0)} د.ع',
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    if (!item.lineDiscount.isZero) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'خصم: ${item.discountAmount.toAmount().toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // أزرار زيادة ونقصان الكمية
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
                onPressed: () {
                  final step = item.isWeighable ? 0.250 : 1.0;
                  controller.updateItemQuantity(item.itemId, item.quantity - step);
                },
              ),
              InkWell(
                onTap: () => _showEditQuantityDialog(context, item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    qtyDisplay,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
                onPressed: () {
                  final step = item.isWeighable ? 0.250 : 1.0;
                  controller.updateItemQuantity(item.itemId, item.quantity + step);
                },
              ),
            ],
          ),

          const SizedBox(width: 4),

          // إجمالي البند وزر الحذف
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${item.lineTotal.toAmount().toStringAsFixed(0)} د.ع',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'Cairo'),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 16,
                  onPressed: () => controller.removeItem(item.itemId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditQuantityDialog(BuildContext context, CartItem item) {
    final ctrl = TextEditingController(text: item.quantity.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل كمية: ${item.name}', style: const TextStyle(fontFamily: 'Cairo')),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'الكمية الجديدة (${item.unitOfMeasure.isNotEmpty ? item.unitOfMeasure : 'قطعة'})',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                controller.updateItemQuantity(item.itemId, val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }
}
