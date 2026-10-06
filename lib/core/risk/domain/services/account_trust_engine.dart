/// محرك تقييم موثوقية ونضج الحساب (Account Trust Engine)
class AccountTrustEngine {
  const AccountTrustEngine();

  /// احتساب خصم الثقة بناءً على تاريخ الحساب والعمليات الناجحة
  static int computeTrustDiscount({
    required DateTime accountCreatedAt,
    required int completedOrdersCount,
    required int successfulPaymentsCount,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final accountAgeDays = currentTime.difference(accountCreatedAt).inDays;

    int discount = 0;

    // مكافأة عمر الحساب
    if (accountAgeDays >= 90) {
      discount += 10;
    } else if (accountAgeDays >= 30) {
      discount += 5;
    }

    // مكافأة العمليات الناجحة المكتملة
    if (completedOrdersCount >= 20 && successfulPaymentsCount >= 20) {
      discount += 10;
    } else if (completedOrdersCount >= 5) {
      discount += 5;
    }

    return discount.clamp(0, 25); // أقصى خصم أمان 25 نقطة
  }
}
