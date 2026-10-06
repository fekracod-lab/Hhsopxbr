// حوار نجاح المعاملة وعرض الإيصال (MADAR SHOP POS Receipt Success Dialog)
// Presentation Layer — Honest Sync Status, Receipt Summary & Reprint

import 'package:flutter/material.dart';

import '../../../application/pos/commands/checkout_result.dart';
import '../controllers/windows_pos_controller.dart';

class PosReceiptSuccessDialog extends StatelessWidget {
  final WindowsPosController controller;
  final CheckoutResult result;
  final bool isOfflineSale;

  const PosReceiptSuccessDialog({
    super.key,
    required this.controller,
    required this.result,
    required this.isOfflineSale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sale = result.sale;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1D27) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 28),
          ),
          const SizedBox(width: 12),
          const Text(
            'تم إتمام البيع بنجاح',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Cairo'),
          ),
          const Spacer(),
          // شارة المزامنة الصادقة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOfflineSale ? Colors.orange.withAlpha(25) : Colors.green.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOfflineSale ? Colors.orange.withAlpha(80) : Colors.green.withAlpha(80),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOfflineSale ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                  size: 14,
                  color: isOfflineSale ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  isOfflineSale ? 'محفوظ محلياً (PENDING SYNC)' : 'متزامن مع السحابة (SYNCED)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: isOfflineSale ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('رقم الفاتورة:', sale.saleNumber, isBold: true),
                  const SizedBox(height: 8),
                  _buildSummaryRow('المبلغ الإجمالي:', '${sale.grandTotal.toAmount().toStringAsFixed(0)} د.ع', isHighlight: true),
                  const SizedBox(height: 8),
                  _buildSummaryRow('المدفوع:', '${sale.paidTotal.toAmount().toStringAsFixed(0)} د.ع'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('المتبقي للزبون:', '${sale.changeTotal.toAmount().toStringAsFixed(0)} د.ع'),
                  if (sale.customerName != null) ...[
                    const SizedBox(height: 8),
                    _buildSummaryRow('العميل:', sale.customerName!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'تم حفظ المعاملة في السجلات الرسمية؛ يمكنك إعادة طباعة الفاتورة أو البدء بعملية جديدة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey, fontFamily: 'Cairo'),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('إعادة الطباعة', style: TextStyle(fontFamily: 'Cairo')),
          onPressed: () {
            controller.reprintSaleReceipt(sale: sale, reason: 'إعادة طباعة يدوية من الكاشير');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم إرسال أمر إعادة الطباعة إلى الطابعة', style: TextStyle(fontFamily: 'Cairo'))),
            );
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
          label: const Text('فاتورة جديدة (Enter)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo')),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 13.5,
            fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.normal,
            color: isHighlight ? const Color(0xFF1E88E5) : null,
          ),
        ),
      ],
    );
  }
}
