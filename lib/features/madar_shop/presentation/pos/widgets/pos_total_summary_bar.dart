// شريط الملخص المالي وأزرار الدفع لنقطة البيع (MADAR SHOP POS Total Summary Bar)
// Presentation Layer — Large Grand Total, Financial Breakdown & Action Shortcuts

import 'package:flutter/material.dart';
import '../controllers/windows_pos_controller.dart';
import 'pos_discount_dialog.dart';
import 'pos_payment_dialog.dart';
import 'pos_returns_dialog.dart';

class PosTotalSummaryBar extends StatelessWidget {
  final WindowsPosController controller;

  const PosTotalSummaryBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cart = controller.currentCart;
    final totals = controller.totals;
    final subtotal = totals.subtotal.toAmount();
    final discount = totals.discountTotal.toAmount();
    final tax = totals.taxTotal.toAmount();
    final grandTotal = totals.grandTotal.toAmount();
    final isCartEmpty = cart.isEmpty;

    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151D) : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF232734) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 1400;

          return Row(
            children: [
              // تفاصيل المجموع الفرعي والخصومات والضريبة
              Flexible(
                flex: 4,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'المجموع الفرعي: ',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Cairo'),
                          ),
                          Text(
                            '${subtotal.toStringAsFixed(0)} د.ع',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => PosDiscountDialog(controller: controller),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'الخصم (F3): ',
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Cairo'),
                                ),
                                Text(
                                  '-${discount.toStringAsFixed(0)} د.ع',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: discount > 0 ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit, size: 14, color: Color(0xFF1E88E5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'الضريبة: ',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Cairo'),
                          ),
                          Text(
                            '${tax.toStringAsFixed(0)} د.ع',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'عدد المواد: ${cart.items.length}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),
              Container(width: 1.5, height: 44, color: Colors.grey.withAlpha(50)),
              const SizedBox(width: 12),

              // الإجمالي النهائي (أكبر وأبرز عنصر بصري في الشاشة)
              Flexible(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المجموع النهائي المطلوب',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                      Text(
                        '${grandTotal.toStringAsFixed(0)} د.ع',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E88E5),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // أزرار العمليات المساعدة
              OutlinedButton.icon(
                icon: const Icon(Icons.assignment_return_outlined, size: 18),
                label: const Text('مرتجع (F8)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => PosReturnsDialog(controller: controller),
                  );
                },
              ),
              const SizedBox(width: 8),

              // زر فاتورة جديدة
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('جديدة (F9)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  if (cart.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('تفريغ السلة', style: TextStyle(fontFamily: 'Cairo')),
                        content: const Text('هل أنت متأكد من رغبتك في تفريغ السلة الحالية وبدء فاتورة جديدة؟', style: TextStyle(fontFamily: 'Cairo')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () {
                              controller.clearCurrentCart();
                              Navigator.pop(ctx);
                            },
                            child: const Text('نعم، تفريغ السلة', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  } else {
                    controller.clearCurrentCart();
                  }
                },
              ),
              const SizedBox(width: 10),

              // زر الدفع الرئيسي الكبير
              SizedBox(
                height: 52,
                width: isCompact ? 150 : 180,
                child: ElevatedButton.icon(
                  onPressed: isCartEmpty || controller.isProcessingPayment
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (_) => PosPaymentDialog(controller: controller),
                          );
                        },
                  icon: const Icon(Icons.payment_rounded, size: 22),
                  label: const Text(
                    'دفع (F5)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
