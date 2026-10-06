// نماذج وكيانات الدفع وإتمام الطلب لمتجر مدار (Store Checkout Domain Models)
// Pure Dart — Zero Flutter / Firebase Dependencies

/// طريقة دفع الطلب في متجر مدار
enum StorePaymentMethod {
  cash,
  wallet;

  static StorePaymentMethod fromString(String? value) {
    if (value == null) return StorePaymentMethod.cash;
    switch (value.trim().toLowerCase()) {
      case 'wallet':
      case 'paid_wallet':
        return StorePaymentMethod.wallet;
      case 'cash':
      case 'cash_on_delivery':
      default:
        return StorePaymentMethod.cash;
    }
  }

  String toDbString() {
    switch (this) {
      case StorePaymentMethod.wallet:
        return 'wallet';
      case StorePaymentMethod.cash:
        return 'cash';
    }
  }
}

/// حالة دفع الطلب لمتجر مدار
enum StorePaymentStatus {
  cashOnDelivery,
  paidWallet,
  pending,
  unknown;

  static StorePaymentStatus fromString(String? value) {
    if (value == null) return StorePaymentStatus.unknown;
    switch (value.trim().toLowerCase()) {
      case 'paid_wallet':
        return StorePaymentStatus.paidWallet;
      case 'cash_on_delivery':
        return StorePaymentStatus.cashOnDelivery;
      case 'pending':
        return StorePaymentStatus.pending;
      default:
        return StorePaymentStatus.unknown;
    }
  }

  String toDbString() {
    switch (this) {
      case StorePaymentStatus.paidWallet:
        return 'paid_wallet';
      case StorePaymentStatus.cashOnDelivery:
        return 'cash_on_delivery';
      case StorePaymentStatus.pending:
        return 'pending';
      case StorePaymentStatus.unknown:
        return 'unknown';
    }
  }
}

/// معلومات العميل والتوصيل عند إتمام الطلب
class StoreCustomerInfoEntity {
  final String name;
  final String phone;
  final String address;
  final String notes;
  final double? latitude;
  final double? longitude;

  const StoreCustomerInfoEntity({
    required this.name,
    required this.phone,
    required this.address,
    this.notes = '',
    this.latitude,
    this.longitude,
  });

  StoreCustomerInfoEntity copyWith({
    String? name,
    String? phone,
    String? address,
    String? notes,
    double? latitude,
    double? longitude,
  }) {
    return StoreCustomerInfoEntity(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

/// نتيجة التحقق من صحة بيانات إتمام الطلب
class StoreCheckoutValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? errorCode;

  const StoreCheckoutValidationResult({
    required this.isValid,
    this.errorMessage,
    this.errorCode,
  });

  static const StoreCheckoutValidationResult valid =
      StoreCheckoutValidationResult(isValid: true);

  factory StoreCheckoutValidationResult.invalid({
    required String message,
    String? code,
  }) {
    return StoreCheckoutValidationResult(
      isValid: false,
      errorMessage: message,
      errorCode: code,
    );
  }
}

/// ملخص الحسابات المالية لإتمام الطلب (Checkout Summary)
class StoreCheckoutSummaryEntity {
  final double subtotal;
  final double deliveryFee;
  final int pointsUsed;
  final double pointsDiscount;
  final double walletDiscount;
  final double totalDiscount;
  final double finalTotal;
  final int pointsEarned;
  final StorePaymentMethod paymentMethod;
  final StorePaymentStatus paymentStatus;
  final double userBalance;
  final int userPoints;
  final bool canPayWithWallet;

  const StoreCheckoutSummaryEntity({
    required this.subtotal,
    required this.deliveryFee,
    required this.pointsUsed,
    required this.pointsDiscount,
    required this.walletDiscount,
    required this.totalDiscount,
    required this.finalTotal,
    required this.pointsEarned,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.userBalance,
    required this.userPoints,
    required this.canPayWithWallet,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoreCheckoutSummaryEntity &&
        other.subtotal == subtotal &&
        other.deliveryFee == deliveryFee &&
        other.pointsUsed == pointsUsed &&
        other.pointsDiscount == pointsDiscount &&
        other.walletDiscount == walletDiscount &&
        other.totalDiscount == totalDiscount &&
        other.finalTotal == finalTotal &&
        other.pointsEarned == pointsEarned &&
        other.paymentMethod == paymentMethod &&
        other.paymentStatus == paymentStatus &&
        other.userBalance == userBalance &&
        other.userPoints == userPoints &&
        other.canPayWithWallet == canPayWithWallet;
  }

  @override
  int get hashCode => Object.hash(
        subtotal,
        deliveryFee,
        pointsUsed,
        pointsDiscount,
        walletDiscount,
        totalDiscount,
        finalTotal,
        pointsEarned,
        paymentMethod,
        paymentStatus,
        userBalance,
        userPoints,
        canPayWithWallet,
      );

  @override
  String toString() {
    return 'StoreCheckoutSummary(subtotal: $subtotal, delivery: $deliveryFee, disc: $totalDiscount, total: $finalTotal, earnedPts: $pointsEarned)';
  }
}

/// لقطة مالية غير قابلة للتعديل لحفظ الطلب في قاعدة البيانات (Immutable Order Financial Snapshot)
class StoreOrderFinancialSnapshot {
  final double subtotal;
  final double deliveryFee;
  final double totalDiscount;
  final int pointsUsed;
  final double pointsDiscount;
  final double walletDiscount;
  final double finalTotal;
  final int pointsEarned;
  final String paymentStatus;

  const StoreOrderFinancialSnapshot({
    required this.subtotal,
    required this.deliveryFee,
    required this.totalDiscount,
    required this.pointsUsed,
    required this.pointsDiscount,
    required this.walletDiscount,
    required this.finalTotal,
    required this.pointsEarned,
    required this.paymentStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'subTotal': subtotal,
      'deliveryFee': deliveryFee,
      'discount': totalDiscount,
      'pointsUsed': pointsUsed,
      'pointsDiscount': pointsDiscount,
      'walletDiscount': walletDiscount,
      'total': finalTotal,
      'pointsEarned': pointsEarned,
      'paymentStatus': paymentStatus,
    };
  }
}
