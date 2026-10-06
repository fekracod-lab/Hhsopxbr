import '../entities/unified_order.dart';
import '../entities/inventory_reservation.dart';
import '../entities/order_creation_result.dart';
import '../enums/order_enums.dart';

/// العقد التجريدي لمستودع إدارة الطلبات الموحد (IOrderRepository)
abstract class IOrderRepository {
  /// جلب بيانات طلب موحد بمعرّف الطلب
  Future<UnifiedOrder?> getOrder(String orderId);

  /// إنشاء طلب ذرياً مع قفل المخزون والمرايا والتسجيل المالي
  Future<OrderCreationResult> placeOrderAtomic(UnifiedOrder order);

  /// تحديث حالة الطلب وفق آلة الحالات المعتمدة
  Future<bool> updateOrderStatus(
    String orderId,
    UnifiedOrderStatus nextStatus, {
    String? driverId,
    String? driverName,
  });

  /// إلغاء الطلب وتحرير الحجوزات وإصدار طلب استرداد مالي إن وجد
  Future<bool> cancelOrder(
    String orderId, {
    required String reason,
    required String actorId,
  });

  /// التحقق من مفتاح عدم التكرار للطلب
  Future<bool> verifyIdempotencyKey(String idempotencyKey);

  /// جلب حجوزات المخزون لطلب معين
  Future<List<InventoryReservation>> getOrderReservations(String orderId);
}
