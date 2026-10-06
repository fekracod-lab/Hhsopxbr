import '../entities/inventory_reservation.dart';
import '../enums/order_enums.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// خدمة حجز المخزون الذري ومنع البيع الزائد (Inventory Reservation Invariant Service)
class InventoryReservationService {
  const InventoryReservationService();

  /// التحقق من كفاية المخزون وحساب المخزون المتبقي
  static int computeRemainingStock({
    required String productId,
    required int availableStock,
    required int requestedQuantity,
  }) {
    if (requestedQuantity <= 0) {
      throw SecurityViolationException(
        'الكمية المطلوبة للمنتج ($productId) يجب أن تكون أكبر من الصفر: $requestedQuantity',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'quantity',
      );
    }

    if (availableStock < requestedQuantity) {
      throw SecurityViolationException(
        'المخزون المتوفر للمنتج ($productId) غير كافٍ: المتاح ($availableStock) < المطلوب ($requestedQuantity)',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'stock',
      );
    }

    final remaining = availableStock - requestedQuantity;
    if (remaining < 0) {
      throw SecurityViolationException(
        'انتهاك أمني: لا يمكن أن يصبح المخزون سالباً للمنتج ($productId)',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'stock',
      );
    }

    return remaining;
  }

  /// إنشاء كائن حجز المخزون
  static InventoryReservation createReservation({
    required String orderId,
    required String storeId,
    required String productId,
    required int quantity,
    Duration expirationDuration = const Duration(minutes: 15),
  }) {
    final now = DateTime.now();
    return InventoryReservation(
      reservationId: 'res-$orderId-$productId',
      orderId: orderId,
      storeId: storeId,
      productId: productId,
      quantity: quantity,
      status: ReservationStatus.reserved,
      createdAt: now,
      expiresAt: now.add(expirationDuration),
    );
  }
}
