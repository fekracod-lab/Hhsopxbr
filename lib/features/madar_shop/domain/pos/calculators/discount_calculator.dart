// محرك حساب وتوزيع الخصومات الحسابية الدقيقة (MADAR SHOP Discount Calculator)
// Pure Dart — Zero UI Dependencies

import 'dart:math' as math;
import '../entities/cart_item.dart';
import '../value_objects/discount.dart';
import '../value_objects/money.dart';

class DiscountCalculator {
  const DiscountCalculator._();

  /// حساب خصم البند بدقة مع ضمان عدم تجاوزه لأصل المجموع الفرعي
  static Money calculateLineDiscount({
    required Money subtotal,
    required Discount discount,
  }) {
    if (subtotal.isZero || subtotal.isNegative || discount.isZero) {
      return Money.zero(subtotal.currency);
    }
    return discount.calculateDiscountAmount(subtotal);
  }

  /// حساب خصم السلة المالي العام على المتبقي بعد خصومات البنود
  static Money calculateCartDiscount({
    required Money netAfterItemDiscounts,
    required Discount cartDiscount,
  }) {
    if (netAfterItemDiscounts.isZero ||
        netAfterItemDiscounts.isNegative ||
        cartDiscount.isZero) {
      return Money.zero(netAfterItemDiscounts.currency);
    }
    return cartDiscount.calculateDiscountAmount(netAfterItemDiscounts);
  }

  /// توزيع خصم السلة العام بنسب عادلة ومحددة على بنود السلة
  /// مع معالجة الكسور (Rounding Drift Prevention) لضمان أن مجموع الخصومات الموزعة يساوي خصم السلة بالضبط
  static Map<String, Money> allocateCartDiscountAcrossItems({
    required List<CartItem> items,
    required Money totalCartDiscount,
  }) {
    if (items.isEmpty || totalCartDiscount.isZero) {
      return {for (var item in items) item.itemId: Money.zero(totalCartDiscount.currency)};
    }

    final currency = totalCartDiscount.currency;
    final totalBaseUnits = items.fold<int>(0, (sum, it) => sum + it.lineTotal.minorUnits);

    if (totalBaseUnits == 0) {
      return {for (var item in items) item.itemId: Money.zero(currency)};
    }

    final Map<String, Money> allocations = {};
    int allocatedUnitsSum = 0;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (i == items.length - 1) {
        // البند الأخير يحصل على المتبقي لضمان دقة المجموع بنسبة 100%
        final lastRemainderUnits = math.max(0, totalCartDiscount.minorUnits - allocatedUnitsSum);
        allocations[item.itemId] = Money.fromMinorUnits(lastRemainderUnits, currency);
      } else {
        final shareUnits = ((item.lineTotal.minorUnits / totalBaseUnits) *
                totalCartDiscount.minorUnits)
            .floor();
        allocations[item.itemId] = Money.fromMinorUnits(shareUnits, currency);
        allocatedUnitsSum += shareUnits;
      }
    }

    return allocations;
  }
}
