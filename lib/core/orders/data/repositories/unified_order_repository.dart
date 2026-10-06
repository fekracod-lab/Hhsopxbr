import '../../domain/entities/unified_order.dart';
import '../../domain/entities/inventory_reservation.dart';
import '../../domain/entities/order_creation_result.dart';
import '../../domain/enums/order_enums.dart';
import '../../domain/repositories/i_order_repository.dart';
import '../datasources/unified_order_remote_datasource.dart';

/// تطبيق مستودع إدارة الطلبات الموحد (UnifiedOrderRepository)
class UnifiedOrderRepository implements IOrderRepository {
  final UnifiedOrderRemoteDatasource _remoteDatasource;

  UnifiedOrderRepository({UnifiedOrderRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? UnifiedOrderRemoteDatasource();

  @override
  Future<UnifiedOrder?> getOrder(String orderId) {
    return _remoteDatasource.getOrder(orderId);
  }

  @override
  Future<OrderCreationResult> placeOrderAtomic(UnifiedOrder order) {
    return _remoteDatasource.placeOrderAtomic(order);
  }

  @override
  Future<bool> updateOrderStatus(
    String orderId,
    UnifiedOrderStatus nextStatus, {
    String? driverId,
    String? driverName,
  }) {
    return _remoteDatasource.updateOrderStatus(
      orderId,
      nextStatus,
      driverId: driverId,
      driverName: driverName,
    );
  }

  @override
  Future<bool> cancelOrder(
    String orderId, {
    required String reason,
    required String actorId,
  }) {
    return _remoteDatasource.cancelOrder(
      orderId,
      reason: reason,
      actorId: actorId,
    );
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) {
    return _remoteDatasource.verifyIdempotencyKey(idempotencyKey);
  }

  @override
  Future<List<InventoryReservation>> getOrderReservations(String orderId) {
    return _remoteDatasource.getOrderReservations(orderId);
  }
}
