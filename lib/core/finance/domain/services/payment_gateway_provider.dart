import '../entities/payment_intent.dart';
import '../entities/payment_result.dart';

/// واجهة موفر بوابة الدفع الرقمية (Decoupled Payment Provider Interface)
abstract class PaymentGatewayProvider {
  /// نوع موفر بوابة الدفع (ZainCash, QiCard, etc.)
  PaymentGatewayProviderType get providerType;

  /// هل تم ضبط مفاتيح الربط الحقيقية لبوابة الدفع
  bool get isConfigured;

  /// إنشاء معاملة دفع والحصول على رابط التوجيه أو تأكيد المعاملة
  Future<PaymentResult> createPaymentIntent(PaymentIntent intent);

  /// التحقق من حالة المعاملة لدى بوابة الدفع بعد عودة الزبون من التوجيه
  Future<PaymentResult> verifyPayment({
    required String intentId,
    required String transactionReference,
  });

  /// استرجاع جزئي أو كلي لمعاملة سابقة
  Future<PaymentResult> refundPayment({
    required String intentId,
    required String transactionReference,
    required int amountMinorUnits,
    required String reason,
  });
}
