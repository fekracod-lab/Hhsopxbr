// حاسبة مجمل الربح وهوامش الفواتير والفترات (MADAR SHOP Gross Profit Calculator)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/money.dart';
import '../value_objects/gross_profit_result.dart';

class GrossProfitCalculator {
  const GrossProfitCalculator._();

  /// حساب مجمل الربح ونسبة هامش الربح
  /// المعادلة: Gross Profit = Net Revenue - COGS
  /// الهامش: Gross Margin = (Gross Profit / Net Revenue) * 100
  static GrossProfitResult calculate({
    required Money grossRevenue,
    required Money discountTotal,
    required Money taxTotal,
    required Money cogs,
    required double unitsCount,
  }) {
    return GrossProfitResult.calculate(
      grossRevenue: grossRevenue,
      discountTotal: discountTotal,
      taxTotal: taxTotal,
      cogs: cogs,
      unitsCount: unitsCount,
    );
  }
}
