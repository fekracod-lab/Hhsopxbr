import '../entities/fare_request.dart';
import '../entities/pricing_policy.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// فاحص الحدود والشذوذ في معطيات التسعير (Pricing Limits Validator)
class PricingLimitsValidator {
  const PricingLimitsValidator();

  /// أقصى مسافة مسموح بتسعيرها آلياً (200 كم = 200,000 متر)
  static const double maxDistanceMeters = 200000.0;

  /// التحقق الصارم من مدخلات طلب التسعير
  static void validateRequest(FareRequest request, PricingPolicy policy) {
    if (request.distanceMeters.isNaN || request.distanceMeters.isInfinite || request.distanceMeters < 0) {
      throw const SecurityViolationException(
        'المسافة المدخلة غير صالحة للتسعير',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'distanceMeters',
      );
    }

    if (request.distanceMeters > maxDistanceMeters) {
      throw SecurityViolationException(
        'المسافة تتجاوز الحد الأقصى المسموح (${maxDistanceMeters / 1000} كم)',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'distanceMeters',
      );
    }

    if (request.estimatedDurationSeconds < 0) {
      throw const SecurityViolationException(
        'المدة التقديرية لا يمكن أن تكون سالبة',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'estimatedDurationSeconds',
      );
    }

    if (request.discount < 0) {
      throw const SecurityViolationException(
        'مبلغ الخصم لا يمكن أن يكون سالباً',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'discount',
      );
    }

    if (request.stopCount < 0 || request.stopCount > 10) {
      throw const SecurityViolationException(
        'عدد التوقفات الإضافية خارج النطاق المسموح (0 - 10)',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'stopCount',
      );
    }
  }

  /// التحقق من الأجرة النهائية وتطبيق الحدود الدنيا والعليا
  static int clampFare(int calculatedAmount, PricingPolicy policy) {
    if (calculatedAmount < policy.minimumFare) {
      return policy.minimumFare;
    }
    if (calculatedAmount > policy.maximumFare) {
      return policy.maximumFare;
    }
    return calculatedAmount;
  }
}
