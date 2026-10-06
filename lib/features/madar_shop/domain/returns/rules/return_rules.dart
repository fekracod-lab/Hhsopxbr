// قواعد وأحكام الإرجاع والمطابقة (MADAR SHOP Return Rules & Invariants)
// Pure Dart — Zero UI Dependencies

import '../../inventory/value_objects/stock_quantity.dart';

class ReturnValidationResult {
  final bool isAllowed;
  final String? reason;

  const ReturnValidationResult._(this.isAllowed, this.reason);

  factory ReturnValidationResult.allowed() => const ReturnValidationResult._(true, null);

  factory ReturnValidationResult.rejected(String reason) =>
      ReturnValidationResult._(false, reason);
}

class ReturnRules {
  const ReturnRules._();

  /// التحقق من كمية الإرجاع للزبون مقابل الكمية المباعة والمسترجعة سابقاً
  static ReturnValidationResult validateReturnQuantity({
    required StockQuantity soldQuantity,
    required StockQuantity alreadyReturnedQuantity,
    required StockQuantity requestedQuantity,
  }) {
    if (requestedQuantity.milliUnits <= 0) {
      return ReturnValidationResult.rejected('كمية الإرجاع المطلوبة يجب أن تكون أكبر من الصفر.');
    }

    final maxReturnable = soldQuantity - alreadyReturnedQuantity;
    if (maxReturnable.milliUnits <= 0) {
      return ReturnValidationResult.rejected('لقد تم إرجاع كامل الكمية المباعة من هذا الصنف مسبقاً.');
    }

    if (requestedQuantity > maxReturnable) {
      return ReturnValidationResult.rejected(
        'الكمية المطلوب إرجاعها (${requestedQuantity.toDouble()}) تتجاوز الكمية المتبقية المتاحة للإرجاع (${maxReturnable.toDouble()}). '
        '[المباع: ${soldQuantity.toDouble()}، المرتجع مسبقاً: ${alreadyReturnedQuantity.toDouble()}]',
      );
    }

    return ReturnValidationResult.allowed();
  }

  /// التحقق من كمية الإرجاع للمورد مقابل الكمية المستلمة في إيصال الشراء
  static ReturnValidationResult validateSupplierReturnQuantity({
    required StockQuantity receivedQuantity,
    required StockQuantity alreadyReturnedQuantity,
    required StockQuantity requestedQuantity,
  }) {
    if (requestedQuantity.milliUnits <= 0) {
      return ReturnValidationResult.rejected('كمية الإرجاع للمورد يجب أن تكون أكبر من الصفر.');
    }

    final maxReturnable = receivedQuantity - alreadyReturnedQuantity;
    if (maxReturnable.milliUnits <= 0) {
      return ReturnValidationResult.rejected('لقد تم إرجاع كامل كمية هذا البند للمورد مسبقاً.');
    }

    if (requestedQuantity > maxReturnable) {
      return ReturnValidationResult.rejected(
        'الكمية المطلوب إرجاعها للمورد (${requestedQuantity.toDouble()}) تتجاوز الكمية المتاحة للإرجاع (${maxReturnable.toDouble()}). '
        '[المستلم: ${receivedQuantity.toDouble()}، المرتجع مسبقاً: ${alreadyReturnedQuantity.toDouble()}]',
      );
    }

    return ReturnValidationResult.allowed();
  }
}
