// شبكة عرض المنتجات بنقطة البيع (MADAR SHOP POS Product Grid)
// Presentation Layer — Responsive Layout for Windows Displays

import 'package:flutter/material.dart';
import '../controllers/windows_pos_controller.dart';
import 'pos_product_card.dart';

class PosProductGrid extends StatelessWidget {
  final WindowsPosController controller;

  const PosProductGrid({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingCatalog) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final products = controller.filteredProducts;

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'لا توجد منتجات مطابقة للبحث أو القسم المحدد',
              style: TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Cairo'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // حساب عدد الأعمدة بناءً على العرض المتاح
        int crossAxisCount = 3;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 900) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return PosProductCard(
              product: products[index],
              controller: controller,
            );
          },
        );
      },
    );
  }
}
