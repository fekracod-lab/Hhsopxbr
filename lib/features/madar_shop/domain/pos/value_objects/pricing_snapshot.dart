// لقطة تسعير تاريخية غير قابلة للتغيير للبند المباع (MADAR SHOP Pricing Snapshot)
// Pure Dart — Zero UI Dependencies

import 'currency.dart';
import 'money.dart';

class PricingSnapshot {
  final Money basePrice;
  final Money costPrice;
  final Money unitPrice;
  final Money unitDiscount;
  final Money unitTax;
  final Money netUnitPrice;
  final bool isManualOverride;
  final String? overrideReason;
  final DateTime capturedAt;

  const PricingSnapshot({
    required this.basePrice,
    required this.costPrice,
    required this.unitPrice,
    required this.unitDiscount,
    required this.unitTax,
    required this.netUnitPrice,
    this.isManualOverride = false,
    this.overrideReason,
    required this.capturedAt,
  });

  /// بناء لقطة تسعير سريعة مع التحقق من الاتساق المالي
  factory PricingSnapshot.create({
    required Money basePrice,
    required Money costPrice,
    Money? unitPrice,
    Money? unitDiscount,
    Money? unitTax,
    bool isManualOverride = false,
    String? overrideReason,
    DateTime? capturedAt,
  }) {
    final currency = basePrice.currency;
    final effectiveUnitPrice = unitPrice ?? basePrice;
    final effectiveDiscount = unitDiscount ?? Money.zero(currency);
    final effectiveTax = unitTax ?? Money.zero(currency);

    // netUnitPrice = effectiveUnitPrice - effectiveDiscount + effectiveTax
    final calculatedNet = effectiveUnitPrice - effectiveDiscount + effectiveTax;

    return PricingSnapshot(
      basePrice: basePrice,
      costPrice: costPrice,
      unitPrice: effectiveUnitPrice,
      unitDiscount: effectiveDiscount,
      unitTax: effectiveTax,
      netUnitPrice: calculatedNet < Money.zero(currency) ? Money.zero(currency) : calculatedNet,
      isManualOverride: isManualOverride,
      overrideReason: overrideReason,
      capturedAt: capturedAt ?? DateTime.now(),
    );
  }

  Currency get currency => basePrice.currency;

  Map<String, dynamic> toMap() {
    return {
      'basePriceUnits': basePrice.minorUnits,
      'costPriceUnits': costPrice.minorUnits,
      'unitPriceUnits': unitPrice.minorUnits,
      'unitDiscountUnits': unitDiscount.minorUnits,
      'unitTaxUnits': unitTax.minorUnits,
      'netUnitPriceUnits': netUnitPrice.minorUnits,
      'currencyCode': currency.code,
      'isManualOverride': isManualOverride,
      'overrideReason': overrideReason,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }

  factory PricingSnapshot.fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currencyCode'] as String?);
    return PricingSnapshot(
      basePrice: Money.fromMinorUnits((map['basePriceUnits'] as num?)?.toInt() ?? 0, currency),
      costPrice: Money.fromMinorUnits((map['costPriceUnits'] as num?)?.toInt() ?? 0, currency),
      unitPrice: Money.fromMinorUnits((map['unitPriceUnits'] as num?)?.toInt() ?? 0, currency),
      unitDiscount: Money.fromMinorUnits((map['unitDiscountUnits'] as num?)?.toInt() ?? 0, currency),
      unitTax: Money.fromMinorUnits((map['unitTaxUnits'] as num?)?.toInt() ?? 0, currency),
      netUnitPrice: Money.fromMinorUnits((map['netUnitPriceUnits'] as num?)?.toInt() ?? 0, currency),
      isManualOverride: map['isManualOverride'] as bool? ?? false,
      overrideReason: map['overrideReason'] as String?,
      capturedAt: DateTime.tryParse(map['capturedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
