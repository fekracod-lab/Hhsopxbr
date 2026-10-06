// واجهة مستودع أوامر الشراء (MADAR SHOP Purchase Order Repository Contract)
// Pure Dart — Zero UI Dependencies

import '../entities/purchase_order.dart';
import '../enums/purchase_order_status.dart';

abstract class IPurchaseOrderRepository {
  Future<PurchaseOrder?> getPurchaseOrderById({
    required String businessId,
    required String purchaseOrderId,
  });

  Future<PurchaseOrder?> getPurchaseOrderByNumber({
    required String businessId,
    required String orderNumber,
  });

  Future<List<PurchaseOrder>> getPurchaseOrders({
    required String businessId,
    String? branchId,
    String? supplierId,
    PurchaseOrderStatus? status,
  });

  Future<void> savePurchaseOrder(PurchaseOrder purchaseOrder);
}
