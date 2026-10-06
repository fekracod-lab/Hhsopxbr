import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// خدمة خصم المخزون التلقائي عند إتمام بيع وجبة من الكاشير
/// تربط بين وجبات المنيو ومكونات المخزون وتخصم الكميات تلقائياً
class InventoryDeductionService {
  static final InventoryDeductionService instance =
      InventoryDeductionService._internal();
  InventoryDeductionService._internal();

  /// خصم مكونات المخزون بناءً على وجبات الطلب المكتمل
  /// يتم استدعاؤها بعد كل عملية بيع ناجحة في PosProvider.checkout()
  Future<void> deductForOrder({
    required String restaurantId,
    required List<Map<String, dynamic>> orderItems,
  }) async {
    if (restaurantId.isEmpty || orderItems.isEmpty) return;

    try {
      final inventoryRef = FirebaseFirestore.instance
          .collection('merchant_inventory')
          .doc(restaurantId)
          .collection('items');

      final recipesRef = FirebaseFirestore.instance
          .collection('merchant_recipes')
          .doc(restaurantId)
          .collection('recipes');

      final batch = FirebaseFirestore.instance.batch();
      bool hasBatchOps = false;

      for (final item in orderItems) {
        final mealId = (item['mealId'] ?? item['id'] ?? '').toString();
        final qty = (item['quantity'] ?? 1) as int;
        if (mealId.isEmpty) continue;

        // جلب وصفة الوجبة (المكونات المرتبطة) من merchant_recipes أو مباشرة من بيانات الوجبة
        List<dynamic> ingredients = [];
        final recipeDoc = await recipesRef.doc(mealId).get();
        if (recipeDoc.exists) {
          ingredients = (recipeDoc.data()?['ingredients'] as List<dynamic>?) ?? [];
        } else {
          final prodDoc = await FirebaseFirestore.instance
              .collection('merchant_products')
              .doc(restaurantId)
              .collection('products')
              .doc(mealId)
              .get();
          if (prodDoc.exists) {
            ingredients = (prodDoc.data()?['linkedIngredients'] as List<dynamic>?) ??
                (prodDoc.data()?['recipe'] as List<dynamic>?) ?? [];
          }
        }
        if (ingredients.isEmpty) continue;

        for (final ingredient in ingredients) {
          final ingMap = ingredient as Map<String, dynamic>? ?? {};
          final inventoryItemId =
              (ingMap['inventoryItemId'] ?? '').toString();
          final usagePerUnit =
              (ingMap['usagePerUnit'] ?? 0).toDouble();

          if (inventoryItemId.isEmpty || usagePerUnit <= 0) continue;

          final totalDeduction = usagePerUnit * qty;

          // خصم الكمية من المخزون
          batch.update(
            inventoryRef.doc(inventoryItemId),
            {
              'currentQuantity': FieldValue.increment(-totalDeduction),
              'lastDeductedAt': FieldValue.serverTimestamp(),
            },
          );
          hasBatchOps = true;
        }
      }

      if (hasBatchOps) {
        await batch.commit();
        debugPrint(
            '[InventoryDeduction] Successfully deducted inventory for ${orderItems.length} items');
      }
    } catch (e) {
      debugPrint('[InventoryDeduction] Error deducting inventory: $e');
    }
  }

  /// فحص مستويات المخزون وتوليد إشعارات للمواد التي وصلت للحد الأدنى
  Future<void> checkLowStockAlerts({required String restaurantId}) async {
    if (restaurantId.isEmpty) return;

    try {
      final inventorySnap = await FirebaseFirestore.instance
          .collection('merchant_inventory')
          .doc(restaurantId)
          .collection('items')
          .get();

      final List<Map<String, dynamic>> lowStockItems = [];

      for (final doc in inventorySnap.docs) {
        final data = doc.data();
        final currentQty =
            (data['currentQuantity'] ?? data['quantity'] ?? 0).toDouble();
        final minAlert = (data['minAlertLevel'] ?? 5).toDouble();
        final name = (data['name'] ?? 'مادة').toString();

        if (currentQty <= minAlert) {
          lowStockItems.add({
            'itemId': doc.id,
            'name': name,
            'currentQuantity': currentQty,
            'minAlertLevel': minAlert,
            'unit': (data['unit'] ?? 'كغم').toString(),
          });
        }
      }

      if (lowStockItems.isEmpty) return;

      // توليد إشعارات للمواد المنخفضة
      final notifRef = FirebaseFirestore.instance
          .collection('merchant_notifications')
          .doc(restaurantId)
          .collection('notifications');

      final batch = FirebaseFirestore.instance.batch();

      for (final item in lowStockItems) {
        // تجنب الإشعارات المكررة: فحص آخر إشعار لنفس المادة خلال آخر 4 ساعات
        final recentCheck = await notifRef
            .where('type', isEqualTo: 'low_stock')
            .where('relatedId', isEqualTo: item['itemId'])
            .where('createdAt',
                isGreaterThan: Timestamp.fromDate(
                    DateTime.now().subtract(const Duration(hours: 4))))
            .limit(1)
            .get();

        if (recentCheck.docs.isNotEmpty) continue;

        final notifDoc = notifRef.doc();
        batch.set(notifDoc, {
          'type': 'low_stock',
          'title': '⚠️ تنبيه نفاد مخزون',
          'body':
              '${item['name']} وصل إلى ${item['currentQuantity']} ${item['unit']} (الحد الأدنى: ${item['minAlertLevel']} ${item['unit']})',
          'relatedId': item['itemId'],
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'priority': 'high',
        });
      }

      await batch.commit();
      debugPrint(
          '[InventoryDeduction] Generated ${lowStockItems.length} low-stock alerts');
    } catch (e) {
      debugPrint('[InventoryDeduction] Error checking low stock: $e');
    }
  }

  /// الدالة المتكاملة: خصم المخزون + فحص التنبيهات
  Future<void> processOrderDeduction({
    required String restaurantId,
    required List<Map<String, dynamic>> orderItems,
  }) async {
    await deductForOrder(
      restaurantId: restaurantId,
      orderItems: orderItems,
    );
    // فحص مستويات المخزون بعد الخصم
    await checkLowStockAlerts(restaurantId: restaurantId);
  }
}
