// عقد مستودع أوامر المرتجع للزبائن (MADAR SHOP Return Order Repository Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/return_order.dart';

abstract class IReturnOrderRepository {
  Future<ReturnOrder?> getReturnOrderById({
    required String businessId,
    required String returnOrderId,
  });

  Future<List<ReturnOrder>> getReturnOrdersForSale({
    required String businessId,
    required String saleId,
  });

  Future<List<ReturnOrder>> getReturnOrders({
    required String businessId,
    String? branchId,
    DateTime? from,
    DateTime? to,
  });

  Future<void> saveReturnOrder(ReturnOrder order);
}
