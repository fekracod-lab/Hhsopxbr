enum PaymentGatewayProviderType {
  zainCash,
  qiCard,
  cashOnDelivery,
  wallet,
}

enum PaymentIntentStatus {
  initiated,
  pendingUserConfirmation,
  processing,
  succeeded,
  failed,
  cancelled,
  expired,
}

/// كائن نية الدفع الرقمي أو النقدي (Payment Intent Entity)
class PaymentIntent {
  final String id;
  final String orderId;
  final String userId;
  final int amountMinorUnits; // القيمة بالدينار العراقي
  final String currency; // 'IQD'
  final PaymentGatewayProviderType providerType;
  final PaymentIntentStatus status;
  final String? redirectUrl;
  final String? transactionReference;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const PaymentIntent({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.amountMinorUnits,
    this.currency = 'IQD',
    required this.providerType,
    required this.status,
    this.redirectUrl,
    this.transactionReference,
    required this.createdAt,
    this.metadata = const {},
  });

  double get amountMajorUnits => amountMinorUnits / 1.0; // IQD has 0 fractional units in standard commerce

  PaymentIntent copyWith({
    PaymentIntentStatus? status,
    String? redirectUrl,
    String? transactionReference,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentIntent(
      id: id,
      orderId: orderId,
      userId: userId,
      amountMinorUnits: amountMinorUnits,
      currency: currency,
      providerType: providerType,
      status: status ?? this.status,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      transactionReference: transactionReference ?? this.transactionReference,
      createdAt: createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'userId': userId,
      'amountMinorUnits': amountMinorUnits,
      'currency': currency,
      'providerType': providerType.name,
      'status': status.name,
      'redirectUrl': redirectUrl,
      'transactionReference': transactionReference,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}
