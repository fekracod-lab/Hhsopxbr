// محرك التسعير والحسابات المالية لنقطة البيع (MADAR SHOP Pricing Calculator)
// Pure Dart — Zero UI Dependencies

import 'dart:math' as math;
import '../entities/cart.dart';
import '../entities/cart_item.dart';
import '../entities/resolved_product.dart';
import '../value_objects/discount.dart';
import '../value_objects/money.dart';
import '../value_objects/pricing_snapshot.dart';
import 'discount_calculator.dart';
import 'tax_policy.dart';

class OrderTotalsCalculation {
  final Money subtotal;
  final Money discountTotal;
  final Money taxTotal;
  final Money grandTotal;
  final Money costTotal;
  final Money netProfit;

  const OrderTotalsCalculation({
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.costTotal,
    required this.netProfit,
  });
}

class PricingCalculator {
  const PricingCalculator._();

  /// إنشاء لقطة تسعير ثابتة لبند السلة
  static PricingSnapshot createSnapshotForItem({
    required ResolvedProduct product,
    Money? manualOverridePrice,
    String? overrideReason,
    Discount discount = const Discount.none(),
    TaxPolicy? taxPolicy,
  }) {
    final currency = product.price.currency;
    final effectivePrice = manualOverridePrice ?? product.price;
    final effectiveTaxPolicy = taxPolicy ?? TaxPolicy.none();

    final lineDiscount = discount.calculateDiscountAmount(effectivePrice);
    final taxableUnitPrice = effectivePrice - lineDiscount;
    final unitTax = effectiveTaxPolicy.calculateTax(
      taxableUnitPrice.isNegative ? Money.zero(currency) : taxableUnitPrice,
    );

    return PricingSnapshot.create(
      basePrice: product.price,
      costPrice: product.cost,
      unitPrice: effectivePrice,
      unitDiscount: lineDiscount,
      unitTax: unitTax,
      isManualOverride: manualOverridePrice != null,
      overrideReason: overrideReason,
    );
  }

  /// حساب الإجماليات الشاملة لسلة المشتريات بدقة جبرية مطلقة
  static OrderTotalsCalculation calculateCartTotals({
    required Cart cart,
    TaxPolicy? taxPolicy,
  }) {
    final currency = cart.currency;
    final effectiveTaxPolicy = taxPolicy ?? TaxPolicy.none();

    if (cart.isEmpty) {
      return OrderTotalsCalculation(
        subtotal: Money.zero(currency),
        discountTotal: Money.zero(currency),
        taxTotal: Money.zero(currency),
        grandTotal: Money.zero(currency),
        costTotal: Money.zero(currency),
        netProfit: Money.zero(currency),
      );
    }

    // 1. المجموع الفرعي للبضاعة
    final subtotal = cart.itemsSubtotal;

    // 2. إجمالي الخصم
    final itemsDiscount = cart.itemsDiscountTotal;
    final netAfterItems = subtotal - itemsDiscount;
    final cartDiscount = DiscountCalculator.calculateCartDiscount(
      netAfterItemDiscounts: netAfterItems,
      cartDiscount: cart.cartDiscount,
    );
    final totalDiscount = itemsDiscount + cartDiscount;

    // 3. المبلغ الخاضع للضريبة
    final taxableBase = subtotal - totalDiscount;
    final safeTaxableBase = taxableBase.isNegative ? Money.zero(currency) : taxableBase;

    // 4. الضريبة
    final totalTax = effectiveTaxPolicy.calculateTax(safeTaxableBase);

    // 5. المبلغ الإجمالي النهائي (Grand Total = Subtotal - Discount + Tax)
    final rawGrand = safeTaxableBase + totalTax;
    final grandTotal = rawGrand.isNegative ? Money.zero(currency) : rawGrand;

    // 6. التكلفة وصافي الربح
    final costTotal = cart.totalCost;
    final netProfit = safeTaxableBase - costTotal;

    return OrderTotalsCalculation(
      subtotal: subtotal,
      discountTotal: totalDiscount,
      taxTotal: totalTax,
      grandTotal: grandTotal,
      costTotal: costTotal,
      netProfit: netProfit,
    );
  }
}
