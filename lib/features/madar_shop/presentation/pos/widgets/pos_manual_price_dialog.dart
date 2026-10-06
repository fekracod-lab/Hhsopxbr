// حوار تعديل السعر اليدوي للبند (MADAR SHOP POS Manual Price Override Dialog)
// Presentation Layer — RBAC Permission Check, Old/New Price Tracking & Audit Reason

import 'package:flutter/material.dart';

import '../../../domain/identity/rbac/shop_permission.dart';
import '../../../domain/pos/entities/cart_item.dart';
import '../../../domain/pos/entities/resolved_product.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../controllers/windows_pos_controller.dart';

class PosManualPriceDialog extends StatefulWidget {
  final WindowsPosController controller;
  final CartItem item;

  const PosManualPriceDialog({
    super.key,
    required this.controller,
    required this.item,
  });

  @override
  State<PosManualPriceDialog> createState() => _PosManualPriceDialogState();
}

class _PosManualPriceDialogState extends State<PosManualPriceDialog> {
  late final TextEditingController _newPriceCtrl;
  final TextEditingController _reasonCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _newPriceCtrl = TextEditingController(text: widget.item.unitPrice.toAmount().toStringAsFixed(0));
  }

  @override
  void dispose() {
    _newPriceCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _submitOverride() {
    // 1. التحقق من صلاحية تعديل السعر
    if (!widget.controller.identityCoordinator.hasPermission(ShopPermission.overrideItemPrice)) {
      setState(() => _error = 'ليس لديك صلاحية لتعديل سعر المنتج يدوياً.');
      return;
    }

    final newPriceVal = double.tryParse(_newPriceCtrl.text.trim()) ?? -1.0;
    if (newPriceVal <= 0) {
      setState(() => _error = 'يجب أن يكون السعر الجديد أكبر من صفر.');
      return;
    }

    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'يرجى كتابة سبب التعديل للتوثيق في سجل التدقيق.');
      return;
    }

    // إعادة إضافة المنتج بالسعر المعدل وسبب التعديل
    final currency = widget.item.unitPrice.currency;
    final manualPrice = Money.fromAmount(newPriceVal, currency);

    // تحديث البند في السلة
    widget.controller.removeItem(widget.item.itemId);
    widget.controller.addProductToCart(
      widget.item.toResolvedProduct(),
      quantity: widget.item.quantity,
      manualOverridePrice: manualPrice,
      overrideReason: reason,
      discount: widget.item.lineDiscount,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1D27) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.price_change_outlined, color: Color(0xFF1E88E5), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'تعديل سعر يدوي: ${widget.item.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Text(
              'السعر الأصلي: ${widget.item.unitPrice.toAmount().toStringAsFixed(0)} د.ع',
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _newPriceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'السعر الجديد المطلوب (د.ع)',
                prefixIcon: const Icon(Icons.attach_money_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reasonCtrl,
              decoration: InputDecoration(
                labelText: 'سبب تعديل السعر (إلزامي للتدقيق)',
                prefixIcon: const Icon(Icons.edit_note_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
        ElevatedButton(
          onPressed: _submitOverride,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('حفظ السعر الجديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

extension CartItemExtension on CartItem {
  ResolvedProduct toResolvedProduct() {
    return ResolvedProduct(
      productId: productId,
      variantId: variantId,
      variantTitle: variantTitle,
      name: name,
      sku: sku,
      barcode: barcode,
      price: unitPrice,
      cost: costPrice,
      stockQuantity: 999.0,
      unitOfMeasure: unitOfMeasure,
      isWeighable: isWeighable,
    );
  }
}

