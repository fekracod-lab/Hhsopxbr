import '../../domain/entities/payment_intent.dart';
import '../../domain/entities/payment_result.dart';
import '../../domain/services/payment_gateway_provider.dart';

/// مستودع ومنسق بوابات الدفع الرقمية (Payment Gateway Repository Implementation)
class PaymentGatewayRepositoryImpl {
  final Map<PaymentGatewayProviderType, PaymentGatewayProvider> _providers = {};

  PaymentGatewayRepositoryImpl({
    List<PaymentGatewayProvider>? providers,
  }) {
    if (providers != null) {
      for (final p in providers) {
        _providers[p.providerType] = p;
      }
    }
  }

  /// تسجيل مزود دفع جديد في النظام
  void registerProvider(PaymentGatewayProvider provider) {
    _providers[provider.providerType] = provider;
  }

  /// الحصول على المزود المسجل
  PaymentGatewayProvider? getProvider(PaymentGatewayProviderType type) {
    return _providers[type];
  }

  /// التحقق مما إذا كان المزود مفعلاً ومضبوطاً
  bool isProviderConfigured(PaymentGatewayProviderType type) {
    return _providers[type]?.isConfigured ?? false;
  }

  /// تنفيذ عملية الدفع عبر المزود المختار
  Future<PaymentResult> processPayment(PaymentIntent intent) async {
    final provider = _providers[intent.providerType];
    if (provider == null) {
      return PaymentResult.failure(
        intentId: intent.id,
        errorCode: 'UNSUPPORTED_PROVIDER',
        errorMessageIraqi: 'طريقة الدفع المحددة غير مدعومة حالياً',
      );
    }

    return await provider.createPaymentIntent(intent);
  }

  /// التحقق من اكتمال الدفع بعد رجوع العميل
  Future<PaymentResult> verifyPayment({
    required PaymentGatewayProviderType providerType,
    required String intentId,
    required String transactionReference,
  }) async {
    final provider = _providers[providerType];
    if (provider == null) {
      return PaymentResult.failure(
        intentId: intentId,
        errorCode: 'UNSUPPORTED_PROVIDER',
        errorMessageIraqi: 'طريقة الدفع المحددة غير مدعومة حالياً',
      );
    }

    return await provider.verifyPayment(
      intentId: intentId,
      transactionReference: transactionReference,
    );
  }
}
