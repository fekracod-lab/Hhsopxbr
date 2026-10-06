// نتيجة حساب مجمل الربح وهوامش المبيعات (MADAR SHOP Gross Profit Result)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/money.dart';

class GrossProfitResult {
  final Money grossRevenue;
  final Money netRevenue;
  final Money cogs;
  final Money grossProfit;
  final double? grossMarginPercentage;
  final Money discountTotal;
  final Money taxTotal;
  final double unitsCount;

  const GrossProfitResult({
    required this.grossRevenue,
    required this.netRevenue,
    required this.cogs,
    required this.grossProfit,
    required this.grossMarginPercentage,
    required this.discountTotal,
    required this.taxTotal,
    required this.unitsCount,
  });

  /// حساب مجمل الربح مع الحماية الصارمة من القسمة على الصفر
  factory GrossProfitResult.calculate({
    required Money grossRevenue,
    required Money discountTotal,
    required Money taxTotal,
    required Money cogs,
    required double unitsCount,
  }) {
    final netRev = grossRevenue - discountTotal;
    final profit = netRev - cogs;

    double? margin;
    if (netRev.minorUnits > 0) {
      margin = (profit.minorUnits / netRev.minorUnits) * 100.0;
    } else if (netRev.minorUnits == 0) {
      margin = 0.0;
    } else {
      margin = null;
    }

    return GrossProfitResult(
      grossRevenue: grossRevenue,
      netRevenue: netRev,
      cogs: cogs,
      grossProfit: profit,
      grossMarginPercentage: margin,
      discountTotal: discountTotal,
      taxTotal: taxTotal,
      unitsCount: unitsCount,
    );
  }
}
