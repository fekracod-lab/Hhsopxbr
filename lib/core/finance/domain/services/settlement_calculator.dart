import '../entities/settlement_entity.dart';
import '../enums/financial_enums.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// حاسبة التسوية المالية المركزية الحتمية (Deterministic Settlement Calculator)
class SettlementCalculator {
  const SettlementCalculator();

  /// العمولة الثابتة لمنصة مدار على طلبات التوصيل (500 د.ع)
  static const int defaultDeliveryPlatformCommission = 500;

  /// النسبة المئوية الافتراضية لعمولة رحلات التكسي (10%)
  static const double defaultTaxiCommissionRate = 0.10;

  /// احتساب تسوية طلب توصيل (Food أو Store أو Mersal)
  static SettlementEntity calculateDeliverySettlement({
    required String orderId,
    required String orderSource,
    required String customerId,
    String? driverId,
    String? merchantId,
    required int subtotal,
    required int deliveryFee,
    int? customPlatformCommission,
    required String paymentMethod,
    required String idempotencyKey,
  }) {
    if (subtotal < 0 || deliveryFee < 0) {
      throw const SecurityViolationException(
        'المبالغ المالية للطلب لا يمكن أن تكون سالبة',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    final grossOrderAmount = subtotal + deliveryFee;
    if (grossOrderAmount <= 0) {
      throw const SecurityViolationException(
        'إجمالي مبلغ الطلب يجب أن يكون أكبر من الصفر',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    // عمولة المنصة
    final commission = customPlatformCommission ??
        (deliveryFee > defaultDeliveryPlatformCommission
            ? defaultDeliveryPlatformCommission
            : 0);

    // صافي ربح الكابتن = أجور التوصيل - عمولة المنصة
    final driverEarnings = deliveryFee >= commission ? deliveryFee - commission : 0;

    // مستحقات التاجر = قيمة المنتجات (المتبقي من الحسبة)
    final merchantAmount = grossOrderAmount - driverEarnings - commission;

    return SettlementEntity(
      id: 'stl-$orderId',
      orderId: orderId,
      orderSource: orderSource,
      customerId: customerId,
      driverId: driverId,
      merchantId: merchantId,
      grossOrderAmount: grossOrderAmount,
      deliveryFee: deliveryFee,
      merchantAmount: merchantAmount,
      driverAmount: driverEarnings,
      platformCommission: commission,
      paymentMethod: paymentMethod,
      status: SettlementStatus.pending,
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now(),
    );
  }

  /// احتساب تسوية رحلة تكسي (Taxi Ride)
  static SettlementEntity calculateTaxiSettlement({
    required String rideId,
    required String customerId,
    required String driverId,
    required int grossFare,
    double commissionRate = defaultTaxiCommissionRate,
    required String paymentMethod,
    required String idempotencyKey,
  }) {
    if (grossFare <= 0) {
      throw const SecurityViolationException(
        'أجرة رحلة التكسي يجب أن تكون أكبر من الصفر',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    final platformCommission = (grossFare * commissionRate).round();
    final driverAmount = grossFare - platformCommission;

    return SettlementEntity(
      id: 'stl-$rideId',
      orderId: rideId,
      orderSource: 'taxi',
      customerId: customerId,
      driverId: driverId,
      grossOrderAmount: grossFare,
      merchantAmount: 0,
      driverAmount: driverAmount,
      platformCommission: platformCommission,
      paymentMethod: paymentMethod,
      status: SettlementStatus.pending,
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now(),
    );
  }
}
