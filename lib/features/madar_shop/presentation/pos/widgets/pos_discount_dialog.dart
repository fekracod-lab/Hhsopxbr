// حوار تطبيق الخصومات لنقطة البيع (MADAR SHOP POS Discount Dialog)
// Presentation Layer — Item/Cart Discounts, RBAC Check & Input Boundaries

import 'package:flutter/material.dart';

import '../../../domain/identity/rbac/shop_permission.dart';
import '../../../domain/pos/enums/discount_type.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/discount.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../controllers/windows_pos_controller.dart';

class PosDiscountDialog extends StatefulWidget {
  final WindowsPosController controller;

  const PosDiscountDialog({
    super.key,
    required this.controller,
  });

  @override
  State<PosDiscountDialog> createState() => _PosDiscountDialogState();
}

class _PosDiscountDialogState extends State<PosDiscountDialog> {
  DiscountType _type = DiscountType.fixed;
  final TextEditingController _valCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _valCtrl.dispose();
    super.dispose();
  }

  void _applyDiscount() {
    final raw = double.tryParse(_valCtrl.text.trim()) ?? 0.0;
    if (raw < 0) {
      setState(() => _error = 'لا يمكن أن تكون قيمة الخصم سالبة.');
      return;
    }

    final subtotal = widget.controller.totals.subtotal.toAmount();

    if (_type == DiscountType.percentage) {
      if (raw > 100) {
        setState(() => _error = 'نسبة الخصم لا يمكن أن تتجاوز 100%.');
        return;
      }
    } else {
      if (raw > subtotal) {
        setState(() => _error = 'قيمة الخصم لا يمكن أن تتجاوز المجموع الفرعي.');
        return;
      }
    }

    // التحقق من الصلاحية
    if (!widget.controller.identityCoordinator.hasPermission(ShopPermission.applyCartDiscount)) {
      setState(() => _error = 'ليس لديك صلاحية لتطبيق خصم على الفاتورة.');
      return;
    }

    final discount = Discount(
      type: _type,
      value: raw,
    );

    widget.controller.applyCartDiscount(discount);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1D27) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.local_offer_outlined, color: Color(0xFF1E88E5), size: 22),
          SizedBox(width: 10),
          Text('تطبيق خصم على الفاتورة (F3)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontFamily: 'Cairo')),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<DiscountType>(
                    segments: const [
                      ButtonSegment(value: DiscountType.fixed, label: Text('مبلغ ثابت', style: TextStyle(fontFamily: 'Cairo'))),
                      ButtonSegment(value: DiscountType.percentage, label: Text('نسبة %', style: TextStyle(fontFamily: 'Cairo'))),
                    ],
                    selected: {_type},
                    onSelectionChanged: (set) => setState(() => _type = set.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _valCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: _type == DiscountType.percentage ? 'النسبة المئوية (%)' : 'مبلغ الخصم (د.ع)',
                prefixIcon: Icon(_type == DiscountType.percentage ? Icons.percent : Icons.attach_money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
        ElevatedButton(
          onPressed: _applyDiscount,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('تطبيق الخصم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
