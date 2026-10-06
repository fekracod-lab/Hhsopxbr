// بطاقة المنتج في شبكة نقطة البيع (MADAR SHOP POS Product Card)
// Presentation Layer — Fast Click-to-Cart, Stock & Weighable Badges

import 'package:flutter/material.dart';

import '../../../domain/pos/entities/resolved_product.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/products/entities/shop_product.dart';
import '../controllers/windows_pos_controller.dart';

class PosProductCard extends StatelessWidget {
  final ShopProduct product;
  final WindowsPosController controller;

  const PosProductCard({
    super.key,
    required this.product,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasVariants = product.variants.isNotEmpty;
    final isOutOfStock = product.stockQuantity <= 0;
    final isLowStock = !isOutOfStock && product.stockQuantity <= 5;
    final isWeighable = product.unitOfMeasure.toLowerCase() == 'kg' ||
        product.unitOfMeasure.toLowerCase() == 'كغم';

    return InkWell(
      onTap: isOutOfStock
          ? null
          : () {
              if (hasVariants) {
                _showVariantSelector(context);
              } else {
                final resolved = ResolvedProduct(
                  productId: product.productId,
                  name: product.name,
                  sku: product.sku,
                  barcode: product.barcode,
                  price: Money.fromAmount(product.sellingPrice, Currency.iqd),
                  cost: Money.fromAmount(product.costPrice, Currency.iqd),
                  stockQuantity: product.stockQuantity,
                  unitOfMeasure: product.unitOfMeasure,
                  isWeighable: isWeighable,
                );
                controller.addProductToCart(resolved, quantity: 1.0);
              }
            },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1E29) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF262B3A) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شارات الحالة (مخزون / متغيرات / ميزان)
            Row(
              children: [
                if (hasVariants) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'أصناف',
                      style: TextStyle(color: Colors.purple, fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (isWeighable) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'وزن',
                      style: TextStyle(color: Colors.teal, fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? Colors.red.withAlpha(20)
                        : (isLowStock ? Colors.orange.withAlpha(20) : Colors.green.withAlpha(20)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOutOfStock
                        ? 'نفذ'
                        : (isLowStock ? 'متبقي: ${product.stockQuantity.toInt()}' : 'متوفر'),
                    style: TextStyle(
                      color: isOutOfStock
                          ? Colors.red
                          : (isLowStock ? Colors.orange : Colors.green),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // اسم المنتج
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                fontFamily: 'Cairo',
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),

            // رمز الـ SKU
            Text(
              product.sku,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
            const SizedBox(height: 6),

            // السعر
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${product.sellingPrice.toStringAsFixed(0)} د.ع',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF1E88E5),
                    fontFamily: 'Cairo',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 16, color: Color(0xFF1E88E5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVariantSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'اختر صنف: ${product.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 14),
              ...product.variants.map((v) {
                return ListTile(
                  title: Text(v.title, style: const TextStyle(fontFamily: 'Cairo')),
                  subtitle: Text('SKU: ${v.sku}'),
                  trailing: Text(
                    '${v.sellingPrice.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E88E5)),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    final resolved = ResolvedProduct(
                      productId: product.productId,
                      variantId: v.variantId,
                      variantTitle: v.title,
                      name: '${product.name} - ${v.title}',
                      sku: v.sku,
                      barcode: v.barcode ?? product.barcode,
                      price: Money.fromAmount(v.sellingPrice, Currency.iqd),
                      cost: Money.fromAmount(v.costPrice, Currency.iqd),
                      stockQuantity: v.stockQuantity,
                      unitOfMeasure: product.unitOfMeasure,
                    );
                    controller.addProductToCart(resolved, quantity: 1.0);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
