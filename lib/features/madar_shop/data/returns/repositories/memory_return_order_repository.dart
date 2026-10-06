// مستودع أوامر المرتجع في الذاكرة (MADAR SHOP Memory Return Order Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/returns/entities/return_order.dart';
import '../../../domain/returns/repositories/i_return_order_repository.dart';

class MemoryReturnOrderRepository implements IReturnOrderRepository {
  final Map<String, ReturnOrder> _store = {};

  @override
  Future<ReturnOrder?> getReturnOrderById({
    required String businessId,
    required String returnOrderId,
  }) async {
    final order = _store[returnOrderId];
    if (order != null && order.businessId == businessId) {
      return order;
    }
    return null;
  }

  @override
  Future<List<ReturnOrder>> getReturnOrdersForSale({
    required String businessId,
    required String saleId,
  }) async {
    return _store.values
        .where((o) => o.businessId == businessId && o.originalSaleId == saleId)
        .toList();
  }

  @override
  Future<List<ReturnOrder>> getReturnOrders({
    required String businessId,
    String? branchId,
    DateTime? from,
    DateTime? to,
  }) async {
    return _store.values.where((o) {
      if (o.businessId != businessId) return false;
      if (branchId != null && o.branchId != branchId) return false;
      if (from != null && o.createdAt.isBefore(from)) return false;
      if (to != null && o.createdAt.isAfter(to)) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> saveReturnOrder(ReturnOrder order) async {
    _store[order.id] = order;
  }

  void clear() => _store.clear();
}
