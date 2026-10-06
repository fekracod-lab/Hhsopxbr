import '../entities/unified_order.dart';
import 'order_pricing_validator.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// خدمة تدقيق وثائق الطلب الموحدة (Order Validation Service)
class OrderValidationService {
  const OrderValidationService();

  /// التدقيق الشامل لسلامة الطلب
  static void validateOrder(UnifiedOrder order) {
    if (order.customerId.trim().isEmpty) {
      throw const SecurityViolationException(
        'معرّف العميل مفقود في الطلب',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'customerId',
      );
    }

    if (order.customerName.trim().isEmpty) {
      throw const SecurityViolationException(
        'اسم العميل مطلوب لإنشاء الطلب',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'customerName',
      );
    }

    if (order.customerPhone.trim().isEmpty) {
      throw const SecurityViolationException(
        'رقم هاتف العميل مطلوب لإنشاء الطلب',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'customerPhone',
      );
    }

    if (order.deliveryAddress.trim().isEmpty) {
      throw const SecurityViolationException(
        'عنوان التوصيل مطلوب لإتمام الطلب',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'deliveryAddress',
      );
    }

    if (order.idempotencyKey.trim().length < 8) {
      throw const SecurityViolationException(
        'مفتاح عدم التكرار (Idempotency Key) غير صالح في الطلب',
        type: SecurityViolationType.invalidIdempotency,
      );
    }

    // التحقق من التسعير وبنود الطلب
    OrderPricingValidator.validatePricing(
      items: order.items,
      pricing: order.pricing,
    );
  }
}
