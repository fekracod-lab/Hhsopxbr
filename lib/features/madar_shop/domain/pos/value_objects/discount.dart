// كائن قيمة الخصم المالي في نقطة البيع (MADAR SHOP Discount Value Object)
// Pure Dart — Zero UI Dependencies

import 'dart:math' as math;
import '../enums/discount_type.dart';
import 'money.dart';

class Discount {
  final DiscountType type;
  final double value; // النسبة المئوية مثلاً 10% أو المبلغ المباشر مثلاً 2000 د.ع
  final String? reason;
  final String? couponCode;

  const Discount({
    required this.type,
    required this.value,
    this.reason,
    this.couponCode,
  });

  const Discount.none()
      : type = DiscountType.fixed,
        value = 0.0,
        reason = null,
        couponCode = null;

  bool get isZero => value <= 0;

  /// حساب قيمة الخصم الفعلي بدقة وبدون تجاوز أصل المبلغ
  Money calculateDiscountAmount(Money baseAmount) {
    if (value <= 0) return Money.zero(baseAmount.currency);

    if (type == DiscountType.percentage) {
      if (value >= 100.0) return baseAmount;
      final discountUnits = (baseAmount.minorUnits * (value / 100.0)).round();
      final boundedUnits = math.min(discountUnits, baseAmount.minorUnits);
      return Money.fromMinorUnits(boundedUnits, baseAmount.currency);
    } else {
      final fixedDiscount = Money.fromAmount(value, baseAmount.currency);
      return fixedDiscount > baseAmount ? baseAmount : fixedDiscount;
    }
  }
}
