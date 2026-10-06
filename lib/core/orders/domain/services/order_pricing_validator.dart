import '../entities/order_item.dart';
import '../entities/order_pricing.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// مدقق تسعير الطلب الصارم (Order Pricing Validator)
class OrderPricingValidator {
  const OrderPricingValidator();

  /// التحقق من تطابق الأسعار وبنود الطلب والمجموع الفرعي والنهائي
  static void validatePricing({
    required List<OrderItem> items,
    required OrderPricing pricing,
  }) {
    if (items.isEmpty) {
      throw const SecurityViolationException(
        'لا يمكن إنشاء طلب بدون عناصر',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'items',
      );
    }

    int calculatedSubtotal = 0;

    for (final item in items) {
      if (item.price < 0) {
        throw SecurityViolationException(
          'سعر العنصر (${item.name}) لا يمكن أن يكون سالباً: ${item.price}',
          type: SecurityViolationType.unauthorizedFinancialMutation,
          fieldName: 'price',
        );
      }

      if (item.quantity <= 0) {
        throw SecurityViolationException(
          'كمية العنصر (${item.name}) يجب أن تكون أكبر من الصفر: ${item.quantity}',
          type: SecurityViolationType.tamperedPayload,
          fieldName: 'quantity',
        );
      }

      calculatedSubtotal += item.totalItemPrice;
    }

    // التحقق من تطابق المجموع الفرعي
    if (pricing.subtotal != calculatedSubtotal) {
      throw SecurityViolationException(
        'عدم تطابق في المجموع الفرعي للطلب: المحسوب ($calculatedSubtotal) != المرسل (${pricing.subtotal})',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'subtotal',
      );
    }

    if (pricing.deliveryFee < 0) {
      throw const SecurityViolationException(
        'أجور التوصيل لا يمكن أن تكون سالبة',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'deliveryFee',
      );
    }

    if (pricing.couponDiscount < 0 || pricing.pointsDiscount < 0 || pricing.walletDiscount < 0) {
      throw const SecurityViolationException(
        'مبالغ الخصم لا يمكن أن تكون سالبة',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'discounts',
      );
    }

    final calculatedFinal = (calculatedSubtotal + pricing.deliveryFee - pricing.totalDiscount);
    final expectedFinal = calculatedFinal > 0 ? calculatedFinal : 0;

    if (pricing.finalTotal != expectedFinal) {
      throw SecurityViolationException(
        'عدم تطابق في المبلغ الإجمالي النهائي: المتوقع ($expectedFinal) != المرسل (${pricing.finalTotal})',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'finalTotal',
      );
    }
  }
}
