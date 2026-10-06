// مستودع أوامر الشراء في الذاكرة (MADAR SHOP Memory Purchase Order Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/purchasing/entities/purchase_order.dart';
import '../../../domain/purchasing/enums/purchase_order_status.dart';
import '../../../domain/purchasing/repositories/i_purchase_order_repository.dart';

class MemoryPurchaseOrderRepository implements IPurchaseOrderRepository {
  final Map<String, PurchaseOrder> _orders = {};

  String _key(String businessId, String id) => '$businessId:$id';

  @override
  Future<PurchaseOrder?> getPurchaseOrderById({
    required String businessId,
    required String purchaseOrderId,
  }) async {
    return _orders[_key(businessId, purchaseOrderId)];
  }

  @override
  Future<PurchaseOrder?> getPurchaseOrderByNumber({
    required String businessId,
    required String orderNumber,
  }) async {
    try {
      return _orders.values.firstWhere(
        (o) => o.businessId == businessId && o.orderNumber == orderNumber,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<PurchaseOrder>> getPurchaseOrders({
    required String businessId,
    String? branchId,
    String? supplierId,
    PurchaseOrderStatus? status,
  }) async {
    return _orders.values.where((o) {
      if (o.businessId != businessId) return false;
      if (branchId != null && o.branchId != branchId) return false;
      if (supplierId != null && o.supplierId != supplierId) return false;
      if (status != null && o.status != status) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> savePurchaseOrder(PurchaseOrder purchaseOrder) async {
    _orders[_key(purchaseOrder.businessId, purchaseOrder.id)] = purchaseOrder;
  }

  void clear() {
    _orders.clear();
  }
}
