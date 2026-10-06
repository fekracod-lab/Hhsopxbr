// تجريد سياسة الضريبة لنظام نقاط البيع (MADAR SHOP Tax Policy Abstraction)
// Pure Dart — Zero UI Dependencies

import '../value_objects/money.dart';

abstract class TaxPolicy {
  final String policyName;

  const TaxPolicy(this.policyName);

  /// حساب مبلغ الضريبة للبند أو السلة
  Money calculateTax(Money taxableAmount);

  /// سياسة بدون ضريبة (الافتراضية في نقاط البيع العراقية)
  factory TaxPolicy.none() = _NoTaxPolicy;

  /// سياسة ضريبية بنسبة مئوية محددة (مثل ضريبة المبيعات أو القيمة المضافة)
  factory TaxPolicy.rate({
    required double percentage,
    String name,
  }) = _PercentageTaxPolicy;
}

class _NoTaxPolicy extends TaxPolicy {
  const _NoTaxPolicy() : super('معفي من الضريبة');

  @override
  Money calculateTax(Money taxableAmount) {
    return Money.zero(taxableAmount.currency);
  }
}

class _PercentageTaxPolicy extends TaxPolicy {
  final double percentage;

  const _PercentageTaxPolicy({
    required this.percentage,
    String name = 'ضريبة مبيعات',
  }) : super(name);

  @override
  Money calculateTax(Money taxableAmount) {
    if (percentage <= 0 || taxableAmount.isZero || taxableAmount.isNegative) {
      return Money.zero(taxableAmount.currency);
    }
    final taxMinor = (taxableAmount.minorUnits * (percentage / 100.0)).round();
    return Money.fromMinorUnits(taxMinor, taxableAmount.currency);
  }
}
