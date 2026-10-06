import 'payment_intent.dart';

/// كائن نتيجة معالجة الدفع الرقمي (Payment Processing Result)
class PaymentResult {
  final bool isSuccess;
  final String? transactionId;
  final String intentId;
  final PaymentIntentStatus status;
  final String? redirectUrl;
  final String? errorCode;
  final String? errorMessageIraqi;
  final Map<String, dynamic> rawResponse;

  const PaymentResult({
    required this.isSuccess,
    this.transactionId,
    required this.intentId,
    required this.status,
    this.redirectUrl,
    this.errorCode,
    this.errorMessageIraqi,
    this.rawResponse = const {},
  });

  factory PaymentResult.success({
    required String intentId,
    required String transactionId,
    String? redirectUrl,
    Map<String, dynamic> rawResponse = const {},
  }) {
    return PaymentResult(
      isSuccess: true,
      intentId: intentId,
      transactionId: transactionId,
      status: PaymentIntentStatus.succeeded,
      redirectUrl: redirectUrl,
      rawResponse: rawResponse,
    );
  }

  factory PaymentResult.pendingRedirect({
    required String intentId,
    required String redirectUrl,
    String? transactionReference,
    Map<String, dynamic> rawResponse = const {},
  }) {
    return PaymentResult(
      isSuccess: true,
      intentId: intentId,
      transactionId: transactionReference,
      status: PaymentIntentStatus.pendingUserConfirmation,
      redirectUrl: redirectUrl,
      rawResponse: rawResponse,
    );
  }

  factory PaymentResult.failure({
    required String intentId,
    required String errorCode,
    required String errorMessageIraqi,
    Map<String, dynamic> rawResponse = const {},
  }) {
    return PaymentResult(
      isSuccess: false,
      intentId: intentId,
      status: PaymentIntentStatus.failed,
      errorCode: errorCode,
      errorMessageIraqi: errorMessageIraqi,
      rawResponse: rawResponse,
    );
  }
}
