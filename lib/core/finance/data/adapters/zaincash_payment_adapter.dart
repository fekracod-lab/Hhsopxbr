import '../../domain/entities/payment_intent.dart';
import '../../domain/entities/payment_result.dart';
import '../../domain/services/payment_gateway_provider.dart';

/// محول بوابة زين كاش العراقية (ZainCash Iraqi Payment Gateway Adapter)
/// ملاحظة معمارية: يتطلب التفعيل الميداني إدخال مفاتيح التاجر الرسمية من شركة زين كاش
class ZainCashPaymentAdapter implements PaymentGatewayProvider {
  final String? merchantId;
  final String? secretKey;
  final String? msisdn;
  final bool isProduction;

  static const String stagingEndpoint = 'https://test.zaincash.iq/transaction/init';
  static const String productionEndpoint = 'https://api.zaincash.iq/transaction/init';

  const ZainCashPaymentAdapter({
    this.merchantId,
    this.secretKey,
    this.msisdn,
    this.isProduction = false,
  });

  @override
  PaymentGatewayProviderType get providerType => PaymentGatewayProviderType.zainCash;

  @override
  bool get isConfigured =>
      merchantId != null &&
      merchantId!.isNotEmpty &&
      secretKey != null &&
      secretKey!.isNotEmpty &&
      msisdn != null &&
      msisdn!.isNotEmpty;

  String get endpoint => isProduction ? productionEndpoint : stagingEndpoint;

  @override
  Future<PaymentResult> createPaymentIntent(PaymentIntent intent) async {
    if (!isConfigured) {
      return PaymentResult.failure(
        intentId: intent.id,
        errorCode: 'ZAINCASH_CREDENTIALS_MISSING',
        errorMessageIraqi: 'خدمة الدفع عبر زين كاش تتطلب إدخال مفاتيح التاجر والربط المالي المعتمد مع شركة زين كاش',
        rawResponse: {'status': 'unconfigured', 'provider': 'zainCash'},
      );
    }

    if (intent.amountMinorUnits < 250) {
      return PaymentResult.failure(
        intentId: intent.id,
        errorCode: 'INVALID_AMOUNT',
        errorMessageIraqi: 'الحد الأدنى لعملية الدفع عبر زين كاش هو 250 د.ع',
      );
    }

    // هنا يتم استدعاء خادم الـ Cloud Function الآمن لإنشاء توكن JWT والتوقيع السحابي
    // ولا يتم إجراء محاكاة نجاح وهمية بدون مصادقة السيرفر
    return PaymentResult.failure(
      intentId: intent.id,
      errorCode: 'AWAITING_PRODUCTION_GATEWAY_ACTIVATION',
      errorMessageIraqi: 'بوابة زين كاش بانتظار تفعيل المعاملات الحية من لوحة التحكم المالية',
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
        errorCode: 'ZAINCASH_CREDENTIALS_MISSING',
        errorMessageIraqi: 'لا يمكن التحقق من الدفع: مفاتيح بوابة زين كاش غير مهيأة',
      );
    }

    return PaymentResult.failure(
      intentId: intentId,
      errorCode: 'VERIFICATION_UNAVAILABLE',
      errorMessageIraqi: 'بانتظار استجابة بوابة زين كاش للتحقق من المعاملة',
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
        errorCode: 'ZAINCASH_CREDENTIALS_MISSING',
        errorMessageIraqi: 'لا يمكن الاسترجاع: مفاتيح بوابة زين كاش غير مهيأة',
      );
    }

    return PaymentResult.failure(
      intentId: intentId,
      errorCode: 'REFUND_UNAVAILABLE',
      errorMessageIraqi: 'عمليات الاسترجاع تتطلب تفعيل صلاحيات الاسترداد من حساب تاجر زين كاش',
    );
  }
}
