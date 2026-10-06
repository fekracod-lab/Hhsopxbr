import '../../domain/entities/payment_intent.dart';
import '../../domain/entities/payment_result.dart';
import '../../domain/services/payment_gateway_provider.dart';

/// محول بوابة كي كارد / مصرف الرافدين العراقية (QiCard Gateway Adapter)
/// ملاحظة معمارية: يتطلب التفعيل إدخال مفاتيح التاجر ورمز المحطة من الشركة العالمية للبطاقة الذكية
class QiCardPaymentAdapter implements PaymentGatewayProvider {
  final String? terminalId;
  final String? merchantKey;
  final bool isProduction;

  static const String stagingEndpoint = 'https://uat-gateway.qicard.net/api/v1/checkout';
  static const String productionEndpoint = 'https://gateway.qicard.net/api/v1/checkout';

  const QiCardPaymentAdapter({
    this.terminalId,
    this.merchantKey,
    this.isProduction = false,
  });

  @override
  PaymentGatewayProviderType get providerType => PaymentGatewayProviderType.qiCard;

  @override
  bool get isConfigured =>
      terminalId != null &&
      terminalId!.isNotEmpty &&
      merchantKey != null &&
      merchantKey!.isNotEmpty;

  String get endpoint => isProduction ? productionEndpoint : stagingEndpoint;

  @override
  Future<PaymentResult> createPaymentIntent(PaymentIntent intent) async {
    if (!isConfigured) {
      return PaymentResult.failure(
        intentId: intent.id,
        errorCode: 'QICARD_CREDENTIALS_MISSING',
        errorMessageIraqi: 'خدمة الدفع عبر كي كارد تتطلب ضبط معرف المحطة (Terminal ID) ومفتاح التاجر المعتمد',
        rawResponse: {'status': 'unconfigured', 'provider': 'qiCard'},
      );
    }

    if (intent.amountMinorUnits <= 0) {
      return PaymentResult.failure(
        intentId: intent.id,
        errorCode: 'INVALID_AMOUNT',
        errorMessageIraqi: 'مبلغ الدفع يجب أن يكون أكبر من الصفر',
      );
    }

    return PaymentResult.failure(
      intentId: intent.id,
      errorCode: 'AWAITING_PRODUCTION_GATEWAY_ACTIVATION',
      errorMessageIraqi: 'بوابة كي كارد بانتظار تفعيل المعاملات الحية من لوحة التحكم المالية',
    );
  }

  @override
  Future<PaymentResult> verifyPayment({
    required String intentId,
    required String transactionReference,
  }) async {
    if (!isConfigured) {
      return PaymentResult.failure(
        intentId: intentId,
        errorCode: 'QICARD_CREDENTIALS_MISSING',
        errorMessageIraqi: 'لا يمكن التحقق من الدفع: مفاتيح بوابة كي كارد غير مهيأة',
      );
    }

    return PaymentResult.failure(
      intentId: intentId,
      errorCode: 'VERIFICATION_UNAVAILABLE',
      errorMessageIraqi: 'بانتظار استجابة بوابة كي كارد للتحقق من المعاملة',
    );
  }

  @override
  Future<PaymentResult> refundPayment({
    required String intentId,
    required String transactionReference,
    required int amountMinorUnits,
    required String reason,
  }) async {
    if (!isConfigured) {
      return PaymentResult.failure(
        intentId: intentId,
        errorCode: 'QICARD_CREDENTIALS_MISSING',
        errorMessageIraqi: 'لا يمكن الاسترجاع: مفاتيح بوابة كي كارد غير مهيأة',
      );
    }

    return PaymentResult.failure(
      intentId: intentId,
      errorCode: 'REFUND_UNAVAILABLE',
      errorMessageIraqi: 'عمليات استرجاع كي كارد تتطلب صلاحيات التاجر المالي من شركة Qi Card',
    );
  }
}
