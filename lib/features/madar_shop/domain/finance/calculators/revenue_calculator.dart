// حاسبة الإيرادات وصافي المبيعات (MADAR SHOP Revenue Calculator)
// Pure Dart — Zero UI Dependencies

import '../../pos/entities/sale.dart';
import '../../pos/value_objects/money.dart';

class RevenueCalculationResult {
  final Money grossRevenue;
  final Money discountTotal;
  final Money netRevenue;
  final Money taxTotal;
  final Money grandTotal;

  const RevenueCalculationResult({
    required this.grossRevenue,
    required this.discountTotal,
    required this.netRevenue,
    required this.taxTotal,
    required this.grandTotal,
  });
}

class RevenueCalculator {
  const RevenueCalculator._();

  /// حساب الإيراد الفعلي المحقق من الفاتورة بناء على لقطة التسعير والخصم
  static RevenueCalculationResult calculateSaleRevenue(Sale sale) {
    final gross = sale.subtotal;
    final discount = sale.discountTotal;
    final net = gross - discount;
    final tax = sale.taxTotal;
    final grand = sale.grandTotal;

    return RevenueCalculationResult(
      grossRevenue: gross,
      discountTotal: discount,
      netRevenue: net,
      taxTotal: tax,
      grandTotal: grand,
    );
  }
}
