// قواعد وضوابط عمليات المخزون وحساب الأرصدة (MADAR SHOP Stock Rules)
// Pure Dart — Zero UI Dependencies

import '../entities/inventory_item.dart';
import '../enums/negative_stock_policy.dart';
import '../value_objects/stock_quantity.dart';

class StockRuleResult {
  final bool isAllowed;
  final String? rejectionReason;

  const StockRuleResult.success()
      : isAllowed = true,
        rejectionReason = null;

  const StockRuleResult.failure(this.rejectionReason) : isAllowed = false;
}

class StockRules {
  const StockRules._();

  /// التحقق من إمكانية صرف أو بيع كمية معينة من المخزون
  static StockRuleResult validateConsumption({
    required InventoryItem item,
    required StockQuantity requestedQuantity,
  }) {
    if (requestedQuantity <= StockQuantity.zero(item.unit)) {
      return const StockRuleResult.failure('كمية الصرف المطلوبة يجب أن تكون أكبر من صفر.');
    }

    final projectedAvailable = item.available - requestedQuantity;

    if (projectedAvailable.isNegative) {
      if (item.negativeStockPolicy == NegativeStockPolicy.block) {
        return StockRuleResult.failure(
          'الرصيد المتاح غير كافٍ للصرف. المتاح: ${item.available}، المطلوب: $requestedQuantity.',
        );
      }
    }

    return const StockRuleResult.success();
  }

  /// التحقق من إمكانية حجز كمية من المخزون
  static StockRuleResult validateReservation({
    required InventoryItem item,
    required StockQuantity reservationQuantity,
  }) {
    if (reservationQuantity <= StockQuantity.zero(item.unit)) {
      return const StockRuleResult.failure('كمية الحجز المطلوبة يجب أن تكون أكبر من صفر.');
    }

    if (reservationQuantity > item.available) {
      if (item.negativeStockPolicy == NegativeStockPolicy.block) {
        return StockRuleResult.failure(
          'لا يمكن حجز كمية تتجاوز الرصيد المتاح حالياً. المتاح: ${item.available}، المطلوب حجزها: $reservationQuantity.',
        );
      }
    }

    return const StockRuleResult.success();
  }

  /// التحقق من إمكانية فك حجز كمية
  static StockRuleResult validateReleaseReservation({
    required InventoryItem item,
    required StockQuantity releaseQuantity,
  }) {
    if (releaseQuantity <= StockQuantity.zero(item.unit)) {
      return const StockRuleResult.failure('الكمية المراد فك حجزها يجب أن تكون أكبر من صفر.');
    }

    if (releaseQuantity > item.reserved) {
      return StockRuleResult.failure(
        'الكمية المراد فك حجزها ($releaseQuantity) تتجاوز إجمالي المحجوز الفعلي (${item.reserved}).',
      );
    }

    return const StockRuleResult.success();
  }
}
