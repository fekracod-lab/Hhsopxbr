// تقرير تقييم المخزون المالي الشامل (MADAR SHOP Inventory Valuation Report)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/currency.dart';
import '../../pos/value_objects/money.dart';
import 'inventory_valuation_item.dart';

class InventoryValuationReport {
  final String businessId;
  final String? branchId;
  final List<InventoryValuationItem> items;
  final Currency currency;
  final DateTime generatedAt;
  final DateTime asOf;

  const InventoryValuationReport({
    required this.businessId,
    this.branchId,
    required this.items,
    this.currency = Currency.iqd,
    required this.generatedAt,
    required this.asOf,
  });

  /// إجمالي القيمة التقييمية لجميع بضائع المخزون
  Money get totalValuation {
    if (items.isEmpty) return Money.zero(currency);
    return items.fold(Money.zero(currency), (sum, item) => sum + item.totalValuation);
  }

  /// إجمالي عدد القطع والوحدات المخزنة
  double get totalUnitsCount {
    return items.fold(0.0, (sum, item) => sum + item.quantityOnHand.toDouble());
  }
}
