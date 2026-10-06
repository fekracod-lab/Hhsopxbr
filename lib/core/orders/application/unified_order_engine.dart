import 'dart:math';
import '../domain/entities/unified_order.dart';
import '../domain/entities/order_creation_result.dart';
import '../domain/enums/order_enums.dart';
import '../domain/repositories/i_order_repository.dart';
import '../domain/services/order_state_machine.dart';
import '../data/repositories/unified_order_repository.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// المحرك المركزي لإدارة وتوحيد دورة حياة الطلبات في مدار (Unified Order Engine)
class UnifiedOrderEngine {
  static UnifiedOrderEngine? _instance;
  static UnifiedOrderEngine get instance => _instance ??= UnifiedOrderEngine();

  final IOrderRepository _repository;

  UnifiedOrderEngine({IOrderRepository? repository})
      : _repository = repository ?? UnifiedOrderRepository();

  /// توليد مفتاح عدم تكرار فريد للطلب
  String generateOrderIdempotencyKey({String prefix = 'ord'}) {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$hex';
  }

  /// إنشاء طلب موحد ذرياً مع قفل المخزون وحماية عدم التكرار
  Future<OrderCreationResult> createOrder({required UnifiedOrder order}) async {
    final effectiveOrder = order.idempotencyKey.trim().isEmpty
        ? order.copyWith(idempotencyKey: generateOrderIdempotencyKey())
        : order;

    return await _repository.placeOrderAtomic(effectiveOrder);
  }

  /// ترقية وتحديث حالة الطلب عبر آلة الحالات
  Future<bool> advanceOrderStatus({
    required String orderId,
    required UnifiedOrderStatus nextStatus,
    String? driverId,
    String? driverName,
  }) async {
    return await _repository.updateOrderStatus(
      orderId,
      nextStatus,
      driverId: driverId,
      driverName: driverName,
    );
  }

  /// إلغاء الطلب وتحرير المخزون
  Future<bool> cancelOrder({
    required String orderId,
    required String reason,
    required String actorId,
  }) async {
    final order = await _repository.getOrder(orderId);
    if (order != null && !OrderStateMachine.canCancelOrder(order.status)) {
      throw SecurityViolationException(
        'لا يمكن إلغاء الطلب في حالته المتقدمة الحالية (${order.status.key})',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'status',
      );
    }

    return await _repository.cancelOrder(
      orderId,
      reason: reason,
      actorId: actorId,
    );
  }
}
